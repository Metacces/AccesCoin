// SPDX-License-Identifier: MIT

/****************************
Metacces Vesting Contract V2
****************************/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

pragma solidity 0.8.26;

contract AccesVesting_V2 {

    address public owner;

    address public constant zeroAddress = address(0x0);
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    IERC20 public Acces;
    uint256 public constant monthly = 30 days;
    uint256 public constant yearly = 12 * monthly; // Define a year as 12 months
    uint256 public investorCount;
    uint256 public investorsVault;
    uint256 public teamVault;
    uint256 public teamCount;
    uint256 public totalLocked;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 public constant hPercent = 100; //100%
    uint256 private _status;
    uint256 public mP = 5; /* Monthy percentage */
    uint256 public accesAmount;
    bool public samePercentage = false;

    TimelockController public timelockController;

    event InvestorAdded(address Investor, uint256 Amount, string investorType, uint256 yearsLocked);
    event TeamAdded(address Team, uint256 Amount);
    event AccesClaimed(address Investor, uint256 Amount);
    event ChangeOwner(address NewOwner);
    event addressBlacklisted(address);
    event removedFromBlacklist(address);
    event fixedLock(address Investor);
    event MonthlyPercentageChanged(uint256 NewPercentage);
    event WithdrawalBNB(uint256 _amount, address to); 
    event WithdrawalAcces(uint256 _amount, address to);
    event WithdrawalBEP20(address _tokenAddr, uint256 _amount, address to);
    
    struct InvestorSafe {
        uint256 amount;
        uint256 yP;
        uint256 mP;
        uint256 yearlyAllowance;
        uint256 yearLock;
        uint256 monthLock;
        uint256 lockTime;
        uint256 firstUnlock;
        uint256 timeStart;
        bool isTeam;
    }
    
    struct amountCalculation {
        uint256 yearlyAllowed;
        uint256 monthlyAllowed;
        uint256 yearsCount;
        uint256 monthsCount;
        uint256 endYear;
    }

    mapping(address => bool) public Investor;
    mapping(address => InvestorSafe) public investor;
    mapping(address => amountCalculation) public investorAllowance;
    mapping(address => bool) public blackList;

    modifier onlyOwner() {
        require(msg.sender == owner, "AccesVesting: Not Owner");
        _;
    }

    modifier isInvestor(address _investor) {
        require(Investor[_investor] == true, "AccesVesting: Not an Investor!");
        _;
    }

    modifier isNotBlackListed(address _investor) {
        require(blackList[_investor] != true, "AccesVesting: Your wallet is Blacklisted!");
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(IERC20 _Acces, TimelockController _timelockController) {
        timelockController = _timelockController;
        investorCount = 0;
        Acces = _Acces;
        _status = _NOT_ENTERED;
        owner = address(timelockController);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != zeroAddress, "AccesVesting: Zero Address");
        emit ChangeOwner(_newOwner);
        owner = _newOwner;
    }

    function setMonthlyPercentage(uint256 _mP) external onlyOwner {
        require(_mP > 0 && _mP <= 30, "AccesVesting: Min 1% Max 30%");
        mP = _mP;
        emit MonthlyPercentageChanged(_mP);
    }

    function addToBlackList(address _investor) external onlyOwner {
        require(_investor != zeroAddress, "AccesVesting: Zero address");
        blackList[_investor] = true;
        emit addressBlacklisted(_investor);
    }

    function removeFromBlackList(address _investor) external onlyOwner {
        require(_investor != zeroAddress, "AccesVesting: Zero address");
        blackList[_investor] = false;
        emit removedFromBlacklist(_investor);
    }

    function activateSamePercentage() external onlyOwner {
        samePercentage = true;
    }

    function disableSamePercentage() external onlyOwner {
        samePercentage = false;
    }

    function addInvestor(address _investor, bool _isTeam, uint256 _amount, uint256 _yPercent, uint256 _lockTime, uint256 _firstUnlock) external onlyOwner {
        require(_investor != zeroAddress && _investor != deadAddress, "AccesVesting: Zero Address Dead!");
        string memory investorType;
        uint256 availableAmount = Acces.balanceOf(address(this)) - (investorsVault) - (teamVault);
        require(availableAmount >= _amount, "AccesVesting: No Acces");
        uint256 lockTime = _lockTime*(monthly);
        uint256 firstUnlock = _firstUnlock*(monthly);
        require(_amount > 0, "AccesVesting: Amount!");
        if(investor[_investor].amount > 0) {
            investor[_investor].amount += _amount;
            if (investor[_investor].isTeam) {
                teamVault += _amount;
            } else {
                investorsVault += _amount;
            }
            setAllowance(_investor); // Update investorAllowance
            return;
        }
        require(lockTime >= monthly*(3), "AccesVesting: Please set a time in the future more than 90 days!");
        require(firstUnlock < lockTime, "AccesVesting: lock error");
        investor[_investor].amount = _amount;
        investor[_investor].yP = _yPercent;
        investor[_investor].mP = hPercent / 12;
        setAllowance(_investor);
        investor[_investor].lockTime = lockTime+(block.timestamp);
        investor[_investor].timeStart = block.timestamp;
        if(lockTime < yearly) {
            investorAllowance[_investor].endYear = lockTime+(block.timestamp);
        } else {
            uint256 lockYears = (lockTime / yearly)*(yearly);
            investor[_investor].yearLock = lockYears+(block.timestamp);
            investorAllowance[_investor].endYear = yearly+(firstUnlock)+(block.timestamp);
        }
        investor[_investor].monthLock = monthly+(block.timestamp);
        investor[_investor].firstUnlock = firstUnlock+(block.timestamp);
        investor[_investor].isTeam = _isTeam;
        Investor[_investor] = true;
        if(_isTeam == true) {
            teamVault += _amount;
            teamCount++;
            investorType = "Team";
        } else {
            investorsVault += _amount;
            investorCount++;
            investorType = "Investor";
        }
        allVaults();
        emit InvestorAdded(_investor, _amount, investorType, _lockTime/(12));
    }

    function claimMonthlyAmount() external isInvestor(msg.sender) isNotBlackListed(msg.sender) nonReentrant {
        require(investor[msg.sender].firstUnlock < block.timestamp, "AccesVesting: Unlock is not available yet");
        require(investorAllowance[msg.sender].yearlyAllowed > 0, "AccesVesting: Insufficient allowance, wait until next year!");
        uint256 monthlyAmount;

        while(investorAllowance[msg.sender].endYear <= block.timestamp) {
            if(investor[msg.sender].yearlyAllowance > investor[msg.sender].amount) {
                investor[msg.sender].yearlyAllowance = investor[msg.sender].amount;
            }
            uint256 leftOver = investorAllowance[msg.sender].yearlyAllowed;
            investorAllowance[msg.sender].yearlyAllowed = investor[msg.sender].yearlyAllowance;
            investorAllowance[msg.sender].yearsCount++;
            investorAllowance[msg.sender].endYear += yearly;
            investorAllowance[msg.sender].yearlyAllowed += leftOver;
            investorAllowance[msg.sender].monthlyAllowed = investorAllowance[msg.sender].yearlyAllowed / 12;
        }

        if(samePercentage == true) {
            monthlyAmount = investor[msg.sender].yearlyAllowance * mP / hPercent;
        } else {
            monthlyAmount = investorAllowance[msg.sender].monthlyAllowed;
        }
        uint256 monthLock = investor[msg.sender].monthLock;
        require(monthLock <= block.timestamp, "AccesVesting: Not yet");
        require(monthlyAmount > 0, "AccesVesting: No Acces");
        require(investor[msg.sender].amount >= monthlyAmount, "AccesVesting: Insufficient balance to subtract monthly amount");
        require(investorAllowance[msg.sender].yearlyAllowed >= monthlyAmount, "AccesVesting: Insufficient yearly allowance to subtract monthly amount");

        investor[msg.sender].amount -= monthlyAmount;

        // Update monthLock to the next month's start date
        investor[msg.sender].monthLock += monthly;

        if(investor[msg.sender].isTeam == true) {
            teamVault -= monthlyAmount;
        } else {
            investorsVault -= monthlyAmount;
        }
        investorAllowance[msg.sender].yearlyAllowed -= monthlyAmount;
        if(investor[msg.sender].amount == 0) {
            Investor[msg.sender] = false;
            delete investor[msg.sender];
            delete investorAllowance[msg.sender]; // Ensure allowance is deleted
            if(investor[msg.sender].isTeam == true) {
                teamCount--;
            } else {
                investorCount--;
            }
        }
        allVaults();
        emit AccesClaimed(msg.sender, monthlyAmount);
        Acces.transfer(msg.sender, monthlyAmount);
        investorAllowance[msg.sender].monthsCount++;
    }


    function claimRemainings() external isInvestor(msg.sender) isNotBlackListed(msg.sender) nonReentrant {
        uint256 totalTimeLock = investor[msg.sender].lockTime;
        require(totalTimeLock <= block.timestamp, "AccesVesting: Not yet");
        uint256 remainAmount = investor[msg.sender].amount;
        investor[msg.sender].amount = 0;
        if(investor[msg.sender].isTeam == true) {
            teamVault -= remainAmount;
            teamCount--;
        } else {
            investorsVault -= remainAmount;
            investorCount--;
        }
        Investor[msg.sender] = false;
        delete investor[msg.sender];
        delete investorAllowance[msg.sender]; // Ensure allowance is deleted
        emit AccesClaimed(msg.sender, remainAmount);
        Acces.transfer(msg.sender, remainAmount);
        allVaults();
    }

    function fixInvestorLock() external isInvestor(msg.sender) {
        while(investorAllowance[msg.sender].endYear <= block.timestamp) {
            uint256 leftOver = investorAllowance[msg.sender].yearlyAllowed;
            investorAllowance[msg.sender].yearlyAllowed = investor[msg.sender].yearlyAllowance;
            investorAllowance[msg.sender].yearsCount++;
            investorAllowance[msg.sender].endYear += yearly;
            investorAllowance[msg.sender].yearlyAllowed += leftOver;
            investorAllowance[msg.sender].monthlyAllowed = investorAllowance[msg.sender].yearlyAllowed / 12;
        }
        emit fixedLock(msg.sender);
    }


    function withdrawalAcces(uint256 _amount, address to) external onlyOwner {
        require(to != zeroAddress, "AccesVesting: zero address");
        allVaults();
        require(accesAmount > 0 && _amount <= accesAmount, "AccesVesting: No Acces!");
        emit WithdrawalAcces(_amount, to);
        Acces.transfer(to, _amount);
        allVaults();
    }

    function withdrawalBEP20(address _tokenAddr, uint256 _amount, address to) external onlyOwner {
        require(to != zeroAddress, "AccesVesting: zero address");
        IERC20 token = IERC20(_tokenAddr);
        require(token != Acces, "AccesVesting: Not Allowed!"); // Can't withdraw Acces using this function!
        emit WithdrawalBEP20(_tokenAddr, _amount, to);
        token.transfer(to, _amount); 
    }  

    function withdrawalBNB(uint256 _amount, address to) external onlyOwner {
        require(to != zeroAddress, "AccesVesting: zero address");
        require(address(this).balance >= _amount, "AccesVesting: Check balanace"); // No BNB balance available
        emit WithdrawalBNB(_amount, to);
        payable(to).transfer(_amount);      
    }

    receive() external payable {}

    function allVaults() internal {
        totalLocked = investorsVault+(teamVault);
        accesAmount = Acces.balanceOf(address(this))-(totalLocked);
    }

    function setAllowance(address _investor) internal {
        investor[_investor].yearlyAllowance = investor[_investor].amount*(investor[_investor].yP)/(hPercent);
        investorAllowance[_investor].yearlyAllowed = investor[_investor].yearlyAllowance;
        require(investorAllowance[_investor].yearlyAllowed > 0, "Year error");
        investorAllowance[_investor].monthlyAllowed = investorAllowance[_investor].yearlyAllowed/(12);
    }
}
