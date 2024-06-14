// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IAccesDeployer} from "./IAccesDeployer.sol";
import {AccesVesting_V2} from "./AccesVesting_V2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract AccesModuleVesting {
    IAccesDeployer public deployer;
    address public owner;

    address payable public addressOfVestingContract;

    modifier onlyOwner() {
        require(msg.sender == owner, "Module: not owner");
        _;
    }

    constructor(address _deployer) {
        deployer = IAccesDeployer(_deployer);
        owner = msg.sender;
    }

    function setDeployer(address _deployer) public onlyOwner {
        deployer = IAccesDeployer(_deployer);
    }

    function deployVestingContract(
        IERC20 _Acces
    ) public onlyOwner {
        require(addressOfVestingContract == address(0), "Vesting contract already deployed");

        AccesVesting_V2 vestingContract = new AccesVesting_V2(_Acces, address(deployer));
        addressOfVestingContract = payable(address(vestingContract));
    }

    function addInvestorInVesting(
        address _investor, 
        bool _isTeam, 
        uint256 _amount, 
        uint256 _yPercent, 
        uint256 _lockTime, 
        uint256 _firstUnlock
    ) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "addInvestor(address,bool,uint256,uint256,uint256,uint256)",
            _investor, _isTeam, _amount, _yPercent, _lockTime, _firstUnlock
        );

        deployer.submitTransactionFromModule(msg.sender, addressOfVestingContract, 0, data);
    }

    function setMonthlyPercentage(uint256 _mP) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "setMonthlyPercentage(uint256)",
            _mP
        );

        deployer.submitTransactionFromModule(msg.sender, addressOfVestingContract, 0, data);
    }

    function addToBlackList(address _investor) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "addToBlackList(address)",
            _investor
        );

        deployer.submitTransactionFromModule(msg.sender, addressOfVestingContract, 0, data);
    }

    function removeFromBlackList(address _investor) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "removeFromBlackList(address)",
            _investor
        );

        deployer.submitTransactionFromModule(msg.sender, addressOfVestingContract, 0, data);
    }

    function activateSamePercentage() public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "activateSamePercentage()"
        );

        deployer.submitTransactionFromModule(msg.sender, addressOfVestingContract, 0, data);
    }

    function disableSamePercentage() public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "disableSamePercentage()"
        );

        deployer.submitTransactionFromModule(msg.sender, addressOfVestingContract, 0, data);
    }

}
