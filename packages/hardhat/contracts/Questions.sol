//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "./IQuestionsController.sol";
import "./PayableOwnable.sol";

contract Questions is PayableOwnable {

	struct Option {
		string text; //up to 140 chars
		uint16 resolutionFraction;
		mapping(address => uint) playerPositions;
		uint optionPool;
	}

	struct Question {
		address lister;
		uint game; //immutable
		mapping(address => uint) sponsors; // uint is amount sponsored, in base tokens.
		uint totalSponsoredAmount;
		//TODO: Make Option its own struct?
		//Option[] options; //max length 26
		string[] options; //up to 26 strings each up to 140 chars
		uint16[] resolutionFractions; //should total 10000 //or should that be -1000*sponsorFractionOfOptionPool?
		mapping(address => uint)[] playerPositions;
		uint[] optionPools;
		uint optionPoolsSum; // sum of the above array, but helps accelerate math
		//playerTotalInputs: uint is net amount total amount put in, in base tokens.
		//Adjusts only on moving tokens in and out of question, not among options.
		//Can't remove more until resolution, in case it's unresolvable and moves incl. winnings are reversed.
		mapping(address => int) playerTotalInputs; // Might be > sum(player's positions).
		bool isResolved; //irreversible
		bool unresolvable; //irreversible
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
			revert PropertyChangeAttemptByNonLister(_msgSender());
		}
	}

	modifier onlyLister(uint rowID) {
		_checkLister(rowID); //Split out like OpenZeppelin's Ownable contract
		_;
	}

	function _checkLister(uint rowID) internal view virtual {
		if (rows[rowID].lister != msg.sender) {
			revert PropertyChangeAttemptByNonLister(_msgSender());
		}
	}

	modifier onlyIfValidOptionID(uint rowID, uint8 optionID) {
		_checkOptionIDValidity(rowID, optionID); //Split out like OpenZeppelin's Ownable contract
		_;
	}

	function _checkOptionIDValidity(uint rowID, uint8 optionID) internal view virtual {
		if (optionID < rows[rowID].options.length) {
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
		require(rows[rowID].optionPools[optionID] <= 0, 'Cannot delete an option when players have an open position in it.');
		for(uint i = optionID; i<rows[rowID].options.length-2; i++) {
			rows[rowID].options[i] = rows[rowID].options[i+1];
			rows[rowID].resolutionFractions[i] = rows[rowID].resolutionFractions[i+1];
			//TODO: This isn't assignable; consider struct strategy.
			//rows[rowID].playerPositions[i] = rows[rowID].playerPositions[i+1];
			rows[rowID].optionPools[i] = rows[rowID].optionPools[i+1];
		}
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

	// TODO: Add fn allowing referees in aggregate to resolve

	function _resolve(
		uint rowID,
		uint16[] calldata resolutionFractions
	) private {
		emit Resolved(
			rowID,
			false,
			resolutionFractions
		);
		rows[rowID].isResolved = true;
		//TODO: Process resolutionFractions, differently if using Options struct
		rows[rowID].resolutionFractions = resolutionFractions;
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

}
