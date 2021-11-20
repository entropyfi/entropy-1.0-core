// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

/************
@title IPriceOracle interface
@notice Interface for the Aave price oracle.*/
interface IPriceOracleGetter {
	function getAssetPrice(address _asset) external view returns (uint256);

	/***********
    @dev returns the asset price in ETH
     */
	function getAssetsPrices(address[] calldata _assets) external view returns (uint256[] memory);

	/***********
    @dev sets the asset price, in wei
     */
	function setAssetsPrices(address[] calldata _assets, uint256[] calldata _prices) external;
}
