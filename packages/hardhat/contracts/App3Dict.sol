//SPDX-License-Identifier: UNLICENSED
//This contract controls app-wide settings.
//For the hackathon, the scaffold-eth "debug contracts" is a sufficient admin interface
//to modify app-wide settings; an improved app manager interface is prioritized out of the MVP.
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.
import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract App3Dict is Ownable{
	// State Variables
	// baseToken: The base unit other prices are denoted in,
	// which becomes more important when using Chainlink price feeds to accept payment in various tokens
	ERC20 public baseToken;
	uint256 public gameSponsorMin;
	uint256 public questionSponsorMin;
	uint24 public sponsorFractionOfQuestionPool = 20*100000; // A percentage (e.g. 20 for 20%) * 10^5
	uint24 public defaultSponsorFractionOfOptionPool = 2*100000; // A percentage (e.g. 2 for 2%) * 10^5
	uint256 public publicGoodsPoolUnpaidBalance = 0;
	uint256 public publicGoodsPoolPaidOut = 0;
	bool public openToAnyLister = false; //true on testnet, usually
	mapping(address => bool) public approvedListers;

	event BaseTokenChange(
		ERC20 indexed oldBaseToken,
		ERC20 indexed newBaseToken
	);

	event GameSponsorMinChange(
		uint256 oldValue,
		uint256 newValue
	);

	event QuestionSponsorMinChange(
		uint256 oldValue,
		uint256 newValue
	);

	event SponsorFractionOfQuestionPoolChange(
		uint24 oldValue,
		uint24 newValue
	);

	event DefaultSponsorFractionOfOptionPoolChange(
		uint24 oldValue,
		uint24 newValue
	);

	event OpenToAnyListerChange(
		bool oldValue,
		bool newValue
	);

	event ApprovedListerChange(
		address lister,
		bool wasApproved,
		bool isApproved
	);

	event TipReceived(
		address donor,
		uint256 amount
	);

	event PublicGoodsPoolDonationReceived(
		address donor,
		uint256 amount,
		uint256 newPublicGoodsPoolUnpaidBalance
	);

	event PublicGoodsPoolPayout(
		address paidTo,
		uint256 amountPaidOut,
		uint256 newTotalPaidOut
	);

	event BaseTokensPayout(
		address paidTo,
		uint256 amountPaidOut
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

	// Use with caution, especially if base token isn't a 1:1 value to the old!
	function changeBaseToken(
		ERC20 newBaseToken
	) public onlyOwner {
		emit BaseTokenChange(
			baseToken,
			newBaseToken
		);
		baseToken = newBaseToken;
	}

	function changeGameSponsorMin(
			uint256 newValue
	) public onlyOwner {
		emit GameSponsorMinChange(
			gameSponsorMin,
			newValue
		);
		gameSponsorMin = newValue;
	}

	function changeQuestionSponsorMin(
			uint256 newValue
	) public onlyOwner {
		emit QuestionSponsorMinChange(
			questionSponsorMin,
			newValue
		);
		questionSponsorMin = newValue;
	}

	function changeSponsorFractionOfQuestionPool(
			uint24 newValue
	) public onlyOwner {
		emit SponsorFractionOfQuestionPoolChange(
			sponsorFractionOfQuestionPool,
			newValue
		);
		sponsorFractionOfQuestionPool = newValue;
	}

	function changeDefaultSponsorFractionOfOptionPool(
			uint24 newValue
	) public onlyOwner {
		emit DefaultSponsorFractionOfOptionPoolChange(
			defaultSponsorFractionOfOptionPool,
			newValue
		);
		defaultSponsorFractionOfOptionPool = newValue;
	}

	function changeOpenToAnyLister(
			bool newValue
	) public onlyOwner {
		emit OpenToAnyListerChange(
			openToAnyLister,
			newValue
		);
		openToAnyLister = newValue;
	}

	function changeApprovedLister(
			address lister,
			bool shouldBeApproved
	) public onlyOwner {
		emit ApprovedListerChange(
			lister,
			approvedListers[lister],
			shouldBeApproved
		);
		approvedListers[lister] = shouldBeApproved;
	}

	function donateToPublicGoods(
			uint256 amount
	) public {
		publicGoodsPoolUnpaidBalance += amount;
		emit PublicGoodsPoolDonationReceived(
			msg.sender, //must have prior allowance
			amount,
			publicGoodsPoolUnpaidBalance
		);
		require(baseToken.transferFrom(msg.sender, address(this), amount), 'Donation transfer failed.');
	}

	function tip(
			uint256 amount
	) public {
		emit TipReceived(
			msg.sender, //must have prior allowance
			amount
		);
		require(baseToken.transferFrom(msg.sender, address(this), amount), 'Tip transfer failed.');
	}

	function payoutPublicGoods(
			address payTo,
			uint256 payAmount
	) public onlyOwner {
		require(payAmount <= publicGoodsPoolUnpaidBalance, 'Insufficient funds in public goods pool!');
		emit PublicGoodsPoolPayout(
			payTo,
			payAmount,
			publicGoodsPoolPaidOut + payAmount
		);
		publicGoodsPoolPaidOut += payAmount;
		publicGoodsPoolUnpaidBalance -= payAmount;
		require(baseToken.transfer(payTo, payAmount), 'Public goods payout failed.');
	}

	function payoutBaseTokens(
		address payTo,
		uint256 payAmount
	) public onlyOwner {
		require(
			payAmount <= (baseToken.balanceOf(address(this))-publicGoodsPoolUnpaidBalance),
			'Insufficient funds to make the requested withdrawal!'
		);
		emit BaseTokensPayout(
			payTo,
			payAmount
		);
		require(baseToken.transfer(payTo, payAmount), 'Payout failed.');
	}

	/**
	 * Function that allows the owner to withdraw all the Ether in the contract
	 * The function can only be called by the owner of the contract as defined by the modifier
	 */
	function payoutEth(address payable recipient) public onlyOwner {
		(bool success, ) = payable(recipient).call{ value: address(this).balance }("");
		require(success, "Failed to send Ether");
	}

	/**
	 * Function that allows the contract to receive ETH
	 */
	receive() external payable {}
}
