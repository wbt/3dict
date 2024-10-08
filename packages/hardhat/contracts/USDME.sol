// SPDX-License-Identifier: MIT
// Generated with https://wizard.openzeppelin.com/
// This contract is intended to simulate an existing widely used ERC20 already deployed on a main chain.
// It is a token only intended to be used for development & testing on chains that don't have a predeployed token ecosystem.
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USDME is ERC20, ERC20Permit, Ownable {
    constructor(address initialOwner)
        ERC20("USDME", "USDME")
        ERC20Permit("USDME")
        Ownable(initialOwner)
    {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}
