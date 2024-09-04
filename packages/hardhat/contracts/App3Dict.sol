//SPDX-License-Identifier: UNLICENSED
//This contract controls app-wide settings.
//For the hackathon, the scaffold-eth "debug contracts" is a sufficient admin interface
//to modify app-wide settings; an improved app manager interface is prioritized out of the MVP.
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.
import "hardhat/console.sol";

import "./IGamesController.sol";
import "./PayableOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract App3Dict is PayableOwnable, IGamesController {
	// State Variables
	// baseToken: The base unit other prices are denoted in,
	// which becomes more important when using Chainlink price feeds to accept payment in various tokens
	ERC20 private _baseToken; //baseToken() getter returns IERC20
	uint256 public gameSponsorMin;
	uint256 public questionSponsorMin;
	uint256 public defaultMaxQuestionBid;
	uint24 public sponsorFractionOfQuestionPool = 20*100000; // A percentage (e.g. 20 for 20%) * 10^5
	uint24 public defaultSponsorFractionOfOptionPool = 2*100000; // A percentage (e.g. 2 for 2%) * 10^5
	uint256 public publicGoodsPoolUnpaidBalance = 0;
	uint256 public publicGoodsPoolPaidOut = 0;
	bool public openToAnyLister = false; //true on testnet, usually
	mapping(address => bool) public approvedListers;

	event BaseTokenChange(
		IERC20 indexed oldBaseToken,
		IERC20 indexed newBaseToken
	);

	event GameSponsorMinChange(
		uint256 oldValue,
		uint256 newValue
	);

	event QuestionSponsorMinChange(
		uint256 oldValue,
		uint256 newValue
	);

	event DefaultMaxQuestionBidChanged(
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
		ERC20 baseTokenToSet
	)
		PayableOwnable(initialOwner)
	{
		_baseToken = baseTokenToSet;
		// NOTE: The .decimals() function is not part of the ERC-20 standard interface (IERC20)!
		// Verify support before using any particular token in the constructor.
		gameSponsorMin = 100 * 10 ** ERC20(_baseToken).decimals();
		questionSponsorMin = 5 * 10 ** ERC20(_baseToken).decimals();
		defaultMaxQuestionBid = 100 * 10 ** ERC20(_baseToken).decimals();
		emit BaseTokenChange(ERC20(address(0)), _baseToken);
		emit GameSponsorMinChange(0, gameSponsorMin);
		emit QuestionSponsorMinChange(0, questionSponsorMin);
		emit DefaultMaxQuestionBidChanged(0, defaultMaxQuestionBid);
	}

	function baseToken() public view returns (IERC20) {
		return _baseToken;
	}

	// Use with caution, especially if base token isn't a 1:1 value to the old!
	function changeBaseToken(
		ERC20 newBaseToken
	) public onlyOwner {
		emit BaseTokenChange(
			_baseToken,
			newBaseToken
		);
		_baseToken = newBaseToken;
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

	function changeDefaultMaxQuestionBid(
		uint256 newValue
	) public onlyOwner {
		emit DefaultMaxQuestionBidChanged(
			defaultMaxQuestionBid,
			newValue
		);
		defaultMaxQuestionBid = newValue;
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
		require(_baseToken.transferFrom(msg.sender, address(this), amount), 'Donation transfer failed.');
	}

	function tip(
			uint256 amount
	) public {
		emit TipReceived(
			msg.sender, //must have prior allowance
			amount
		);
		require(_baseToken.transferFrom(msg.sender, address(this), amount), 'Tip transfer failed.');
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
		require(_baseToken.transfer(payTo, payAmount), 'Public goods payout failed.');
	}

	function payoutBaseTokens(
		address payTo,
		uint256 payAmount
	) public onlyOwner {
		require(
			payAmount <= (_baseToken.balanceOf(address(this))-publicGoodsPoolUnpaidBalance),
			'Insufficient funds to make the requested withdrawal!'
		);
		emit BaseTokensPayout(
			payTo,
			payAmount
		);
		require(_baseToken.transfer(payTo, payAmount), 'Payout failed.');
	}

	function withdrawERC20Tokens(
		address,
		uint256,
		IERC20
	) override public pure {
		revert('Arbitrary token withdrawal is disabled to protect the public goods balance.');
	}

	// If changing away from the controller architecture,
	// might need to change visibility here to public.
	function isAllowedToList(
		address potentialLister
	) external view returns (bool) {
		return (openToAnyLister || approvedListers[potentialLister]);
	}

}
