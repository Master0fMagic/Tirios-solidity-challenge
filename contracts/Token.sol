pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  // Additional state variables
  address[] private holders;
  mapping(address => uint256) private holderIndex; // 1-based index (0 = not a holder)
  mapping(address => uint256) private withdrawableDividends;
  mapping(address => mapping(address => uint256)) private allowances;

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(allowances[from][msg.sender] >= value, "Insufficient allowance");
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Must send ETH to mint");
    
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    
    _addHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 balance = balanceOf[msg.sender];
    require(balance > 0, "No balance to burn");
    
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(balance);
    
    _removeHolder(msg.sender);
    
    dest.transfer(balance);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0 && index <= holders.length, "Index out of bounds");
    return holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Must send ETH for dividend");
    
    for (uint256 i = 0; i < holders.length; i++) {
      address holder = holders[i];
      uint256 holderBalance = balanceOf[holder];
      uint256 dividend = holderBalance.mul(msg.value).div(totalSupply);
      withdrawableDividends[holder] = withdrawableDividends[holder].add(dividend);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = withdrawableDividends[msg.sender];
    require(amount > 0, "No dividends to withdraw");
    
    withdrawableDividends[msg.sender] = 0;
    dest.transfer(amount);
  }

  function _addHolder(address holder) internal {
    if (holderIndex[holder] == 0) {
      holders.push(holder);
      holderIndex[holder] = holders.length; 
    }
  }

  function _removeHolder(address holder) internal {
    uint256 index = holderIndex[holder];
    if (index > 0) {
      // swap with last element and pop (1-indexed)
      uint256 lastIndex = holders.length;
      address lastHolder = holders[lastIndex - 1];
      
      holders[index - 1] = lastHolder;
      holderIndex[lastHolder] = index;
      
      holders.pop();
      holderIndex[holder] = 0;
    }
  }

  function _transfer(address from, address to, uint256 value) internal {
    require(balanceOf[from] >= value, "Insufficient balance");
    
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    
    if (balanceOf[from] == 0) {
      _removeHolder(from);
    }
    
    if (value > 0) {
      _addHolder(to);
    }
  }
}