// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import "../interfaces/IPriceOracleGetter.sol";

contract PriceOracleGetter is IPriceOracleGetter {
	mapping(address => uint256) public prices;
	address public owner;

	constructor() public {
		owner = msg.sender;
	}

	function getAssetPrice(address _asset) external view override returns (uint256) {
		return prices[_asset];
	}

	function getAssetsPrices(address[] calldata _assets) external view override returns (uint256[] memory) {
		uint256[] memory _prices = new uint256[](_assets.length);
		for (uint256 i = 0; i < _assets.length; i++) {
			_prices[i] = prices[_assets[i]];
		}
		// uint256[] memory _prices = new uint256[](2);
		// _prices[0] = 2;
		// _prices[1] = 1;
		return _prices;
	}

	function setAssetsPrices(address[] calldata _assets, uint256[] calldata _prices) external override {
		for (uint256 i = 0; i < _assets.length; i++) {
			prices[_assets[i]] = _prices[i];
		}
	}
}
