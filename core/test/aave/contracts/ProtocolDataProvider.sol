// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import "../interfaces/IProtocolDataProvider.sol";

contract ProtocolDataProvider is IProtocolDataProvider {
	address public aToken;
	address public stableDebtToken;
	address public variableDebtToken;

	constructor(
		address _aToken,
		address _stableDebtToken,
		address _variableDebtToken
	) public {
		aToken = _aToken;
		stableDebtToken = _stableDebtToken;
		variableDebtToken = _variableDebtToken;
	}

	function getReserveTokensAddresses(address asset)
		external
		view
		override
		returns (
			address aTokenAddress,
			address stableDebtTokenAddress,
			address variableDebtTokenAddress
		)
	{
		aTokenAddress = aToken;
		stableDebtTokenAddress = stableDebtToken;
		variableDebtTokenAddress = variableDebtToken;
	}
}
