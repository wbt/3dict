// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

interface IGamesController {

		function isAllowedToList(address potentialLister) external view returns (bool);

}
