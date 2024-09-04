//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "./IGamesController.sol";
import "./PayableOwnable.sol";

contract Games is PayableOwnable {
	uint256 maxUsedID = 0; // 0 is not actually used, but reserved for the undefined/empty reference
	IGamesController controller;
	struct Game {
		address lister;
		mapping(address => uint) sponsors; // uint is amount sponsored, in base tokens.
		uint totalSponsoredAmount;
		uint checkInStart;
		uint endTime; // for autopayout
		uint locationID; // supports map search in the future
		address[] referees; //accounts who can resolve or cancel a question, possibly also account => Boolean mapping and refCount uint.
		IERC20 gameToken; // The token address exchangeable 1:1 for tokens in the game; auto payout in that token after the game end time
		bool checkInRequired;
		bool openToAnyAsker;
		uint24 sponsorFractionOfOptionPool; // A percentage (e.g. 2 for 2%) * 10^5; can’t be changed after CheckInStart
		uint maxQuestionBid; // in token count per question per player.
		mapping (address => int8) askerApprovals; //+1 for whitelist (only attened to if required), -1 for blacklist (though beware Sybils)
		// Some of the information could go into an off-chain metadata file,
		// with just one URL here.
		// Putting the image URI in the metadata file can be done,
		// but would slow down pageload especially on the frequently accessed event list page
		// due to an extra server lookup and roundtrip to get the image URL and then the image content.
		// If there is a large volume of metadata, off-chain is better,
		// but (a) that adds unnecessary complexity to the architecture
		// (for images, there's more argument favoring necessity)
		// and (b) on-chain events with events fired on every change help support server-side render caching
		// with reliable cache invalidation when data changes.
		string imageURI;
		string title140; // Up to 140 character title
		string descr500; // Up to 500 character description
		uint listStart; // for example, the published start time of a sports game.
		uint listEnd;
	}
	mapping(uint256 => Game) rows;

	event GameAdded(
		address indexed lister,
		uint indexed newId
	);

	event ControllerChanged(
		IGamesController indexed oldValue,
		IGamesController indexed newValue
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

	event CheckInStartChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	event EndTimeChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	event LocationIDChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	event RefereeAdded(
		uint indexed rowID,
		address indexed referee
	);

	event RefereeRemoved(
		uint indexed rowID,
		address indexed referee
	);

	event GameTokenChanged(
		uint indexed rowID,
		IERC20 oldValue,
		IERC20 newValue
	);

	event CheckInRequiredChanged(
		uint indexed rowID,
		bool oldValue,
		bool newValue
	);

	event OpenToAnyAskerChanged(
		uint indexed rowID,
		bool oldValue,
		bool newValue
	);

	event SponsorFractionOfOptionPoolChanged(
		uint indexed rowID,
		uint24 oldValue,
		uint24 newValue
	);

	event MaxQuestionBidChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	event AskerApprovalChanged(
		uint indexed rowID,
		address indexed asker,
		int8 oldValue,
		int8 newValue
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

	event ListStartChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	event ListEndChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	error PropertyChangeAttemptByNonLister(address attempter);

	modifier onlyLister(uint rowID) {
		_checkLister(rowID); //Split out like OpenZeppelin's Ownable contract
		_;
	}

	function _checkLister(uint rowID) internal view virtual {
		if (rows[rowID].lister != msg.sender) {
			revert PropertyChangeAttemptByNonLister(_msgSender());
		}
	}

	constructor(
		address payable initialOwner,
		IGamesController initialController
	)
		PayableOwnable(initialOwner)
	{
		_changeController(initialController);
	}

	function changeController(
		IGamesController newController
	) public onlyOwner {
		_changeController(
			newController
		);
	}

	function _changeController(
		IGamesController newController
	) private {
		emit ControllerChanged(
			controller,
			newController
		);
		controller = newController;
	}

	function addGame(
		address lister
	) public {
		require(
			controller.isAllowedToList(lister),
			'This account is not currently allowed to create a new game.'
		);
		maxUsedID++;
		emit GameAdded(
			lister,
			maxUsedID
		);
		_changeLister(
			maxUsedID,
			lister
		);
		_changeGameToken(
			maxUsedID,
			controller.baseToken()
		);
		_changeSponsorFractionOfOptionPool(
			maxUsedID,
			controller.defaultSponsorFractionOfOptionPool()
		);
		_changeMaxQuestionBid(
			maxUsedID,
			controller.defaultMaxQuestionBid()
		);
	}

	function changeLister(
		uint rowID,
		address newLister
	) public onlyLister(rowID) {
		_changeLister(
			rowID,
			newLister
		);
	}

	function _changeLister(
		uint rowID,
		address newLister
	) private {
		emit ListerChanged(
			rowID,
			rows[rowID].lister,
			newLister
		);
		rows[rowID].lister = newLister;
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
			rows[rowID].gameToken.transferFrom(msg.sender, address(controller), amountToAdd),
			'Sponsorship addition failed.'
		);
	}

	function changeCheckInStart(
		uint rowID,
		uint newValue
	) public onlyLister(rowID) {
		_changeCheckInStart(
			rowID,
			newValue
		);
	}

	function _changeCheckInStart(
		uint rowID,
		uint newValue
	) private {
		emit CheckInStartChanged(
			rowID,
			rows[rowID].checkInStart,
			newValue
		);
		rows[rowID].checkInStart = newValue;
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

	function changeLocationID(
		uint rowID,
		uint newValue
	) public onlyLister(rowID) {
		_changeLocationID(
			rowID,
			newValue
		);
	}

	function _changeLocationID(
		uint rowID,
		uint newValue
	) private {
		emit LocationIDChanged(
			rowID,
			rows[rowID].locationID,
			newValue
		);
		rows[rowID].locationID = newValue;
	}

	function addReferee(
		uint rowID,
		address referee
	) public onlyLister(rowID) {
		_addReferee(
			rowID,
			referee
		);
	}

	function _addReferee(
		uint rowID,
		address referee
	) private {
		bool found = false;
		for(uint i = 0; i<rows[rowID].referees.length; i++) {
			if(rows[rowID].referees[i] == referee) {
				found = true;
			}
		}
		if(!found) {
			rows[rowID].referees.push(referee);
			emit RefereeAdded(
				rowID,
				referee
			);
		}
	}

	function removeReferee(
		uint rowID,
		address referee
	) public onlyLister(rowID) {
		_removeReferee(
			rowID,
			referee
		);
	}

	function _removeReferee(
		uint rowID,
		address referee
	) private {
		bool found = false;
		uint foundAt = 0;
		for(uint i = 0; i<rows[rowID].referees.length; i++) {
			if(rows[rowID].referees[i] == referee) {
				found = true;
				foundAt = i;
			}
		}
		if(found) {
			if(foundAt < rows[rowID].referees.length-1) {
				//if not the last element in the array, move the last element into the place being vacated
				rows[rowID].referees[foundAt] = rows[rowID].referees[rows[rowID].referees.length-1];
			}
			//Then drop the last element
			rows[rowID].referees.pop();
			emit RefereeRemoved(
				rowID,
				referee
			);
		}
	}

	/* TODO: Work through all the implications
	* of allowing a change to the game token
	* before enabling this function.
	function changeGameToken(
		uint rowID,
		IERC20 newToken
	) public onlyLister(rowID) {
		_changeGameToken(
			rowID,
			newToken
		);
	}
	*/

	function _changeGameToken(
		uint rowID,
		IERC20 newToken
	) private {
		emit GameTokenChanged(
			rowID,
			rows[rowID].gameToken,
			newToken
		);
		rows[rowID].gameToken = newToken;
	}

	function changeCheckInRequired(
		uint rowID,
		bool newValue
	) public onlyLister(rowID) {
		_changeCheckInRequired(
			rowID,
			newValue
		);
	}

	function _changeCheckInRequired(
		uint rowID,
		bool newValue
	) private {
		emit CheckInRequiredChanged(
			rowID,
			rows[rowID].checkInRequired,
			newValue
		);
		rows[rowID].checkInRequired = newValue;
	}

	function changeOpenToAnyAsker(
		uint rowID,
		bool newValue
	) public onlyLister(rowID) {
		_changeOpenToAnyAsker(
			rowID,
			newValue
		);
	}

	function _changeOpenToAnyAsker(
		uint rowID,
		bool newValue
	) private {
		emit OpenToAnyAskerChanged(
			rowID,
			rows[rowID].openToAnyAsker,
			newValue
		);
		rows[rowID].openToAnyAsker = newValue;
	}

	function changeSponsorFractionOfOptionPool(
		uint rowID,
		uint24 newValue
	) public onlyLister(rowID) {
		_changeSponsorFractionOfOptionPool(
			rowID,
			newValue
		);
	}

	function _changeSponsorFractionOfOptionPool(
		uint rowID,
		uint24 newValue
	) private {
		emit SponsorFractionOfOptionPoolChanged(
			rowID,
			rows[rowID].sponsorFractionOfOptionPool,
			newValue
		);
		rows[rowID].sponsorFractionOfOptionPool = newValue;
	}

	function changeMaxQuestionBid(
		uint rowID,
		uint newValue
	) public onlyLister(rowID) {
		_changeMaxQuestionBid(
			rowID,
			newValue
		);
	}

	function _changeMaxQuestionBid(
		uint rowID,
		uint newValue
	) private {
		emit MaxQuestionBidChanged(
			rowID,
			rows[rowID].maxQuestionBid,
			newValue
		);
		rows[rowID].maxQuestionBid = newValue;
	}

	function changeAskerApproval(
		uint rowID,
		address asker,
		int8 newValue
	) public onlyLister(rowID) {
		_changeAskerApproval(
			rowID,
			asker,
			newValue
		);
	}

	function _changeAskerApproval(
		uint rowID,
		address asker,
		int8 newValue
	) private {
		emit AskerApprovalChanged(
			rowID,
			asker,
			rows[rowID].askerApprovals[asker],
			newValue
		);
		rows[rowID].askerApprovals[asker] = newValue;
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

	function changeListStart(
		uint rowID,
		uint newValue
	) public onlyLister(rowID) {
		_changeListStart(
			rowID,
			newValue
		);
	}

	function _changeListStart(
		uint rowID,
		uint newValue
	) private {
		emit ListStartChanged(
			rowID,
			rows[rowID].listStart,
			newValue
		);
		rows[rowID].listStart = newValue;
	}

	function changeListEnd(
		uint rowID,
		uint newValue
	) public onlyLister(rowID) {
		_changeListEnd(
			rowID,
			newValue
		);
	}

	function _changeListEnd(
		uint rowID,
		uint newValue
	) private {
		emit ListEndChanged(
			rowID,
			rows[rowID].listEnd,
			newValue
		);
		rows[rowID].listEnd = newValue;
	}

}
