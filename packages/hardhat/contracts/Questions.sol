//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "./IQuestionsController.sol";
import "./PayableOwnable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Questions is PayableOwnable {

	/*
	//One previously considered alternate implementation was to
	//have a question struct, like this:
	struct Option {
		string text; //up to 140 chars
		uint16 resolutionFraction;
		mapping(address => uint) playerPositions;
		uint optionPool;
	}
	//and then include that within the Questions struct, like this:
	Option[] options; //max length 26
	//instead of
	string[] options; //and other parallel arrays.
	However, attempting to construct such a struct produces the error
	"Struct containing a (nested) mapping cannot be constructed."
	//Using an empty state variable like this:
	mapping(address => uint) emptyMap;
	//and then in addOptions copying it over like this:
	mapping(address => uint) storage em = emptyMap;
	//for use in a constructor like this:
	rows[rowID].options.push(Question({text: options[i]}));
	//seems like it would risk having any modifications to that mapping
	//in the new question affect all others copied from the same source.
	//With the struct strategy, resolution looks a bit different:
	for(uint8 i=0; i<resolutionFractions.length; i++) {
		rows[rowID].options[i].resolutionFraction = resolutionFractions[i];
	}
	*/

	struct Question {
		address lister;
		uint game; //immutable
		mapping(address => uint) sponsors; // uint is amount sponsored, in base tokens.
		uint totalSponsoredAmount;
		string[] options; //up to 26 strings each up to 140 chars
		bool[] optionRemoved;
		uint16[] resolutionFractions; //should total 10000 //or should that be -1000*sponsorFractionOfOptionPool?
		mapping(address => uint)[] playerPositions; //denominated in TICKETS
		//mapping(address => uint)[] playerFundsInOptions; //doesn't seem necessary to track
		uint[] optionPoolsTokens; //sum of money (tokens) put in to that
		uint[] optionPoolsTickets; //sum over players
		uint optionPoolsTokensSum; // sum of the above array, but helps accelerate math
		//playerTotalInputs: value is net amount total amount put in, in base tokens.
		//Adjusts only on moving tokens in and out of question, not among options.
		//Can't remove more until resolution, in case it's unresolvable and moves incl. winnings are reversed.
		mapping(address => int) playerTotalInputs; // Could be negative if player had net winnings
		mapping(address => uint) playerFreeBalanceOnQuestion; // Don't set directly! Use _adjustPlayerFreeBalance only.
		uint freeBalanceSum; // Don't set directly! Use _adjustPlayerFreeBalance only.
		bool isResolved; //irreversible
		bool unresolvable; //irreversible
		bool optionsLocked; //reversible
		uint startTime;
		uint endTime; // for autopayout
		// See Games contract for comments about off-chain metadata
		string imageURI;
		string title140; // Up to 140 character title
		string descr500; // Up to 500 character description
	}

	uint256 maxUsedID = 0; // 0 is not actually used, but reserved for the undefined/empty reference
	IQuestionsController controller;
	mapping(uint256 => Question) rows;

	event Creation(
		address indexed lister,
		uint indexed newId
	);

	event ControllerChanged(
		IQuestionsController indexed oldValue,
		IQuestionsController indexed newValue
	);

	event ListerChanged(
		uint indexed rowID,
		address indexed oldValue,
		address indexed newValue
	);

	event SponsorshipAdded(
		uint indexed rowID,
		address indexed sponsor,
		uint amountAdded,
		uint totalSponsorshipFromThisSponsor,
		uint totalSponsoredAmount
	);

	event OptionAdded(
		uint indexed rowID,
		uint optionIndex,
		string optionsAdded
	);

	event OptionChanged(
		uint indexed rowID,
		uint8 optionID,
		string oldText,
		string newText
	);

	event OptionRemoved(
		uint indexed rowID,
		uint8 optionID,
		string oldText
	);

	event PlayerTotalInputsChanged(
		address indexed player,
		uint indexed rowID,
		int amountOfChange,
		uint newPlayerTotalInput
	);

	event PositionChanged(
		address indexed player,
		uint indexed rowID,
		uint8 optionIndex,
		int amountOfChange,
		uint newPositionForPlayer,
		uint newPoolForOption
	);

	event Resolved(
		uint indexed rowID,
		bool isUnresolvable,
		uint16[] resolutionFractions
	);

	event OptionsLockedChanged(
		uint indexed rowID,
		bool oldValue,
		bool newValue
	);

	event StartTimeChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	event EndTimeChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	event ImageURIChanged(
		uint indexed rowID,
		string oldValue,
		string newValue
	);

	event Title140Changed(
		uint indexed rowID,
		string oldValue,
		string newValue
	);

	event Descr500Changed(
		uint indexed rowID,
		string oldValue,
		string newValue
	);

	error NotAllowedToListInGame(address attempter); // 'This account is not currently allowed to create a new question in this game.'

	error PropertyChangeAttemptByNonLister(address attempter);

	error InvalidOptionID(uint rowID, uint8 optionID);

	modifier onlyIfAllowedToList(uint gameID) {
		_checkIsAllowedToList(gameID);
		_;
	}

	function _checkIsAllowedToList(uint gameID) internal view virtual {
		if (!controller.isAllowedToList(gameID, msg.sender)) {
			revert PropertyChangeAttemptByNonLister(msg.sender);
		}
	}

	modifier onlyLister(uint rowID) {
		_checkLister(rowID); //Split out like OpenZeppelin's Ownable contract
		_;
	}

	function _checkLister(uint rowID) internal view virtual {
		if (rows[rowID].lister != msg.sender) {
			revert PropertyChangeAttemptByNonLister(msg.sender);
		}
	}

	modifier onlyReferee(uint rowID) {
		_checkReferee(rowID); //Split out like OpenZeppelin's Ownable contract
		_;
	}

	function _checkReferee(uint rowID) internal view virtual {
		if (!controller.isRefereeFor(rows[rowID].game, msg.sender)) {
			revert PropertyChangeAttemptByNonLister(msg.sender);
		}
	}

	modifier onlyIfValidOptionID(uint rowID, uint8 optionID) {
		_checkOptionIDValidity(rowID, optionID); //Split out like OpenZeppelin's Ownable contract
		_;
	}

	function _checkOptionIDValidity(uint rowID, uint8 optionID) internal view virtual {
		if ((optionID < rows[rowID].options.length) || rows[rowID].optionRemoved[optionID]) {
			revert InvalidOptionID(rowID, optionID);
		}
	}

	constructor(
		address payable initialOwner,
		IQuestionsController initialController
	)
		PayableOwnable(initialOwner)
	{
		_changeController(initialController);
	}

	function changeController(
		IQuestionsController newController
	) public onlyOwner {
		_changeController(
			newController
		);
	}

	function _changeController(
		IQuestionsController newController
	) private {
		emit ControllerChanged(
			controller,
			newController
		);
		controller = newController;
	}

	function create(
		uint gameID,
		address lister,
		string calldata title140,
		string[] calldata options
		//endTime at default value of 0 here (goes w/game, which might change)
		//startTime at default value of 0 here
	) public onlyIfAllowedToList(gameID) {
		_create(
			gameID,
			lister,
			title140,
			options,
			0,
			0
		);
	}

	function create(
		uint gameID,
		address lister,
		string calldata title140,
		string[] calldata options,
		uint endTime
		//startTime at default value of 0 here
	) public onlyIfAllowedToList(gameID) {
		_create(
			gameID,
			lister,
			title140,
			options,
			endTime,
			0
		);
	}

	function create(
		uint gameID,
		address lister,
		string calldata title140,
		string[] calldata options,
		uint endTime,
		uint startTime
	) public onlyIfAllowedToList(gameID) {
		_create(
			gameID,
			lister,
			title140,
			options,
			endTime,
			startTime
		);
	}

	function _create(
		uint gameID,
		address lister,
		string calldata title140,
		string[] calldata options,
		uint endTime,
		uint startTime
	) private {
		maxUsedID++;
		emit Creation(
			lister,
			maxUsedID
		);
		rows[maxUsedID].game = gameID;
		_changeLister(
			maxUsedID,
			lister
		);
		_changeTitle140(
			maxUsedID,
			title140
		);
		_addOptions(
			maxUsedID,
			options
		);
		_changeEndTime(
			maxUsedID,
			endTime
		);
		_changeStartTime(
			maxUsedID,
			startTime
		);
	}

	function changeLister(
		uint rowID,
		address newValue
	) public onlyLister(rowID) {
		_changeLister(
			rowID,
			newValue
		);
	}

	function _changeLister(
		uint rowID,
		address newValue
	) private {
		emit ListerChanged(
			rowID,
			rows[rowID].lister,
			newValue
		);
		rows[rowID].lister = newValue;
	}

	function addSponsorship(
		uint rowID,
		uint amountToAdd,
		address sponsor
	) public {
		rows[rowID].sponsors[sponsor] += amountToAdd;
		rows[rowID].totalSponsoredAmount += amountToAdd;
		emit SponsorshipAdded(
			rowID,
			sponsor,
			amountToAdd,
			rows[rowID].sponsors[sponsor],
			rows[rowID].totalSponsoredAmount
		);
		require(
			controller.gameToken(rows[rowID].game).transferFrom(msg.sender, address(controller), amountToAdd),
			'Sponsorship addition failed.'
		);
	}

	function addOptions(
		uint rowID,
		string[] calldata options
	) public onlyLister(rowID) {
		//TODO: Add require conditions here
		_addOptions(
			rowID,
			options
		);
	}

	function _addOptions(
		uint rowID,
		string[] calldata options
	) private {
		//DOES allow duplicates but not empty strings
		for(uint i = 0; i<options.length; i++) {
			if(rows[rowID].options.length >= 26) {
				revert('There is a maximum of 26 options per question.');
			}
			if(bytes(options[i]).length > 0) {
				emit OptionAdded(
					rowID,
					rows[rowID].options.length,
					options[i]
				);
				rows[rowID].options.push(options[i]);
				rows[rowID].optionPoolsTokens.push(0);
				rows[rowID].optionPoolsTickets.push(0);
				rows[rowID].playerPositions.push({});
			}
		}
	}

	function changeOption(
		uint rowID,
		uint8 optionID,
		string calldata newText
	) public onlyLister(rowID) {
		_changeOption(
			rowID,
			optionID,
			newText
		);
	}

	function _changeOption(
		uint rowID,
		uint8 optionID,
		string calldata newText
	) private onlyIfValidOptionID(rowID, optionID) {
		//DOES allow duplicates but not empty strings
		//Empty strings are an error here but just silently ignored when adding an array of options.
		require(bytes(newText).length > 0, 'Empty-string options are not allowed.');
		emit OptionChanged(
			rowID,
			optionID,
			rows[rowID].options[optionID],
			newText
		);
		rows[rowID].options[optionID] = newText;
	}

	function removeOption(
		uint rowID,
		uint8 optionID
	) public onlyLister(rowID) {
		_removeOption(
			rowID,
			optionID
		);
	}

	function _removeOption(
		uint rowID,
		uint8 optionID
	) private onlyIfValidOptionID(rowID, optionID) {
		emit OptionRemoved(
			rowID,
			optionID,
			rows[rowID].options[optionID]
		);
		require(
			rows[rowID].optionPoolsTickets[optionID] <= 0,
			'Cannot delete an option when players have an open position in it.'
		);
		rows[rowID].optionRemoved[optionID] = true;
	}

	function changeStartTime(
		uint rowID,
		uint newValue
	) public onlyLister(rowID) {
		_changeStartTime(
			rowID,
			newValue
		);
	}

	function _changeStartTime(
		uint rowID,
		uint newValue
	) private {
		emit StartTimeChanged(
			rowID,
			rows[rowID].startTime,
			newValue
		);
		rows[rowID].startTime = newValue;
	}

	function changeEndTime(
		uint rowID,
		uint newValue
	) public onlyLister(rowID) {
		_changeEndTime(
			rowID,
			newValue
		);
	}

	function _changeEndTime(
		uint rowID,
		uint newValue
	) private {
		emit EndTimeChanged(
			rowID,
			rows[rowID].endTime,
			newValue
		);
		rows[rowID].endTime = newValue;
	}

	function markUnresolvableByLister(
		uint rowID
	) public onlyLister(rowID) {
		_markUnresolvable(
			rowID
		);
	}

	function markUnresolvableByReferee(
		uint rowID
	) public onlyReferee(rowID) {
		_markUnresolvable(
			rowID
		);
	}

	// TODO: Add fn allowing referees in aggregate to mark unresolvable

	//Solidity can't figure out the type when passing [] inline
	//and there doesn't seem to be another valid casting strategy.
	//See https://github.com/ethereum/solidity/issues/12401
	function getEmptyUint16Array() private pure returns(uint16[] memory) {}

	function _markUnresolvable(
		uint rowID
	) private {
		emit Resolved(
			rowID,
			true,
			getEmptyUint16Array()
		);
		rows[rowID].unresolvable = true;
		//TODO: There's more to do here! Joint private fn shared with _resolve().
	}

	function freeze(
		uint rowID
	) public onlyReferee(rowID) {
		_freeze(
			rowID
		);
	}

	function _freeze(
		uint rowID
	) private {
		uint16[] memory resolutionFractions = new uint16[](rows[rowID].options.length);
		for(uint i=0; i<rows[rowID].options.length; i++) {
			resolutionFractions[i] = uint16(10000*rows[rowID].optionPoolsTokens[i] / rows[rowID].optionPoolsTokensSum);
		}
		_resolve(
			rowID,
			resolutionFractions
		);
	}

	function resolveToOption(
		uint rowID,
		uint8 optionID
	) public onlyReferee(rowID) onlyIfValidOptionID(rowID, optionID) {
		_resolveToOption(
			rowID,
			optionID
		);
	}

	function _resolveToOption(
		uint rowID,
		uint8 optionID
	) private {
		uint16[] memory resolutionFractions = new uint16[](rows[rowID].options.length);
		resolutionFractions[optionID] = 10000;
		_resolve(
			rowID,
			resolutionFractions
		);
	}

	function resolve(
		uint rowID,
		uint16[] memory resolutionFractions
	) public onlyReferee(rowID) {
		_resolve(
			rowID,
			resolutionFractions
		);
	}

	function _resolve(
		uint rowID,
		uint16[] memory resolutionFractions
	) private {
		require(resolutionFractions.length == rows[rowID].options.length, 'Invalid length of resolutionFractions parameter.');
		uint16 sum = 0;
		for(uint8 i=0; i<resolutionFractions.length; i++) {
			require(!(rows[rowID].optionRemoved[i] && resolutionFractions[i] > 0), 'ResolutionFractions specifies nonzero value for removed option.');
			sum += resolutionFractions[i];
		}
		require(sum == 10000, 'Invalid sum of resolutionFractions.');
		emit Resolved(
			rowID,
			false,
			resolutionFractions
		);
		rows[rowID].isResolved = true;
		rows[rowID].resolutionFractions = resolutionFractions;
	}

	function changeOptionsLocked(
		uint rowID,
		bool newValue
	) public onlyReferee(rowID) {
		_changeOptionsLocked(
			rowID,
			newValue
		);
	}

	function _changeOptionsLocked(
		uint rowID,
		bool newValue
	) private {
		emit OptionsLockedChanged(
			rowID,
			rows[rowID].optionsLocked,
			newValue
		);
		rows[rowID].optionsLocked = newValue;
	}

	function changeImageURI(
		uint rowID,
		string calldata newValue
	) public onlyLister(rowID) {
		_changeImageURI(
			rowID,
			newValue
		);
	}

	function _changeImageURI(
		uint rowID,
		string calldata newValue
	) private {
		emit ImageURIChanged(
			rowID,
			rows[rowID].imageURI,
			newValue
		);
		rows[rowID].imageURI = newValue;
	}

	function changeTitle140(
		uint rowID,
		string calldata newValue
	) public onlyLister(rowID) {
		_changeTitle140(
			rowID,
			newValue
		);
	}

	function _changeTitle140(
		uint rowID,
		string calldata newValue
	) private {
		emit Title140Changed(
			rowID,
			rows[rowID].title140,
			newValue
		);
		rows[rowID].title140 = newValue;
	}

	function changeDescr500(
		uint rowID,
		string calldata newValue
	) public onlyLister(rowID) {
		_changeDescr500(
			rowID,
			newValue
		);
	}

	function _changeDescr500(
		uint rowID,
		string calldata newValue
	) private {
		emit Descr500Changed(
			rowID,
			rows[rowID].descr500,
			newValue
		);
		rows[rowID].descr500 = newValue;
	}

	function hasResolved(
		uint rowID
	) public view returns (bool) {
		return rows[rowID].isResolved || rows[rowID].unresolvable;
	}

	function moveTokensIntoOrOutOfQuestionFreeBalance(
		uint rowID,
		int amount
	) public {
		if(amount == 0) {
			//do nothing.
			return;
		} else if(amount > 0) { //Depositing into question free balance
			require(
				!hasResolved(rowID),
				'Cannot deposit outside funds into a resolved question; you can only withdraw.'
			);
			require(
				rows[rowID].playerTotalInputs[msg.sender] >= 0,
				'Contract bug: player was allowed to withdraw more than they put in on question before resolution!'
			);
			require(
				//Cast at start of next line is valid due to the immediately preceding require statement
				uint(rows[rowID].playerTotalInputs[msg.sender]) <= controller.maxQuestionBid(rows[rowID].game),
				'Contract bug: player was allowed to exceed maximum bid on question!'
			);
			uint roomLeftToMaxQuestionBid =
				controller.maxQuestionBid(rows[rowID].game) -
				uint(rows[rowID].playerTotalInputs[msg.sender]) //valid cast due to the contract bug check in the require statement above
			;
			//Cap total amount deposited to MaxQuestionBid:
			uint cappedAmount = Math.min(
				uint(amount), //valid cast due to being in if(amount>0) conditional block.
				roomLeftToMaxQuestionBid
			);
			//cappedAmount is guaranteed to be within the positive int range because it is the lesser of:
			//amount, a positive (within the if amount>0 block) value within the int range (it's an int parameter)
			//maxQuestionBid for the game, which is guaranteed within the int range by the controller interface
			amount = int(cappedAmount);
			require(controller.gameToken(rows[rowID].game).transferFrom(msg.sender, address(this), uint256(amount)), 'Token transfer failed.');
		} else { //Withdrawal from question free balance
			if(!rows[rowID].isResolved) {
				//unresolvable, or unknown if it's resolvable:
				//Cap withdrawal to amount that was put in.
				require(rows[rowID].playerTotalInputs[msg.sender] >= 0, 'Contract bug: player was allowed to withdraw more than they put in on question later found unresolvable!');
				uint cappedPositiveAmount = Math.min(
					uint(-1*amount), //valid cast due to being in an (amount < 0) conditional block.
					uint(rows[rowID].playerTotalInputs[msg.sender]) //valid cast due to require statement above
				);
				//cappedPositiveAmount is guaranteed to be within the positive int range, as the result of a min function between:
				//The param "amount" which is guaranteed to be in the int range (it's incoming as an int type)
				//and is necessarily negative in this conditional block, with the sign flipped by the -1*.
				//The other operator to the min function is a uint so it's guaranteed positive, and if it's beyond the int range
				//then it definitely won't be the minimum of the two arguments so it won't be the result of the min function.
				amount = -1*int(cappedPositiveAmount);
			}
			if(!rows[rowID].unresolvable) {
				//Cap withdrawal to free balance on question.
				//This cap does not apply if it's deemed unresolvable;
				//in that case the cap is the net amount put into the question.
				uint cappedPositiveAmount = Math.min(
					uint(-1*amount), //valid cast due to being in an (amount < 0) conditional block.
					rows[rowID].playerFreeBalanceOnQuestion[msg.sender]
				);
				//Same comments as above
				amount = -1*int(cappedPositiveAmount);
			}
			//An extra safety check to limit withdrawals.
			//This shouldn't be needed, but it's a guardrail until a more throrough
			//tokenomics review can be conducted.
			uint cappedPositiveAmount = Math.min(
				uint(-1*amount),
				rows[rowID].freeBalanceSum
			);
			//Same comments as above
			amount = -1*int(cappedPositiveAmount);
			require(controller.gameToken(rows[rowID].game).transfer(msg.sender, uint256(-1*amount)), 'Token transfer failed.');
		}
		//TODO: Get better about checks-effects-interactions here
		rows[rowID].playerTotalInputs[msg.sender] += amount;
		_adjustPlayerFreeBalance(rowID, msg.sender, amount);
	}

	function _adjustPlayerFreeBalance(
		uint rowID,
		address player,
		int amountToIncreaseFreeBalanceBy
	) private {
		if(amountToIncreaseFreeBalanceBy >= 0) {
			//This fn exists to make sure these two state variables are always changed together:
			rows[rowID].playerFreeBalanceOnQuestion[msg.sender] =
				rows[rowID].playerFreeBalanceOnQuestion[msg.sender] +
				amountToIncreaseFreeBalanceBy
			;
			rows[rowID].freeBalanceSum =
				rows[rowID].freeBalanceSum +
				amountToIncreaseFreeBalanceBy
			;
		} else {
			//This fn exists to make sure these two state variables are always changed together:
			rows[rowID].playerFreeBalanceOnQuestion[msg.sender] =
				rows[rowID].playerFreeBalanceOnQuestion[msg.sender] +
				amountToIncreaseFreeBalanceBy
			;
			rows[rowID].freeBalanceSum =
				rows[rowID].freeBalanceSum +
				amountToIncreaseFreeBalanceBy
			;
		}
	}
	}

}
