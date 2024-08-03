// SPDX-License-Identifier: MIT

pragma solidity = 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract MetaccesPolygon is ERC20, ERC20Burnable {
    using SafeMath for uint256;
    address private owner;
    address public bridge;

    uint256 internal sSBlock;uint256 internal sEBlock;uint256 internal sTot;
    uint256 internal sPrice;
    uint256 internal path = 10** decimals();
    uint256 public max = 20 * path;
    uint256 public min = max.div(100);
    uint256 public privateLimit = 1000000;

    event WithdrawalBNB(uint256 _amount, uint256 decimal, address to); 
    event WithdrawalToken(address _tokenAddr, uint256 _amount,uint256 decimals, address to);
    event SetBridge(address _bridge);
    event PrivateSale(uint256 Amount, uint256 Price);
    event saleStarted(uint256 blockNumber);
    event saleEnded(uint256 Time);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner(){
        require(msg.sender == owner,"caller not owner!");
        _;
    }
 

constructor (address _bridge) ERC20("Metacces", "Acces") payable {
    owner = msg.sender;
    bridge = _bridge;
     _mint (address(this), 100000000 * path); // 20% of the Total Supply
        
}
   function transferOwnership(address _newOwner) external onlyOwner{
       require(_newOwner != address(0),"address zero!");
       owner = _newOwner;
       emit OwnershipTransferred(owner, _newOwner);
   }

   function privateSale(address) public payable returns (bool success){
    require(balanceOf(address(msg.sender)) <= privateLimit * path , "You reached your private sale limit");  
    require(sSBlock <= block.number && block.number <= sEBlock, "Private Sale has ended or did not start yet");

    uint256 _eth = msg.value;
    uint256 _tkns;
    
    require ( _eth >= min && _eth <= max , "Less than Minimum or More than Maximum");
    _tkns = (sPrice.mul(_eth)).div(1 ether);
    sTot ++;
    
    _transfer(address(this), msg.sender, _tkns); 
    emit PrivateSale(_tkns, sPrice);
    return true;
  }

  function viewSale() public view returns(uint256 StartBlock, uint256 EndBlock, uint256 SaleCount, uint256 SalePrice){
    return(sSBlock, sEBlock, sTot,  sPrice);
  }
  
  function startSale(uint256 _sEBlock, uint256 _sPrice) public onlyOwner{
      require(_sEBlock !=0 && _sPrice !=0,"Zero!");
   sEBlock = _sEBlock; 
   sPrice =_sPrice;
  }
  
  function endSale () public onlyOwner{
          sEBlock = block.number;
          emit saleEnded(block.timestamp);
  }

  function changeMinMaxPrivateSale(uint256 minAmount, uint256 maxAmount) external onlyOwner {
      require(minAmount != 0 && maxAmount !=0,"Zero!");
      min = minAmount;
      max = maxAmount * path;
  }

  function setPrivateLimit (uint256 _limit) external onlyOwner {
      require(_limit != 0, "zero!");
      privateLimit = _limit;
  }

  function withdrawalToken(address _tokenAddr, uint256 _amount, uint256 decimal, address to) external onlyOwner() {
      require(_tokenAddr != address(0),"address zero!");
        uint256 dcml = 10 ** decimal;
        ERC20 token = ERC20(_tokenAddr);
        emit WithdrawalToken(_tokenAddr, _amount, decimal, to);
        token.transfer(to, _amount*dcml); 
    }
    
  function withdrawalBNB(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(address(this).balance >= _amount);
        uint256 dcml = 10 ** decimal;
        emit WithdrawalBNB(_amount, decimal, to);
        payable(to).transfer(_amount*dcml);      
    }

  function setBridge(address _bridge) onlyOwner public {
      require(_bridge != address(0),"zero address!");
      emit SetBridge(_bridge);
        bridge = _bridge;
    }


  /**
    * @dev Only callable by account with access (gateway role)
    */

    function mint(
        address recipient,
        uint256 amount
        )
        public
        virtual
        onlyBridge
        {
        _mint(recipient, amount);
    }

    /**
    * @dev Only callable by account with access (gateway role)
    * @inheritdoc ERC20Burnable
    */
    function burn(
        uint256 amount
        )
        public
        override(ERC20Burnable)
        virtual
        onlyBridge
        {
        super.burn(amount);
    }

    /**
    * @dev Only callable by account with access (gateway role)
    * @inheritdoc ERC20Burnable
    */
    function burnFrom(
        address account,
        uint256 amount
        )
        public
        override(ERC20Burnable)
        virtual
        onlyBridge
        {
        super.burnFrom(account, amount);
    }

    modifier onlyBridge {
      require(msg.sender == bridge, "only bridge has access to this child token function");
      _;
    }

   receive() external payable {}
}

/**********************************
 Proudly Developed by Metacces Team
***********************************/
