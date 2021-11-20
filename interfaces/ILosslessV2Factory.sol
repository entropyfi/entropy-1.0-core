// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

interface ILosslessV2Factory {
	// event related
	event PoolCreated(address indexed bidToken, address indexed principalToken, address pool, uint256 allPoolLength);
	event PoolTerminated(address pool);
	event FeeToChanged(address feeTo);
	event FeePercentChanged(uint256 feePercent);
	event proposeDAOChange(address pendingDAO);
	event DAOChanged(address DAO);

	function allPools(uint256) external view returns (address pool);

	function allPoolsLength() external view returns (uint256);

	function getPool(address bidToken, address principalToken) external view returns (address pool);

	function isPoolActive(address) external view returns (bool);

	function getPoolShortToken(address) external view returns (address);

	function getPoolLongToken(address) external view returns (address);

	function getPoolSponsorToken(address) external view returns (address);

	function createPool(
		address bidToken,
		address principalToken,
		address addressProvider,
		address aggregator,
		uint256 biddingDuration,
		uint256 gamingDuration,
		string memory tokenName,
		string memory tokenSymbol
	) external;

	// all fee related getter functions
	function feeTo() external view returns (address);

	function DAO() external view returns (address);

	function pendingDAO() external view returns (address);

	function feePercent() external view returns (uint256);

	// only admin functions
	// The default DAO is admin but admin can assign this role to others by calling `setDAO`
	function setFeeTo(address) external;

	function setFeePercent(uint256 _feePercent) external;

	function setPendingDAO(address _pendingDAO) external;

	function setDAO() external;
}
