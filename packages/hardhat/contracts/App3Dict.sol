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

	event BaseTokenChanged(
		IERC20 indexed oldBaseToken,
		IERC20 indexed newBaseToken
	);

	event GameSponsorMinChanged(
		uint256 oldValue,
		uint256 newValue
	);

	event QuestionSponsorMinChanged(
		uint256 oldValue,
		uint256 newValue
	);

	event DefaultMaxQuestionBidChanged(
		uint256 oldValue,
		uint256 newValue
	);

	event SponsorFractionOfQuestionPoolChanged(
		uint24 oldValue,
		uint24 newValue
	);

	event DefaultSponsorFractionOfOptionPoolChanged(
		uint24 oldValue,
		uint24 newValue
	);

	event OpenToAnyListerChanged(
		bool oldValue,
		bool newValue
	);

	event ApprovedListerChanged(
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
		emit BaseTokenChanged(ERC20(address(0)), _baseToken);
		emit GameSponsorMinChanged(0, gameSponsorMin);
		emit QuestionSponsorMinChanged(0, questionSponsorMin);
		emit DefaultMaxQuestionBidChanged(0, defaultMaxQuestionBid);
	}

	function baseToken() public view returns (IERC20) {
		return _baseToken;
	}

	// Use with caution, especially if base token isn't a 1:1 value to the old!
	function changeBaseToken(
		ERC20 newBaseToken
	) public onlyOwner {
		_changeBaseToken(newBaseToken);
	}

	function _changeBaseToken(
		ERC20 newBaseToken
	) private {
		emit BaseTokenChanged(
			_baseToken,
			newBaseToken
		);
		_baseToken = newBaseToken;
	}

	function changeGameSponsorMin(
		uint256 newValue
	) public onlyOwner {
		_changeGameSponsorMin(newValue);
	}

	function _changeGameSponsorMin(
		uint256 newValue
	) private {
		emit GameSponsorMinChanged(
			gameSponsorMin,
			newValue
		);
		gameSponsorMin = newValue;
	}

	function changeQuestionSponsorMin(
		uint256 newValue
	) public onlyOwner {
		_changeQuestionSponsorMin(newValue);
	}

	function _changeQuestionSponsorMin(
		uint256 newValue
	) private {
		emit QuestionSponsorMinChanged(
			questionSponsorMin,
			newValue
		);
		questionSponsorMin = newValue;
	}

	function changeDefaultMaxQuestionBid(
		uint256 newValue
	) public onlyOwner {
		_changeDefaultMaxQuestionBid(newValue);
	}

	function _changeDefaultMaxQuestionBid(
		uint256 newValue
	) private {
		emit DefaultMaxQuestionBidChanged(
			defaultMaxQuestionBid,
			newValue
		);
		defaultMaxQuestionBid = newValue;
	}

	function changeSponsorFractionOfQuestionPool(
		uint24 newValue
	) public onlyOwner {
		_changeSponsorFractionOfQuestionPool(newValue);
	}

	function _changeSponsorFractionOfQuestionPool(
		uint24 newValue
	) private {
		emit SponsorFractionOfQuestionPoolChanged(
			sponsorFractionOfQuestionPool,
			newValue
		);
		sponsorFractionOfQuestionPool = newValue;
	}

	function changeDefaultSponsorFractionOfOptionPool(
		uint24 newValue
	) public onlyOwner {
		_changeDefaultSponsorFractionOfOptionPool(newValue);
	}

	function _changeDefaultSponsorFractionOfOptionPool(
		uint24 newValue
	) private {
		emit DefaultSponsorFractionOfOptionPoolChanged(
			defaultSponsorFractionOfOptionPool,
			newValue
		);
		defaultSponsorFractionOfOptionPool = newValue;
	}

	function changeOpenToAnyLister(
		bool newValue
	) public onlyOwner {
		_changeOpenToAnyLister(newValue);
	}

	function _changeOpenToAnyLister(
		bool newValue
	) private {
		emit OpenToAnyListerChanged(
			openToAnyLister,
			newValue
		);
		openToAnyLister = newValue;
	}

	function changeApprovedLister(
		address lister,
		bool shouldBeApproved
	) public onlyOwner {
		_changeApprovedLister(lister, shouldBeApproved);
	}

	function _changeApprovedLister(
		address lister,
		bool shouldBeApproved
	) private {
		emit ApprovedListerChanged(
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
		_payoutPublicGoods(
			payTo,
			payAmount
		);
	}

	function _payoutPublicGoods(
		address payTo,
		uint256 payAmount
	) private {
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
		_payoutBaseTokens(
			payTo,
			payAmount
		);
	}

	function _payoutBaseTokens(
		address payTo,
		uint256 payAmount
	) private {
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
