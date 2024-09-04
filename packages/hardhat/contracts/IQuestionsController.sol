// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IQuestionsController {

		function isAllowedToList(uint gameID, address potentialLister) external view returns (bool);

		function isRefereeFor(uint gameID, address potentialReferee) external view returns (bool);

		function gameToken(uint gameID) external view returns (IERC20);

		function maxQuestionBid(uint gameID) external view returns (uint256);

		function sponsorFractionOfOptionPool(uint gameID) external view returns (uint24);

}
