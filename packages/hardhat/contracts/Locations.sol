//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "./PayableOwnable.sol";

contract Locations is PayableOwnable {
	uint256 maxUsedID = 0; // 0 is not actually used, but reserved for the undefined/empty reference
	struct Location {
		// TODO: Consider if some of these need to be immutable?
		// Work through all the implications of mutability.
		address lister;
		address signer;
		int48 picolat;
		int48 picolon;
		int32 cmAltitude;
		uint32 cmRadius; //uncertainty/size of location
		uint parent;
		uint lastUpdated; // Not independently mutable, but can be useful in sort tiebreak
		string imageURI;
		string venueURI;
		string title140; // Up to 140 character title
		string descr500; // Up to 500 character description
	}
	mapping(uint256 => Location) rows;

	event Creation(
		address indexed lister,
		uint indexed newId
	);

	event ListerChanged(
		uint indexed rowID,
		address indexed oldValue,
		address indexed newValue
	);

	event SignerChanged(
		uint indexed rowID,
		address indexed oldValue,
		address indexed newValue
	);

	event PicolatChanged(
		uint indexed rowID,
		int48 oldValue,
		int48 newValue
	);

	event PicolonChanged(
		uint indexed rowID,
		int48 oldValue,
		int48 newValue
	);

	event CmAltitudeChanged(
		uint indexed rowID,
		int32 oldValue,
		int32 newValue
	);

	event CmRadiusChanged(
		uint indexed rowID,
		uint32 oldValue,
		uint32 newValue
	);

	event ParentChanged(
		uint indexed rowID,
		uint oldValue,
		uint newValue
	);

	event ImageURIChanged(
		uint indexed rowID,
		string oldValue,
		string newValue
	);

	event VenueURIChanged(
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
		address payable initialOwner
	)
		PayableOwnable(initialOwner)
	{
	}

	function create(
		address lister,
		int48 picolat,
		int48 picolon,
		uint32 cmRadius
	) public {
		maxUsedID++;
		emit Creation(
			lister,
			maxUsedID
		);
		_changeLister(
			maxUsedID,
			lister
		);
		_changePicolat(
			maxUsedID,
			picolat
		);
		_changePicolon(
			maxUsedID,
			picolon
		);
		_changeCmRadius(
			maxUsedID,
			cmRadius
		);
		_setLastUpdated(
			maxUsedID
		);
	}

	function _setLastUpdated(
		uint rowID
	) private {
		rows[rowID].lastUpdated = block.timestamp;
	}

	function changeLister(
		uint rowID,
		address newValue
	) public onlyLister(rowID) {
		_changeLister(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
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

	function changeSigner(
		uint rowID,
		address newValue
	) public onlyLister(rowID) {
		_changeSigner(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
	}

	function _changeSigner(
		uint rowID,
		address newValue
	) private {
		emit SignerChanged(
			rowID,
			rows[rowID].signer,
			newValue
		);
		rows[rowID].lister = newValue;
	}

	// A convenience combination function
	function changeCoordinates(
		uint rowID,
		int48 picolat,
		int48 picolon
	) public onlyLister(rowID) {
		_changePicolat(
			rowID,
			picolat
		);
		_changePicolon(
			rowID,
			picolon
		);
		_setLastUpdated(rowID);
	}

	function changePicolat(
		uint rowID,
		int48 newValue
	) public onlyLister(rowID) {
		_changePicolat(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
	}

	function _changePicolat(
		uint rowID,
		int48 newValue
	) private {
		emit PicolatChanged(
			rowID,
			rows[rowID].picolat,
			newValue
		);
		rows[rowID].picolat = newValue;
	}

	function changePicolon(
		uint rowID,
		int48 newValue
	) public onlyLister(rowID) {
		_changePicolon(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
	}

	function _changePicolon(
		uint rowID,
		int48 newValue
	) private {
		emit PicolonChanged(
			rowID,
			rows[rowID].picolon,
			newValue
		);
		rows[rowID].picolon = newValue;
	}

	function changeCmAltitude(
		uint rowID,
		int32 newValue
	) public onlyLister(rowID) {
		_changeCmAltitude(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
	}

	function _changeCmAltitude(
		uint rowID,
		int32 newValue
	) private {
		emit CmAltitudeChanged(
			rowID,
			rows[rowID].cmAltitude,
			newValue
		);
		rows[rowID].cmAltitude = newValue;
	}

	function changeCmRadius(
		uint rowID,
		uint32 newValue
	) public onlyLister(rowID) {
		_changeCmRadius(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
	}

	function _changeCmRadius(
		uint rowID,
		uint32 newValue
	) private {
		emit CmRadiusChanged(
			rowID,
			rows[rowID].cmRadius,
			newValue
		);
		rows[rowID].cmRadius = newValue;
	}

	function changeParent(
		uint rowID,
		uint newValue
	) public onlyLister(rowID) {
		_changeParent(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
	}

	function _changeParent(
		uint rowID,
		uint newValue
	) private {
		emit ParentChanged(
			rowID,
			rows[rowID].parent,
			newValue
		);
		rows[rowID].parent = newValue;
	}

	function changeImageURI(
		uint rowID,
		string calldata newValue
	) public onlyLister(rowID) {
		_changeImageURI(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
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

	function changeVenueURI(
		uint rowID,
		string calldata newValue
	) public onlyLister(rowID) {
		_changeVenueURI(
			rowID,
			newValue
		);
		_setLastUpdated(rowID);
	}

	function _changeVenueURI(
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
		_setLastUpdated(rowID);
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
		_setLastUpdated(rowID);
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
