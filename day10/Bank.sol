// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    address public owner = msg.sender;
    mapping(address => uint256) public balances;
    struct TopHolder {
        address holder;
        uint256 amount;
    }/Users/huliang/Desktop/my/foundry_program/learn_foundry/test_logs.txt
    TopHolder[3] public topAddresses;

    constructor () payable {
        deposit();
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
        updateTopAddresses();
    }
    
    function withdraw(uint256 _amount) public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    // 判断当前存款地址是否在前三，如果大于前三，替换
    function updateTopAddresses() internal {
        uint256 currentBalance = balances[msg.sender];
        if (currentBalance == 0) return;  // 余额为0不需要更新
    
        // 检查是否已经在排行榜中
        for (uint i = 0; i < topAddresses.length; i++) {
            if (topAddresses[i].holder == msg.sender) {
                // 更新已存在的记录
                topAddresses[i].amount = currentBalance;
                // 重新排序
                _sortTopHolders();
                return;
            }
    }
        
        // 检查是否能进入排行榜
        for (uint i = 0; i < topAddresses.length; i++) {
            if (currentBalance > topAddresses[i].amount) {
                // 将新记录插入到当前位置
                for (uint j = topAddresses.length - 1; j > i; j--) {
                    topAddresses[j] = topAddresses[j - 1];
                }
                topAddresses[i] = TopHolder(msg.sender, currentBalance);
                return;
            }
        }
    }

    // 辅助函数：对排行榜进行排序
    function _sortTopHolders() internal {
        for (uint i = 1; i < topAddresses.length; i++) {
            TopHolder memory key = topAddresses[i];
            uint j = i;
            while (j > 0 && topAddresses[j - 1].amount < key.amount) {
                topAddresses[j] = topAddresses[j - 1];
                j--;
            }
            if (j != i) {
                topAddresses[j] = key;
            }
        }
    }

    function getTopAddresses() public view returns (TopHolder[3] memory) {
        return topAddresses;
    }

    receive() external payable {}
}
