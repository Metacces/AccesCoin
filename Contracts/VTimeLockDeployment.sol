// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./AccesTimeLock.sol";

contract TimelockDeployer {
    address public timelockAddress;
    address public multisigWallet;

    constructor(address _multisig){
        multisigWallet = _multisig;
    }

    function deployTimelock() external {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = multisigWallet; // Multisig wallet
        executors[0] = multisigWallet; // Multisig wallet

        AccesTimelock timelock = new AccesTimelock(proposers, executors, multisigWallet);
        timelockAddress = address(timelock);
    }
}
