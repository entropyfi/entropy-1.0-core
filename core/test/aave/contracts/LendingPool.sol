// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import "../interfaces/ILendingPool.sol";
import "../../token/ERC20Token.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract LendingPool is ILendingPool {
	using SafeMath for uint256;
	address public aToken;

	constructor(address _aToken) public {
		aToken = _aToken;
	}

	function deposit(
		address asset,
		uint256 amount,
		address onBehalfOf,
		uint16 referralCode
	) external override {
		// transfer asset to lendingPool
		SafeERC20.safeTransferFrom(IERC20(asset), msg.sender, address(this), amount);
		// transfer atoken to user
		SafeERC20.safeTransfer(IERC20(aToken), onBehalfOf, amount);

		emit Deposit(asset, msg.sender, onBehalfOf, amount, referralCode);
	}

	function withdraw(
		address asset,
		uint256 amount,
		address to
	) external override returns (uint256) {
		uint256 userBalance = IERC20(aToken).balanceOf(msg.sender);

		uint256 amountToWithdraw = amount;

		if (amount == type(uint256).max) {
			amountToWithdraw = userBalance;
		}
		// aToken interest is 1.5
		ERC20Token(aToken)._burn(msg.sender, amountToWithdraw);

		// asset
		SafeERC20.safeTransfer(IERC20(asset), to, amountToWithdraw.mul(15000).div(10000));

		emit Withdraw(asset, msg.sender, to, amountToWithdraw);

		return amountToWithdraw;
	}
}
