// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGamesController {

		function isAllowedToList(address potentialLister) external view returns (bool);

		function baseToken() external view returns (IERC20);

		// The implementing code must also GUARANTEE this value is in the positive int range, < 2**255.
		function defaultMaxQuestionBid() external view returns (uint256);

		function defaultSponsorFractionOfOptionPool() external view returns (uint24);

}
