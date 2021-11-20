// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import "../interfaces/ILendingPoolAddressesProvider.sol";

contract LendingPoolAddressesProvider is ILendingPoolAddressesProvider {
	address public dataProvider;
	address public lendingPool;
	address public priceOracle;

	constructor(
		address _dataProvider,
		address _lendingPool,
		address _PriceOracle
	) public {
		dataProvider = _dataProvider;
		lendingPool = _lendingPool;
		priceOracle = _PriceOracle;
	}

	function getAddress(bytes32 id) external view override returns (address) {
		return dataProvider;
	}

	function getLendingPool() external view override returns (address) {
		return lendingPool;
	}

	function getPriceOracle() external view override returns (address) {
		return priceOracle;
	}
}
