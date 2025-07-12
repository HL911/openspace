// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBank {
    function deposit() payable external ;
    function withdraw(uint256 _amount) payable external;
}



contract Bank is IBank {
    modifier onlyOwner() {
        require(msg.sender == owner,"Only owner can call this");
        _;
    }

    modifier balanceCheck() {
        require(balances[msg.sender] >= msg.value,"Insufficient balance");
        _;
    }
    mapping(address => uint256) public balances;
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function deposit() payable  public virtual onlyOwner {
        balances[msg.sender] += msg.value;
    }
    
    function withdraw(uint256 _amount) payable external override balanceCheck {
        payable(msg.sender).transfer(_amount);
        balances[msg.sender] -= _amount;
    }
}


contract BigBank is Bank {
    // 每次存款必须大于0.001 ether
    modifier depositCheck() {
        require(msg.value >= 0.001 ether,"Deposit amount must be greater than 0.001 ether");
        _;
    }

    function deposit() payable public override depositCheck {
        super.deposit();
    }

    function updateOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }

}
    
contract Admin  {
    address public owner;
    constructor() {
        owner = msg.sender;
    }
    modifier onlyOwner() {
        require(msg.sender == owner,"Only owner can call this");
        _;
    }

    
    function adminWithdraw(IBank _bank) payable  external onlyOwner {
        payable(address(this)).transfer(address(_bank).balance);
    }

    function withdraw() payable  external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}