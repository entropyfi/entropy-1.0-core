// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import "../interfaces/ILosslessV2Pool.sol";
import "../interfaces/ILosslessV2Factory.sol";
import "../interfaces/ILosslessV2Token.sol";

import "../interfaces/IPriceOracleGetter.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IProtocolDataProvider.sol";
import "../interfaces/IStakedToken.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/interfaces/KeeperCompatibleInterface.sol";

contract LosslessV2Pool is ILosslessV2Pool, KeeperCompatibleInterface{
	using SafeMath for uint256;

	// basic info for initializing a pool
	address public override factory;
	address public override bidToken;
	address public override principalToken;
	address public override aToken;
	address public override addressProvider;

	AggregatorV3Interface private priceFeed;

	// used for calculating share price, define the precision is 0.0001
	uint256 public constant PRECISION = 10**4;

	///@dev the actual share value is valuePerShortToken /  PRECISION (constant = 10000)
	uint256 public valuePerShortToken = PRECISION; // the value of a single share - short
	uint256 public valuePerLongToken = PRECISION; // the value of a single share - long
	uint256 public constant valuePerSponsorToken = PRECISION; // the value of sponsor share should be fixed to PRECISION

	uint256 private totalInterest;

	GameStatus public status;
	PoolTokensInfo public poolTokensInfo;
	mapping(address => uint256) public override inPoolTimestamp;

	ILosslessV2Token private _shortToken;
	ILosslessV2Token private _longToken;
	ILosslessV2Token private _sponsorToken;

	// lock modifier
	bool private accepting = true;
	modifier lock() {
		require(accepting == true, "LosslessV2Pool: LOCKED");
		accepting = false;
		_;
		accepting = true;
	}

	modifier onlyFactory() {
		require(msg.sender == factory, "LosslessV2Factory: FACTORY ONLY");
		_;
	}

	modifier onlyAfter(uint256 _time) {
		require(block.timestamp > _time, "LosslessV2Pool: INVALID TIMESTAMP AFTER");
		_;
	}

	constructor(
		address _bidToken,
		address _principalToken,
		address _addressProvider,
		address _aggregator,
		uint256 _biddingDuration,
		uint256 _gamingDuration
	) public {
		factory = msg.sender;
		bidToken = _bidToken;
		principalToken = _principalToken;

		addressProvider = _addressProvider;
		aToken = _getATokenAddress(principalToken);

		priceFeed = AggregatorV3Interface(_aggregator);

		// modify status variable
		status.gameRound = 1;
		status.durationOfBidding = _biddingDuration;
		status.durationOfGame = _gamingDuration;
		status.lastUpdateTimestamp = block.timestamp;
		// status.initialPrice - unchange for now
		// status.endPrice - unchange for now
		// status.isShortLastRoundWinner - default to false
		status.isFirstRound = true;
		status.isFirstUser = true;
		status.currState = PoolStatus.FirstGame;
	}

	/**
	 * @dev initialize pool
	 **/
	function initialize(
		address shortToken_,
		address longToken_,
		address sponsorToken_
	) external override onlyFactory {
		poolTokensInfo.shortToken = shortToken_;
		poolTokensInfo.longToken = longToken_;
		poolTokensInfo.sponsorToken = sponsorToken_;

		_shortToken = ILosslessV2Token(shortToken_);
		_longToken = ILosslessV2Token(longToken_);
		_sponsorToken = ILosslessV2Token(sponsorToken_);
	}

	/**
	 * @dev only be called once, after initalize
	 **/
	function startFirstRound() external override {
		require(status.isFirstRound == true, "LosslessV2Pool: NOT FIRST ROUND!");
		require(status.currState == PoolStatus.FirstGame, "LosslessV2Pool: WRONG STATUS");
		// modify status variable
		// status.gameRound = 1;
		status.lastUpdateTimestamp = block.timestamp;
		// status.initialPrice - unchange for now
		// status.endPrice - unchange for now
		// status.isShortLastRoundWinner - unchange for now
		status.isFirstRound = false;
		// status.isFirstUser = true;
		status.currState = PoolStatus.Accepting;
	}

	/**
	 * @dev start the gaming, lock pool and transfer asset to defi lending
	 **/
	function startGame() public override lock onlyAfter(status.lastUpdateTimestamp.add(status.durationOfBidding)) {
		require(status.currState == PoolStatus.Accepting, "LosslessV2Pool: WRONG STATUS");
		require(_shortToken.totalSupply() != 0 && _longToken.totalSupply() != 0, "LosslessV2Pool: NO FUND IN POOL");
		// modify status variable
		// status.gameRound = 1;
		status.lastUpdateTimestamp = block.timestamp;
		// fisrt user can set the inital price
		if (status.isFirstUser == true) {
			status.initialPrice = _getPrice();
			status.isFirstUser = false;
		}
		// status.endPrice - unchange for now
		// status.isShortLastRoundWinner - unchange for now
		// status.isFirstRound = false;
		// status.isFirstUser = true;
		status.currState = PoolStatus.Locked;

		// transfer to aave
		_supplyToAAVE(principalToken, IERC20(principalToken).balanceOf(address(this)));
	}

	/**
	 * @dev end the gaming, redeem assets from aave and get end price
	 **/
	function endGame() public override lock onlyAfter(status.lastUpdateTimestamp.add(status.durationOfGame)) {
		require(status.currState == PoolStatus.Locked, "LosslessV2Pool: WRONG STATUS");

		// modify status variable
		status.gameRound = status.gameRound.add(1);
		status.lastUpdateTimestamp = block.timestamp;
		// status.initialPrice - unchange for now
		// status.endPrice - unchange for now
		// status.isShortLastRoundWinner - unchange for now
		// status.isFirstRound = false;
		status.isFirstUser = true;
		status.currState = PoolStatus.Accepting;

		// redeem from AAVE
		_redeemFromAAVE(principalToken, 0); // redeem all
		// get end price
		status.endPrice = _getPrice();

		// if end price higher than inital price -> long users win !
		if (status.endPrice >= status.initialPrice) {
			status.isShortLastRoundWinner = false;
		} else {
			status.isShortLastRoundWinner = true;
		}

		// update interest and principal amount
		uint256 totalShortPrincipal = _shortToken.totalSupply().mul(valuePerShortToken).div(PRECISION);
		uint256 totalLongPrincipal = _longToken.totalSupply().mul(valuePerLongToken).div(PRECISION);
		uint256 totalSponsorPrincipal = _sponsorToken.totalSupply().mul(valuePerSponsorToken).div(PRECISION);
		uint256 totalPrincipal = totalShortPrincipal.add(totalLongPrincipal.add(totalSponsorPrincipal));
		if (IERC20(principalToken).balanceOf(address(this)) < totalPrincipal) {
			totalInterest = 0; // in case kovan testnet give us aToken slightly less than deposit amount
		} else {
			totalInterest = IERC20(principalToken).balanceOf(address(this)).sub(totalPrincipal);
		}

		// update share value
		_updateTokenValue(totalShortPrincipal, totalLongPrincipal);

		emit AnnounceWinner(status.isShortLastRoundWinner, status.initialPrice, status.endPrice);
	}

	/**
	 * @dev chainlink keeper checkUpkeep function to constantly check whether we need function call
	 **/
	function checkUpkeep(bytes calldata checkData) external override returns (bool upkeepNeeded, bytes memory performData) {
		PoolStatus currState = status.currState;
		uint256 lastUpdateTimestamp = status.lastUpdateTimestamp;
		uint256 durationOfGame = status.durationOfGame;
		uint256 durationOfBidding = status.durationOfBidding;

		if (currState == PoolStatus.Accepting && block.timestamp > lastUpdateTimestamp.add(durationOfBidding)) {
			upkeepNeeded = true;
		} else if (currState == PoolStatus.Locked && block.timestamp > lastUpdateTimestamp.add(durationOfGame)) {
			upkeepNeeded = true;
		} else {
			upkeepNeeded = false;
		}
		performData = checkData;
	}

	/**
	 * @dev once checkUpKeep been trigered, keeper will call performUpKeep
	 **/
	function performUpkeep(bytes calldata performData) external override {
		PoolStatus currState = status.currState;
		uint256 lastUpdateTimestamp = status.lastUpdateTimestamp;
		uint256 durationOfGame = status.durationOfGame;
		uint256 durationOfBidding = status.durationOfBidding;

		if (currState == PoolStatus.Accepting && block.timestamp > lastUpdateTimestamp.add(durationOfBidding)) {
			startGame();
		}
		if (currState == PoolStatus.Locked && block.timestamp > lastUpdateTimestamp.add(durationOfGame)) {
			endGame();
		}
		performData;
	}

	/**
	 * @dev termination function, use this to terminate the game
	 **/
	function poolTermination() external override onlyFactory {
		// only when pool status is at Accepting
		require(status.currState == PoolStatus.Accepting, "LosslessV2Pool: WRONG STATUS");

		// modify status variable
		// status.gameRound = status.gameRound.add(1);
		// status.durationOfGame = 6 days;
		// status.durationOfBidding = 1 days;
		// status.lastUpdateTimestamp = block.timestamp;
		// status.initialPrice - unchange for now
		// status.endPrice - unchange for now
		// status.isShortLastRoundWinner - unchange for now
		// status.isFirstRound = false;
		// status.isFirstUser = true;
		status.currState = PoolStatus.Terminated;
	}

	/**
	 * @dev users can add principal as long as the status is accpeting
	 * @param shortPrincipalAmount how many principal in short pool does user want to deposit
	 * @param longPrincipalAmount how many principal in long pool does user want to deposit
	 **/
	function deposit(uint256 shortPrincipalAmount, uint256 longPrincipalAmount) external override lock {
		require(status.currState == PoolStatus.Accepting, "LosslessV2Pool: WRONG STATUS");
		require(shortPrincipalAmount > 0 || longPrincipalAmount > 0, "LosslessV2Pool: INVALID AMOUNT");

		// fisrt user can set the inital price
		if (status.isFirstUser == true) {
			status.initialPrice = _getPrice();
			status.isFirstUser = false;
		}
		// // if user's balance is zero record user's join timestamp for reward
		if (_shortToken.balanceOf(msg.sender) == 0 && _longToken.balanceOf(msg.sender) == 0) {
			inPoolTimestamp[msg.sender] = block.timestamp;
		}
		// transfer principal to pool contract
		SafeERC20.safeTransferFrom(IERC20(principalToken), msg.sender, address(this), shortPrincipalAmount.add(longPrincipalAmount));
		_mintTokens(true, msg.sender, shortPrincipalAmount, longPrincipalAmount);

		emit Deposit(shortPrincipalAmount, longPrincipalAmount);
	}

	/**
	 * @dev user can call it to redeem pool tokens to principal tokens
	 * @param shortTokenAmount 	how many short token in short pool does user want to redeem
	 * @param longTokenAmount 	how many long token in long pool does user want to redeem
	 **/
	function withdraw(
		bool isAToken,
		uint256 shortTokenAmount,
		uint256 longTokenAmount
	) external override lock {
		// withdraw should have no limitation in pool status
		require(shortTokenAmount > 0 || longTokenAmount > 0, "LosslessV2Pool: INVALID AMOUNT");

		// check user token balance
		uint256 userShortTokenBalance = _shortToken.balanceOf(msg.sender);
		uint256 userLongTokenBalance = _longToken.balanceOf(msg.sender);
		require(userShortTokenBalance >= shortTokenAmount && userLongTokenBalance >= longTokenAmount, "LosslessV2Pool: INSUFFICIENT BALANCE");

		// calculate withdraw principal amount
		uint256 shortPrincipalAmount = shortTokenAmount.mul(valuePerShortToken).div(PRECISION);
		uint256 longPrincipalAmount = longTokenAmount.mul(valuePerLongToken).div(PRECISION);

		// user withdraw will cause timestamp update -> reduce their goverance reward
		inPoolTimestamp[msg.sender] = block.timestamp;

		// burn user withdraw token
		_burnTokens(false, msg.sender, shortTokenAmount, longTokenAmount);

		/*  pool status | isAToken | Operation
				lock	     T       transfer aToken
				lock 		 F		 redeem then transfer principal Token
			  unlock  		 T 		 supply to aave then transfer aToken
			  unlock         F       transfer principal token
		 */
		if (isAToken == false) {
			if (status.currState == PoolStatus.Locked) {
				_redeemFromAAVE(principalToken, shortPrincipalAmount.add(longPrincipalAmount));
			}
			SafeERC20.safeTransfer(IERC20(principalToken), msg.sender, shortPrincipalAmount.add(longPrincipalAmount));
		} else {
			if (status.currState == PoolStatus.Accepting) {
				_supplyToAAVE(principalToken, shortPrincipalAmount.add(longPrincipalAmount));
			}
			SafeERC20.safeTransfer(IERC20(aToken), msg.sender, shortPrincipalAmount.add(longPrincipalAmount));
		}

		emit Withdraw(isAToken, shortTokenAmount, longTokenAmount);
	}

	/**
	 * @dev user can call this to shift share from long -> short, short -> long without withdrawing assets
	 * @param fromLongToShort is user choosing to shift from long to short
	 * @param swapTokenAmount the amount of token that user wishes to swap
	 **/
	function swap(bool fromLongToShort, uint256 swapTokenAmount) external override lock {
		require(status.currState == PoolStatus.Accepting, "LosslessV2Pool: WRONG STATUS");
		uint256 shortTokenBalance = _shortToken.balanceOf(msg.sender);
		uint256 longTokenBalance = _longToken.balanceOf(msg.sender);
		uint256 tokenBalanceOfTargetPosition = fromLongToShort ? longTokenBalance : shortTokenBalance;
		// check user balance
		require(swapTokenAmount > 0 && swapTokenAmount <= tokenBalanceOfTargetPosition, "LosslessV2Pool: INSUFFICIENT BALANCE");

		// reallocate user's share balance
		if (fromLongToShort == true) {
			// user wants to shift from long to short, so burn long share and increase short share
			_burnTokens(false, msg.sender, 0, swapTokenAmount);
			_mintTokens(false, msg.sender, swapTokenAmount.mul(valuePerLongToken).div(valuePerShortToken), 0);
		} else {
			// user wants to shift from short to long, so burn short share and increase long share
			_burnTokens(false, msg.sender, swapTokenAmount, 0);
			_mintTokens(false, msg.sender, 0, swapTokenAmount.mul(valuePerShortToken).div(valuePerLongToken));
		}
	}

	/**
	 * @dev sponsr can deposit and withdraw principals to the game
	 * @param principalAmount amount of principal token
	 **/
	function sponsorDeposit(uint256 principalAmount) external override lock {
		require(status.currState != PoolStatus.Terminated, "LosslessV2Pool: POOL TERMINATED");
		require(principalAmount > 0, "LosslessV2Pool: INVALID AMOUNT");
		require(IERC20(principalToken).balanceOf(msg.sender) >= principalAmount, "LosslessV2Pool: INSUFFICIENT BALANCE");

		// transfer asset first
		SafeERC20.safeTransferFrom(IERC20(principalToken), msg.sender, address(this), principalAmount);

		// check current game state
		if (status.currState == PoolStatus.Locked) {
			// if during the lock time
			// interact with AAVE to get the principal back
			_supplyToAAVE(principalToken, principalAmount);
		}

		// mint sponsor token
		_sponsorToken.mint(msg.sender, principalAmount);

		emit SponsorDeposit(principalAmount);
	}

	/**
	 * @dev sponsr can deposit and withdraw principals to the game
	 * @param sponsorTokenAmount amount of zero token
	 **/
	function sponsorWithdraw(uint256 sponsorTokenAmount) external override lock {
		require(sponsorTokenAmount > 0, "LosslessV2Pool: INVALID AMOUNT");
		// burn user sponsor token
		_sponsorToken.burn(msg.sender, sponsorTokenAmount);

		// check current game state
		if (status.currState == PoolStatus.Locked) {
			// if during the lock time
			// interact with AAVE to get the principal back
			_redeemFromAAVE(principalToken, sponsorTokenAmount);
		}

		// transfer principal token
		SafeERC20.safeTransfer(IERC20(principalToken), msg.sender, sponsorTokenAmount);

		emit SponsorWithdraw(sponsorTokenAmount);
	}

	/**
	 * @dev calculate each token's value
	 * @param _totalShortPrincipal 	the total amount of short principal
	 * @param _totalLongPrincipal	the total amount of long principal
	 **/
	function _updateTokenValue(uint256 _totalShortPrincipal, uint256 _totalLongPrincipal) private {
		address feeTo = ILosslessV2Factory(factory).feeTo();
		uint256 feePercent = ILosslessV2Factory(factory).feePercent();
		uint256 fee = totalInterest.mul(feePercent).div(PRECISION);

		// if fee is on and feeTo been set
		if (feePercent != 0 && feeTo != address(0)) {
			totalInterest = totalInterest.sub(fee);
			SafeERC20.safeTransfer(IERC20(principalToken), feeTo, fee);
		}

		// update short/long token value
		if (status.isShortLastRoundWinner == true) {
			// short win
			_totalShortPrincipal = _totalShortPrincipal.add(totalInterest);
			valuePerShortToken = _totalShortPrincipal.mul(PRECISION).div(_shortToken.totalSupply());
		} else if (status.isShortLastRoundWinner == false) {
			// long win
			_totalLongPrincipal = _totalLongPrincipal.add(totalInterest);
			valuePerLongToken = _totalLongPrincipal.mul(PRECISION).div(_longToken.totalSupply());
		}

		emit UpdateTokenValue(valuePerShortToken, valuePerLongToken);
	}

	/**
	 * @dev supply to aave protocol
	 * @param _asset 	the address of the principal token
	 * @param _amount	the amount of the principal token wish to supply to AAVE
	 **/
	function _supplyToAAVE(address _asset, uint256 _amount) private {
		address lendingPoolAddress = ILendingPoolAddressesProvider(addressProvider).getLendingPool();
		ILendingPool lendingPool = ILendingPool(lendingPoolAddress);
		SafeERC20.safeApprove(IERC20(_asset), address(lendingPool), _amount);
		lendingPool.deposit(_asset, _amount, address(this), 0);
	}

	/**
	 * @dev redeem from aave protocol
	 * @param _asset 	the address of the principal token
	 * @param _amount	the amount of the principal token wish to withdraw from AAVE
	 **/
	function _redeemFromAAVE(address _asset, uint256 _amount) private {
		// lendingPool
		address lendingPoolAddress = ILendingPoolAddressesProvider(addressProvider).getLendingPool();
		ILendingPool lendingPool = ILendingPool(lendingPoolAddress);
		// protocol data provider
		aToken = _getATokenAddress(_asset);
		if (_amount == 0) {
			_amount = IERC20(aToken).balanceOf(address(this));
		}
		lendingPool.withdraw(_asset, _amount, address(this));
	}

	/**
	 * @dev get atoken address
	 * @param _asset 	the address of the principal token
	 **/
	function _getATokenAddress(address _asset) private view returns (address _aToken) {
		// protocol data provider
		uint8 number = 1;
		bytes32 id = bytes32(bytes1(number));
		address dataProviderAddress = ILendingPoolAddressesProvider(addressProvider).getAddress(id);
		IProtocolDataProvider protocolDataProvider = IProtocolDataProvider(dataProviderAddress);
		(_aToken, , ) = protocolDataProvider.getReserveTokensAddresses(_asset);
	}

	/**
	 * @dev mint token function to mint long and short token
	 * @param _isPrincipal 	true: principal, false:long/short token amount
	 * @param _to			the destination account token got burned
	 * @param _shortAmount 	the amount of the token to short
	 * @param _longAmount 	the amount of the token to long
	 **/
	function _mintTokens(
		bool _isPrincipal,
		address _to,
		uint256 _shortAmount,
		uint256 _longAmount
	) private {
		if (_isPrincipal == true) {
			// convert principal token amount to long/short token amount
			_shortAmount = _shortAmount.mul(PRECISION).div(valuePerShortToken);
			_longAmount = _longAmount.mul(PRECISION).div(valuePerLongToken);
		}
		if (_shortAmount != 0) {
			_shortToken.mint(_to, _shortAmount);
		}
		if (_longAmount != 0) {
			_longToken.mint(_to, _longAmount);
		}
	}

	/**
	 * @dev burn token function to burn long and short token
	 * @param _isPrincipal 	true: principal, false:long/short token amount
	 * @param _from			the destination account token got burned
	 * @param _shortAmount 	the amount of the token to short
	 * @param _longAmount 	the amount of the token to long
	 **/
	function _burnTokens(
		bool _isPrincipal,
		address _from,
		uint256 _shortAmount,
		uint256 _longAmount
	) private {
		if (_isPrincipal == true) {
			// convert principal token amount to long/short token amount
			_shortAmount = _shortAmount.mul(PRECISION).div(valuePerShortToken);
			_longAmount = _longAmount.mul(PRECISION).div(valuePerLongToken);
		}
		if (_shortAmount != 0) {
			_shortToken.burn(_from, _shortAmount);
		}
		if (_longAmount != 0) {
			_longToken.burn(_from, _longAmount);
		}
	}

	/**
	 * @dev communicate with oracle to get current trusted price
	 * @return price ratio of bidToken * PRECISION / principalToken -> the result comes with precision
	 **/
	function _getPrice() private view returns (int256) {
		(uint80 roundID, int256 price, uint256 startedAt, uint256 timeStamp, uint80 answeredInRound) = priceFeed.latestRoundData();
		return price;
	}

	/**
	 * @dev return user's long token equivalent principal token amount
	 **/
	function userLongPrincipalBalance(address userAddress) external view override returns (uint256 userLongAmount) {
		userLongAmount = _longToken.balanceOf(userAddress).mul(valuePerLongToken).div(PRECISION);
	}

	/**
	 * @dev return user's short token equivalent principal token amount
	 **/
	function userShortPrincipalBalance(address userAddress) external view override returns (uint256 userShortAmount) {
		userShortAmount = _shortToken.balanceOf(userAddress).mul(valuePerShortToken).div(PRECISION);
	}

	/**
	 * @dev claim AAVE token rewards
	 * @param stakedAAVEAddress_ stakedAAVE contract address
	 * @param amount_  The amount of AAVE to be claimed. Use type(uint).max to claim all outstanding rewards for the user.
	 */
	function claimAAVE(address stakedAAVEAddress_, uint256 amount_ ) external override {
		require(stakedAAVEAddress_ != address(0), "LosslessV2Pool: stakedAAVEAddress_ ZERO ADDRESS");
		address feeTo = ILosslessV2Factory(factory).feeTo();
		require(feeTo != address(0), "LosslessV2Pool: feeTo ZERO ADDRESS");

		IStakedToken stakedAAVE = IStakedToken(stakedAAVEAddress_);
		stakedAAVE.claimRewards(feeTo, amount_);
	}
}
