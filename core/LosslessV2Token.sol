// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import "./ERC20.sol";
import "../interfaces/ILosslessV2Pool.sol";

contract LosslessV2Token is ERC20 {
	address public adminPool;

	// limit only pool can mint token
	modifier onlyAdminPool() {
		require(msg.sender == adminPool, "LosslessV2Token: FORBIDDEN");
		_;
	}

	constructor(
		string memory _name,
		string memory _symbol,
		uint8 _decimals,
		address _adminPool
	) public ERC20(_name, _symbol, _decimals) {
		require(address(0) != _adminPool, "LosslessV2Token: set pool to the zero address");
		adminPool = _adminPool;
	}

	function mint(address _to, uint256 _amount) external onlyAdminPool returns (bool) {
		_mint(_to, _amount);
		return true;
	}

	function burn(address _from, uint256 _amount) external onlyAdminPool returns (bool) {
		_burn(_from, _amount);
		return true;
	}
}
