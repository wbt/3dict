//SPDX-License-Identifier: UNLICENSED
//Having profile information is mainly important for game/question sponsors and referees,
//but players can have them too; all positions are public.
pragma solidity >=0.8.0 <0.9.0;

import "./PayableOwnable.sol";

contract Profiles is PayableOwnable {

	struct Profile {
		string imageURI;
		string profileURI; // Could be linktree
		string name75; // Up to 75 character name
		string title140; // Up to 140 character title
		string descr500; // Up to 500 character description
	}

	mapping(address => Profile) profiles;

	event ImageURIChanged(
		address indexed acct,
		string oldValue,
		string newValue
	);

	event ProfileURIChanged(
		address indexed acct,
		string oldValue,
		string newValue
	);

	event Name75Changed(
		address indexed acct,
		string oldValue,
		string newValue
	);

	event Title140Changed(
		address indexed acct,
		string oldValue,
		string newValue
	);

	event Descr500Changed(
		address indexed acct,
		string oldValue,
		string newValue
	);

	constructor(
		address payable initialOwner
	)
		PayableOwnable(initialOwner)
	{
	}

	function changeImageURI(
		string calldata newValue
	) public {
		emit ImageURIChanged(
			msg.sender,
			profiles[msg.sender].imageURI,
			newValue
		);
		profiles[msg.sender].imageURI = newValue;
	}

	function changeProfileURI(
		string calldata newValue
	) public {
		emit ProfileURIChanged(
			msg.sender,
			profiles[msg.sender].profileURI,
			newValue
		);
		profiles[msg.sender].profileURI = newValue;
	}

	function changeName75(
		string calldata newValue
	) public {
		emit Name75Changed(
			msg.sender,
			profiles[msg.sender].name75,
			newValue
		);
		profiles[msg.sender].name75 = newValue;
	}

	function changeTitle140(
		string calldata newValue
	) public {
		emit Title140Changed(
			msg.sender,
			profiles[msg.sender].title140,
			newValue
		);
		profiles[msg.sender].title140 = newValue;
	}

	function changeDescr500(
		string calldata newValue
	) public {
		emit Descr500Changed(
			msg.sender,
			profiles[msg.sender].descr500,
			newValue
		);
		profiles[msg.sender].descr500 = newValue;
	}

}
