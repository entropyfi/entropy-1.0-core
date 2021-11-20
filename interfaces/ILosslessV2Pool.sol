// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

interface ILosslessV2Pool {
	// defined and controls all game logic related variables
	struct GameStatus {
		bool isShortLastRoundWinner; // record whether last round winner
		bool isFirstUser; // check if the user is the first one to enter the game or not
		bool isFirstRound; // is this game the first round of the entire pool?
		uint256 gameRound; // count for showing current game round
		uint256 durationOfGame; // which should be 6 days in default
		uint256 durationOfBidding; // which should be 1 days in default
		uint256 lastUpdateTimestamp; // the timestamp when last game logic function been called
		int256 initialPrice; // game initial price
		int256 endPrice; // game end price
		PoolStatus currState; // current pool status
	}

	// token info for current pool
	struct PoolTokensInfo {
		address longToken;
		address shortToken;
		address sponsorToken;
	}

	// # ENUM FOR POOL STATUS
	/*  
      PoolStatus Explaination
      *****
        Locked ------ game period. interacting with compound
        Accepting --- users can adding or reducing the bet
        FirstGame --- only been used for the first round
		Terminated -- only when special cases admin decided to close the pool

      Notation
      ******
        /name/ - status name
        [name] - function call name

      Workflow
      *******  

                                    
                     /Accepting/            /Locked/         /Accepting/				/Terminated/
                          |                     |                | 							 |
    [startFirstRound] ---------> [startGame] -------> [endGame] ---> [poolTermination] --------------->
                                      ^                    | |
                                      |                    | record time
                                       --------------------
                                                 |
                                            /Accepting/
    */
	enum PoolStatus {
		FirstGame,
		Locked,
		Accepting,
		Terminated
	}

	// ## DEFINE USER OPERATION EVENTS
	event Deposit(uint256 shortPrincipalAmount, uint256 longPrincipalAmount);
	event Withdraw(bool isAToken, uint256 shortTokenAmount, uint256 longTokenAmount);
	event SponsorDeposit(uint256 principalAmount);
	event SponsorWithdraw(uint256 sponsorTokenAmount);
	// ## DEFINE GAME OPERATION EVENTS
	event UpdateTokenValue(uint256 valuePerShortToken, uint256 valuePerLongToken);
	event AnnounceWinner(bool isShortLastRoundWinner, int256 initialPrice, int256 endPrice);

	// ## PUBLIC VARIABLES
	function factory() external view returns (address);

	function bidToken() external view returns (address);

	function principalToken() external view returns (address);

	function aToken() external view returns (address);

	function addressProvider() external view returns (address);

	// ### GAME SETTING VARIABLES
	function inPoolTimestamp(address userAddress) external view returns (uint256);

	// ## STATE-CHANGING FUNCTION
	/* 
		initialize: 		initialize the game
		startFirstRound: 	start the frist round logic
		startGame: 			start game -> pool lock supply principal to AAVE, get start game price
		endGame: 			end game -> pool unlock redeem fund to AAVE, get end game price
		poolTermination:	terminate the pool, no more game, but user can still withdraw fund
    */
	function initialize(
		address shortToken_,
		address longToken_,
		address sponsorToken_
	) external;

	function startFirstRound() external; // only be called to start the first Round

	function startGame() external; // called after bidding duration

	function endGame() external; // called after game duraion

	///@dev admin only
	function poolTermination() external; // called after selectWinner only by admin

	// user actions in below, join game, add, reduce or withDraw all fund
	/* 
		deposit: 			adding funds can be either just long or short or both
		withdraw: 			reduce funds can be either just long or short or both
		swap: 				change amount of tokens from long -> short / short -> long
		sponsorDeposit:		deposit principal to the pool as interest sponsor
		sponsorWithdraw:	withdraw sponsor donation from the pool
    */
	function deposit(uint256 shortPrincipalAmount, uint256 longPrincipalAmount) external;

	function withdraw(
		bool isAToken,
		uint256 shortTokenAmount,
		uint256 longTokenAmount
	) external;

	function swap(bool fromLongToShort, uint256 swapTokenAmount) external;

	function sponsorDeposit(uint256 principalAmount) external;

	function sponsorWithdraw(uint256 sponsorTokenAmount) external;
	
	function claimAAVE(address stakedAAVEAddress_, uint256 amount_ ) external;

	// view functions to return user balance
	function userLongPrincipalBalance(address userAddress) external view returns (uint256);

	function userShortPrincipalBalance(address userAddress) external view returns (uint256);
}
