//SPDX-License-Identifier: UNLICENSED
//A simple extension of Ownable that allows withdrawal of funds sent to a contract.
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PayableOwnable is Ownable {

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

	/**
	 * Function that allows the owner to withdraw all the Ether in the contract
	 * The function can only be called by the owner of the contract as defined by the modifier
	 */
	function payoutEth(address payable recipient) public onlyOwner {
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
