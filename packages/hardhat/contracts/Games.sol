//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.
import "hardhat/console.sol";

import "./IGamesController.sol";
import "./PayableOwnable.sol";

contract Games is PayableOwnable {
	uint256 maxUsedGameID = 0; // 0 is not actually used, but reserved for the undefined/empty game
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
	mapping(uint256 => Game) games;

	event GameAdded(
		address indexed lister,
		uint indexed newGameId
	);

	event ControllerChanged(
		IGamesController indexed oldController,
		IGamesController indexed newController
	);

	event ListerChanged(
		uint indexed gameID,
		address indexed oldLister,
		address indexed newLister
	);

	event SponsorshipAdded(
		uint indexed gameID,
		address indexed sponsor,
		uint amountAdded,
		uint totalSponsorshipFromThisSponsor,
		uint totalSponsoredAmount
	);

	event CheckInStartChanged(
		uint indexed gameID,
		uint oldValue,
		uint newValue
	);

	event EndTimeChanged(
		uint indexed gameID,
		uint oldValue,
		uint newValue
	);

	event LocationIDChanged(
		uint indexed gameID,
		uint oldValue,
		uint newValue
	);

	event RefereeAdded(
		uint indexed gameID,
		address indexed referee
	);

	event RefereeRemoved(
		uint indexed gameID,
		address indexed referee
	);

	event GameTokenChanged(
		uint indexed gameID,
		IERC20 oldValue,
		IERC20 newValue
	);

	event CheckInRequiredChanged(
		uint indexed gameID,
		bool oldValue,
		bool newValue
	);

	event OpenToAnyAskerChanged(
		uint indexed gameID,
		bool oldValue,
		bool newValue
	);

	event SponsorFractionOfOptionPoolChanged(
		uint indexed gameID,
		uint24 oldValue,
		uint24 newValue
	);

	event MaxQuestionBidChanged(
		uint indexed gameID,
		uint oldValue,
		uint newValue
	);

	event AskerApprovalChanged(
		uint indexed gameID,
		address indexed asker,
		int8 oldValue,
		int8 newValue
	);

	event ImageURIChanged(
		uint indexed gameID,
		string oldValue,
		string newValue
	);

	event Title140Changed(
		uint indexed gameID,
		string oldValue,
		string newValue
	);

	event Descr500Changed(
		uint indexed gameID,
		string oldValue,
		string newValue
	);

	event ListStartChanged(
		uint indexed gameID,
		uint oldValue,
		uint newValue
	);

	event ListEndChanged(
		uint indexed gameID,
		uint oldValue,
		uint newValue
	);

	error PropertyChangeAttemptByNonLister(address attempter);

	modifier onlyLister(uint gameID) {
		_checkLister(gameID); //Split out like OpenZeppelin's Ownable contract
		_;
	}

	function _checkLister(uint gameID) internal view virtual {
		if (games[gameID].lister != msg.sender) {
			revert PropertyChangeAttemptByNonLister(_msgSender());
		}
	}

	constructor(
		address payable initialOwner,
		IGamesController initialController
	)
		PayableOwnable(initialOwner)
	{
		emit ControllerChanged(IGamesController(address(0)), initialController);
		controller = initialController;
	}

	function changeController(
		IGamesController newController
	) public onlyOwner {
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
		maxUsedGameID++;
		emit GameAdded(
			lister,
			maxUsedGameID
		);
		_changeLister(
			maxUsedGameID,
			lister
		);
		_changeGameToken(
			maxUsedGameID,
			controller.baseToken()
		);
		_changeSponsorFractionOfOptionPool(
			maxUsedGameID,
			controller.defaultSponsorFractionOfOptionPool()
		);
		_changeMaxQuestionBid(
			maxUsedGameID,
			controller.defaultMaxQuestionBid()
		);
	}

	function changeLister(
		uint gameID,
		address newLister
	) public onlyLister(gameID) {
		_changeLister(
			gameID,
			newLister
		);
	}

	function _changeLister(
		uint gameID,
		address newLister
	) private {
		emit ListerChanged(
			gameID,
			games[gameID].lister,
			newLister
		);
		games[gameID].lister = newLister;
	}

	function addSponsorship(
		uint gameID,
		uint amountToAdd,
		address sponsor
	) public {
		games[gameID].sponsors[sponsor] += amountToAdd;
		games[gameID].totalSponsoredAmount += amountToAdd;
		emit SponsorshipAdded(
			gameID,
			sponsor,
			amountToAdd,
			games[gameID].sponsors[sponsor],
			games[gameID].totalSponsoredAmount
		);
		require(
			games[gameID].gameToken.transferFrom(msg.sender, address(controller), amountToAdd),
			'Sponsorship addition failed.'
		);
	}

	function changeCheckInStart(
		uint gameID,
		uint newValue
	) public onlyLister(gameID) {
		_changeCheckInStart(
			gameID,
			newValue
		);
	}

	function _changeCheckInStart(
		uint gameID,
		uint newValue
	) private {
		emit CheckInStartChanged(
			gameID,
			games[gameID].checkInStart,
			newValue
		);
		games[gameID].checkInStart = newValue;
	}

	function changeEndTime(
		uint gameID,
		uint newValue
	) public onlyLister(gameID) {
		_changeEndTime(
			gameID,
			newValue
		);
	}

	function _changeEndTime(
		uint gameID,
		uint newValue
	) private {
		emit EndTimeChanged(
			gameID,
			games[gameID].endTime,
			newValue
		);
		games[gameID].endTime = newValue;
	}

	function changeLocationID(
		uint gameID,
		uint newValue
	) public onlyLister(gameID) {
		_changeLocationID(
			gameID,
			newValue
		);
	}

	function _changeLocationID(
		uint gameID,
		uint newValue
	) private {
		emit LocationIDChanged(
			gameID,
			games[gameID].locationID,
			newValue
		);
		games[gameID].locationID = newValue;
	}

	function addReferee(
		uint gameID,
		address referee
	) public onlyLister(gameID) {
		_addReferee(
			gameID,
			referee
		);
	}

	function _addReferee(
		uint gameID,
		address referee
	) private {
		bool found = false;
		for(uint i = 0; i<games[gameID].referees.length; i++) {
			if(games[gameID].referees[i] == referee) {
				found = true;
			}
		}
		if(!found) {
			games[gameID].referees.push(referee);
			emit RefereeAdded(
				gameID,
				referee
			);
		}
	}

	function removeReferee(
		uint gameID,
		address referee
	) public onlyLister(gameID) {
		_removeReferee(
			gameID,
			referee
		);
	}

	function _removeReferee(
		uint gameID,
		address referee
	) private {
		bool found = false;
		uint foundAt = 0;
		for(uint i = 0; i<games[gameID].referees.length; i++) {
			if(games[gameID].referees[i] == referee) {
				found = true;
				foundAt = i;
			}
		}
		if(found) {
			if(foundAt < games[gameID].referees.length-1) {
				//if not the last element in the array, move the last element into the place being vacated
				games[gameID].referees[foundAt] = games[gameID].referees[games[gameID].referees.length-1];
			}
			//Then drop the last element
			games[gameID].referees.pop();
			emit RefereeRemoved(
				gameID,
				referee
			);
		}
	}

	/* TODO: Work through all the implications
	* of allowing a change to the game token
	* before enabling this function.
	function changeGameToken(
		uint gameID,
		IERC20 newToken
	) public onlyLister(gameID) {
		_changeGameToken(
			gameID,
			newToken
		);
	}
	*/

	function _changeGameToken(
		uint gameID,
		IERC20 newToken
	) private {
		emit GameTokenChanged(
			gameID,
			games[gameID].gameToken,
			newToken
		);
		games[gameID].gameToken = newToken;
	}

	function changeCheckInRequired(
		uint gameID,
		bool newValue
	) public onlyLister(gameID) {
		_changeCheckInRequired(
			gameID,
			newValue
		);
	}

	function _changeCheckInRequired(
		uint gameID,
		bool newValue
	) private {
		emit CheckInRequiredChanged(
			gameID,
			games[gameID].checkInRequired,
			newValue
		);
		games[gameID].checkInRequired = newValue;
	}

	function changeOpenToAnyAsker(
		uint gameID,
		bool newValue
	) public onlyLister(gameID) {
		_changeOpenToAnyAsker(
			gameID,
			newValue
		);
	}

	function _changeOpenToAnyAsker(
		uint gameID,
		bool newValue
	) private {
		emit OpenToAnyAskerChanged(
			gameID,
			games[gameID].openToAnyAsker,
			newValue
		);
		games[gameID].openToAnyAsker = newValue;
	}

	function changeSponsorFractionOfOptionPool(
		uint gameID,
		uint24 newValue
	) public onlyLister(gameID) {
		_changeSponsorFractionOfOptionPool(
			gameID,
			newValue
		);
	}

	function _changeSponsorFractionOfOptionPool(
		uint gameID,
		uint24 newValue
	) private {
		emit SponsorFractionOfOptionPoolChanged(
			gameID,
			games[gameID].sponsorFractionOfOptionPool,
			newValue
		);
		games[gameID].sponsorFractionOfOptionPool = newValue;
	}

	function changeMaxQuestionBid(
		uint gameID,
		uint newValue
	) public onlyLister(gameID) {
		_changeMaxQuestionBid(
			gameID,
			newValue
		);
	}

	function _changeMaxQuestionBid(
		uint gameID,
		uint newValue
	) private {
		emit MaxQuestionBidChanged(
			gameID,
			games[gameID].maxQuestionBid,
			newValue
		);
		games[gameID].maxQuestionBid = newValue;
	}

	function changeAskerApproval(
		uint gameID,
		address asker,
		int8 newValue
	) public onlyLister(gameID) {
		_changeAskerApproval(
			gameID,
			asker,
			newValue
		);
	}

	function _changeAskerApproval(
		uint gameID,
		address asker,
		int8 newValue
	) private {
		emit AskerApprovalChanged(
			gameID,
			asker,
			games[gameID].askerApprovals[asker],
			newValue
		);
		games[gameID].askerApprovals[asker] = newValue;
	}

	function changeImageURI(
		uint gameID,
		string calldata newValue
	) public onlyLister(gameID) {
		_changeImageURI(
			gameID,
			newValue
		);
	}

	function _changeImageURI(
		uint gameID,
		string calldata newValue
	) private {
		emit ImageURIChanged(
			gameID,
			games[gameID].imageURI,
			newValue
		);
		games[gameID].imageURI = newValue;
	}

	function changeTitle140(
		uint gameID,
		string calldata newValue
	) public onlyLister(gameID) {
		_changeTitle140(
			gameID,
			newValue
		);
	}

	function _changeTitle140(
		uint gameID,
		string calldata newValue
	) private {
		emit Title140Changed(
			gameID,
			games[gameID].title140,
			newValue
		);
		games[gameID].title140 = newValue;
	}

	function changeDescr500(
		uint gameID,
		string calldata newValue
	) public onlyLister(gameID) {
		_changeDescr500(
			gameID,
			newValue
		);
	}

	function _changeDescr500(
		uint gameID,
		string calldata newValue
	) private {
		emit Descr500Changed(
			gameID,
			games[gameID].descr500,
			newValue
		);
		games[gameID].descr500 = newValue;
	}

	function changeListStart(
		uint gameID,
		uint newValue
	) public onlyLister(gameID) {
		_changeListStart(
			gameID,
			newValue
		);
	}

	function _changeListStart(
		uint gameID,
		uint newValue
	) private {
		emit ListStartChanged(
			gameID,
			games[gameID].listStart,
			newValue
		);
		games[gameID].listStart = newValue;
	}

	function changeListEnd(
		uint gameID,
		uint newValue
	) public onlyLister(gameID) {
		_changeListEnd(
			gameID,
			newValue
		);
	}

	function _changeListEnd(
		uint gameID,
		uint newValue
	) private {
		emit ListEndChanged(
			gameID,
			games[gameID].listEnd,
			newValue
		);
		games[gameID].listEnd = newValue;
	}

}
