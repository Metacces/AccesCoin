// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract AccesTimelock is TimelockController {
    uint256 public constant minDelay = 2 days;

    constructor(
        address[] memory proposers,
        address[] memory executors,
        address admin
    )
        TimelockController(minDelay, proposers, executors, admin)
    {}
}
