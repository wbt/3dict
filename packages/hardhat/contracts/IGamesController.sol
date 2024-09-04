// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGamesController {

		function isAllowedToList(address potentialLister) external view returns (bool);

		function baseToken() external view returns (IERC20);
}
