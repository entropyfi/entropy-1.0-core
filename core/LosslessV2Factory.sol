// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import "./LosslessV2Token.sol";
import "./LosslessV2Pool.sol";
import "../interfaces/ILosslessV2Factory.sol";
import "./ERC20.sol";

contract LosslessV2Factory is ILosslessV2Factory {
	address public override feeTo;
	address public override DAO;
	address public override pendingDAO;
	uint256 public override feePercent; //  usage: fee = totalInterest.mul(feePercent).div(PRECISION)

	// all pool related
	address[] public override allPools;
	// BTC - USDT: USDT, DAI, USDC
	//     bidToken ----> principalToken -> poolAddress
	//         |                   |          |
	mapping(address => mapping(address => address)) public override getPool;
	mapping(address => bool) public override isPoolActive;

	mapping(address => address) public override getPoolShortToken;
	mapping(address => address) public override getPoolLongToken;
	mapping(address => address) public override getPoolSponsorToken;

	modifier onlyDAO() {
		require(msg.sender == DAO, "LosslessV2Factory: FORBIDDEN");
		_;
	}

	constructor(address _DAO) public {
		require(_DAO != address(0), "LosslessV2Factory: set DAO the zero address");
		DAO = _DAO; // default is DAO
	}

	function allPoolsLength() external view override returns (uint256) {
		return allPools.length;
	}

	function createPool(
		address bidToken,
		address principalToken,
		address addressProvider,
		address aggregator,
		uint256 biddingDuration,
		uint256 gamingDuration,
		string memory tokenName,
		string memory tokenSymbol
	) external override onlyDAO {
		// pool setting check
		require(bidToken != principalToken, "LosslessV2Factory: IDENTICAL_ADDRESSES");
		require((bidToken != address(0)) && (principalToken != address(0)), "LosslessV2Factory: ZERO_ADDRESS");
		require(addressProvider != address(0), "LosslessV2Factory: ADDRESS PROVIDER ZERO_ADDRESS");
		require(aggregator != address(0), "LosslessV2Factory: AGGREGATOR ZERO_ADDRESS");
		require(getPool[bidToken][principalToken] == address(0), "LosslessV2Factory: POOL_EXISTS");
		require(biddingDuration > 0, "LosslessV2Factory: BIDDING DURATION INVALID_AMOUNT");
		require(gamingDuration > 0, "LosslessV2Factory: GAMING DURATION INVALID_AMOUNT");
		// token name and symbol check
		require(bytes(tokenName).length != 0, "LosslessV2Factory: TOKEN NAME INPUT IS INVALID");
		require(bytes(tokenSymbol).length != 0, "LosslessV2Factory: TOKEN SYMBOL INPUT IS INVALID");

		bytes32 salt = keccak256(abi.encodePacked(allPools.length, bidToken, principalToken, addressProvider, aggregator));
		LosslessV2Pool newPool = new LosslessV2Pool{ salt: salt }(bidToken, principalToken, addressProvider, aggregator, biddingDuration, gamingDuration);
		(address shortToken, address longToken, address sponsorToken) = _initializeTokens(
			tokenName,
			tokenSymbol,
			ERC20(principalToken).decimals(),
			address(newPool)
		);
		newPool.initialize(shortToken, longToken, sponsorToken);
		// save pool address to pool related
		getPool[bidToken][principalToken] = address(newPool);
		allPools.push(address(newPool));
		isPoolActive[address(newPool)] = true;
		// save pool tokens related
		getPoolShortToken[address(newPool)] = shortToken;
		getPoolLongToken[address(newPool)] = longToken;
		getPoolSponsorToken[address(newPool)] = sponsorToken;

		emit PoolCreated(bidToken, principalToken, address(newPool), allPools.length);
	}

	///@dev only DAO can call this function
	function terminatePool(address pool) external onlyDAO returns (bool) {
		require(isPoolActive[pool] == true, "LosslessV2Factory: POOL MUST BE ACTIVE");

		// call pool termination function to
		LosslessV2Pool(pool).poolTermination();
		// update pool related
		isPoolActive[pool] = false;

		emit PoolTerminated(pool);
		return true;
	}

	function _initializeTokens(
		string memory _tokenName,
		string memory _tokenSymbol,
		uint8 _decimals,
		address _pool
	)
		private
		returns (
			address shortToken,
			address longToken,
			address sponsorToken
		)
	{
		require(_pool != address(0), "LosslessV2Factory: ADDRESS PROVIDER ZERO_ADDRESS");

		// create a list of tokens for the new pool
		shortToken = _createToken(string(abi.encodePacked("st", _tokenName)), string(abi.encodePacked("st", _tokenSymbol)), _decimals, _pool);
		longToken = _createToken(string(abi.encodePacked("lg", _tokenName)), string(abi.encodePacked("lg", _tokenSymbol)), _decimals, _pool);
		sponsorToken = _createToken(string(abi.encodePacked("sp", _tokenName)), string(abi.encodePacked("sp", _tokenSymbol)), _decimals, _pool);
	}

	function _createToken(
		string memory _name,
		string memory _symbol,
		uint8 _decimals,
		address _pool
	) private returns (address) {
		bytes32 salt = keccak256(abi.encodePacked(_name, _symbol, _decimals, _pool));
		LosslessV2Token newToken = new LosslessV2Token{ salt: salt }(_name, _symbol, _decimals, _pool);

		return address(newToken);
	}

	// below functions all limited to DAO

	/**
	 * @dev	 The default DAO can assign the receiver of the trading fee
	 * @param _feeTo	the receiver of the trading fee
	 **/
	function setFeeTo(address _feeTo) external override onlyDAO {
		require(_feeTo != address(0), "LosslessV2Factory: set feeTo to the zero address");
		feeTo = _feeTo;
		emit FeeToChanged(feeTo);
	}

	/**
	 * @dev	 only DAO can set the feePercent (usage: fee = totalInterest.mul(feePercent).div(PRECISION))
	 * @param _feePercent	percentage of total interest as trading fee: 1% - 100, 10% - 1000, 100% - 10000
	 **/
	function setFeePercent(uint256 _feePercent) external override onlyDAO {
		require(_feePercent < 10**4, "LosslessV2Factory: feePercent must be less than PRECISION");
		feePercent = _feePercent;
		emit FeePercentChanged(feePercent);
	}

	/**
	 * @dev The default DAO and DAO can assign pendingDAO to others by calling `setDAO`
	 * @param _pendingDAO	new DAO address
	 **/
	function setPendingDAO(address _pendingDAO) external override onlyDAO {
		require(_pendingDAO != address(0), "LosslessV2Factory: set _pendingDAO to the zero address");
		pendingDAO = _pendingDAO;
		emit proposeDAOChange(pendingDAO);
	}

	/**
	 * @dev double confirm on whether to accept the pending changes or not
	 **/
	function setDAO() external override onlyDAO {
		require(pendingDAO != address(0), "LosslessV2Factory: set _DAO to the zero address");
		DAO = pendingDAO;
		pendingDAO = address(0);
		emit DAOChanged(DAO);
	}
}
