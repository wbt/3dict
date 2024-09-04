//SPDX-License-Identifier: UNLICENSED
//A simple extension of Ownable that allows withdrawal of funds sent to a contract.
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PayableOwnable is Ownable {

	event ERC20Withdrawal(
		address recipient,
		uint256 amountPaidOut,
		IERC20 tokenContract
	);

	event EthWithdrawal(
		address recipient,
		uint256 amountPaidOut
	);

	constructor(
		address payable initialOwner
	)
		Ownable(initialOwner)
	{
	}

	function withdrawERC20Tokens(
		address recipient,
		uint256 payAmount,
		IERC20 tokenContract
	) virtual public onlyOwner {
		require(_withdrawERC20Tokens(
			recipient,
			payAmount,
			tokenContract
		), 'Token withdrawal failed.');
	}

	function _withdrawERC20Tokens(
		address recipient,
		uint256 payAmount,
		IERC20 tokenContract
	) internal returns (bool success) {
		//Balance check should be done in ERC20 contract transfer fn
		tokenContract.transfer(recipient, payAmount);
		emit ERC20Withdrawal(
			recipient,
			payAmount,
			tokenContract
		);
		return tokenContract.transfer(recipient, payAmount);
	}

	/**
	 * Function that allows the owner to withdraw all the Ether in the contract
	 * The function can only be called by the owner of the contract as defined by the modifier
	 */
	function payoutEth(address payable recipient) virtual public onlyOwner {
		emit EthWithdrawal(
			recipient,
			address(this).balance
		);
		(bool success, ) = payable(recipient).call{ value: address(this).balance }("");
		require(success, "Failed to send Ether");
	}

	/**
	 * Function that allows the contract to receive ETH
	 */
	receive() external payable {}
}
