// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./IAccesDeployer.sol";
import "./AccesVesting_V2.sol";

contract AccesModuleVesting {
    IAccesDeployer public deployer;
    address public owner;

    address payable public addressOfVestingContract;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
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
        ERC20 _Acces,
        address timelock
    ) public onlyOwner {
        require(addressOfVestingContract == address(0), "Vesting contract already deployed");

        AccesVesting_V2 vestingContract = new AccesVesting_V2(_Acces, timelock, address(deployer));
        addressOfVestingContract = payable(address(vestingContract));
    }

    function addInvestorInVesting(
        address _module,
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

        deployer.submitTransactionFromModule(msg.sender, _module, 0, data);
    }

    function setMonthlyPercentage(address _module, uint256 _mP) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "setMonthlyPercentage(uint256)",
            _mP
        );

        deployer.submitTransactionFromModule(msg.sender, _module, 0, data);
    }

    function addToBlackList(address _module, address _investor) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "addToBlackList(address)",
            _investor
        );

        deployer.submitTransactionFromModule(msg.sender, _module, 0, data);
    }

    function removeFromBlackList(address _module, address _investor) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "removeFromBlackList(address)",
            _investor
        );

        deployer.submitTransactionFromModule(msg.sender, _module, 0, data);
    }

    function activateSamePercentage(address _module) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "activateSamePercentage()"
        );

        deployer.submitTransactionFromModule(msg.sender, _module, 0, data);
    }

    function disableSamePercentage(address _module) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "disableSamePercentage()"
        );

        deployer.submitTransactionFromModule(msg.sender, _module, 0, data);
    }

    function editInvestorLock(address _module, address _investor, uint256 _yPercent, uint256 _mPercent) public onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "editInvestorLock(address,uint256,uint256)",
            _investor, _yPercent, _mPercent
        );

        deployer.submitTransactionFromModule(msg.sender, _module, 0, data);
    }
}
