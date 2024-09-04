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
		//TODO: allow token choice to be a per-game setting:
		//addr tokenAddr: The token address exchangeable 1:1 for tokens in the game; auto payout in that token after the game end time
		bool checkInRequired;
		uint24 sponsorFractionOfOptionPool; // A percentage (e.g. 2 for 2%) * 10^5; can’t be changed after CheckInStart
		uint maxQuestionBid; // in token count per question per player.
		bool openToAnyAsker;
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
		games[maxUsedGameID].lister = lister;
	}

}
