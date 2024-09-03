//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.
import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * A smart contract that allows changing a state variable of the contract and tracking the changes
 * It also allows the owner to withdraw the Ether in the contract
 * @author BuidlGuidl
 */
contract App3Dict is Ownable{
	// State Variables
	string public greeting = "Building Unstoppable Apps!!!";
	bool public premium = false;
	uint256 public totalCounter = 0;
	mapping(address => uint) public userGreetingCounter;
	// baseToken: The base unit other prices are denoted in,
	// which becomes more important when using Chainlink price feeds to accept payment in various tokens
	ERC20 public baseToken;
	uint256 public gameSponsorMin;
	uint256 public questionSponsorMin;
	uint24 public sponsorFractionOfQuestionPool = 20*100000; // A percentage (e.g. 20 for 20%) * 10^5
	uint24 public defaultSponsorFractionOfOptionPool = 2*100000; // A percentage (e.g. 2 for 2%) * 10^5
	uint256 PublicGoodsPoolUnpaidBalance = 0;
	uint256 PublicGoodsPoolPaidOut = 0;

	// Events: a way to emit log statements from smart contract that can be listened to by external parties
	event GreetingChange(
		address indexed greetingSetter,
		string newGreeting,
		bool premium,
		uint256 value
	);

	// Constructor: Called once on contract deployment
	// Check packages/hardhat/deploy/00_deploy_your_contract.ts
	constructor(
		address payable initialOwner,
		ERC20 _baseToken
	)
		Ownable(initialOwner)
	{
		baseToken = _baseToken;
		// NOTE: The .decimals() function is not part of the ERC-20 standard interface (IERC20)!
		// Verify support before using any particular token in the constructor.
		gameSponsorMin = 100 * 10 ** ERC20(baseToken).decimals();
		questionSponsorMin = 5 * 10 ** ERC20(baseToken).decimals();
	}

	/**
	 * Function that allows anyone to change the state variable "greeting" of the contract and increase the counters
	 *
	 * @param _newGreeting (string memory) - new greeting to save on the contract
	 */
	function setGreeting(string memory _newGreeting) public payable {
		// Print data to the hardhat chain console. Remove when deploying to a live network.
		console.log(
			"Setting new greeting '%s' from %s",
			_newGreeting,
			msg.sender
		);

		// Change state variables
		greeting = _newGreeting;
		totalCounter += 1;
		userGreetingCounter[msg.sender] += 1;

		// msg.value: built-in global variable that represents the amount of ether sent with the transaction
		if (msg.value > 0) {
			premium = true;
		} else {
			premium = false;
		}

		// emit: keyword used to trigger an event
		emit GreetingChange(msg.sender, _newGreeting, msg.value > 0, msg.value);
	}

	/**
	 * Function that allows the owner to withdraw all the Ether in the contract
	 * The function can only be called by the owner of the contract as defined by the modifier
	 */
	function withdraw() public onlyOwner {
		(bool success, ) = payable(owner()).call{ value: address(this).balance }("");
		require(success, "Failed to send Ether");
	}

	/**
	 * Function that allows the contract to receive ETH
	 */
	receive() external payable {}
}
