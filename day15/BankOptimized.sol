// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BankOptimized {
    mapping(address => uint256) public balances;
    address constant GUARD = address(1);
    mapping(address => address) _nextUsers;
    uint256 public listSize;
    uint256 public constant MAX_TOP_USERS = 10; // 只维护前10名
    
    event Deposit(address indexed user, uint256 amount, uint256 newBalance);
    event Withdraw(address indexed user, uint256 amount, uint256 newBalance);
    event TopListUpdated(address indexed user, uint256 newBalance, uint256 newRank);
    
    constructor() {
        _nextUsers[GUARD] = GUARD;
    }

    // 接收ETH存款 - 通过Metamask等钱包直接转账
    receive() external payable {
        _deposit(msg.value);
    }
    
    // 备用接收函数
    fallback() external payable {
        _deposit(msg.value);
    }

    // 手动存款函数（也支持ETH）
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        _deposit(msg.value);
    }

    // 内部存款逻辑
    function _deposit(uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 oldBalance = balances[msg.sender];
        uint256 newBalance = oldBalance + amount;
        balances[msg.sender] = newBalance;
        
        // 更新前10名链表
        _updateTopList(msg.sender, newBalance);
        
        emit Deposit(msg.sender, amount, newBalance);
    }

    // 取款函数
    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Contract insufficient funds");
        
        uint256 oldBalance = balances[msg.sender];
        uint256 newBalance = oldBalance - amount;
        
        // 先转账，再更新状态（防止重入攻击）
        payable(msg.sender).transfer(amount);
        
        balances[msg.sender] = newBalance;
        
        // 更新前10名链表
        _updateTopList(msg.sender, newBalance);
        
        emit Withdraw(msg.sender, amount, newBalance);
    }

    // 更新前10名链表
    function _updateTopList(address user, uint256 newBalance) internal {
        // 简化检查：只需要检查_nextUsers[user]即可
        bool wasInList = _nextUsers[user] != address(0);
        
        if (wasInList) {
            // 用户已在榜单中，先移除
            _removeFromTopList(user);
        }
        
        // 如果新余额大于0，尝试加入榜单
        if (newBalance > 0) {
            _addToTopList(user, newBalance);
        }
    }

    // 添加到前10名链表（自动寻找插入位置）
    function _addToTopList(address user, uint256 balance) internal {
        // 如果榜单未满，直接添加
        if (listSize < MAX_TOP_USERS) {
            address insertAfter = _findInsertPosition(balance);
            _insertUser(user, insertAfter);
            return;
        }
        
        // 榜单已满，检查是否能进入前10
        address lastUser = _getLastUser();
        if (balance > balances[lastUser]) {
            // 移除最后一名
            _removeFromTopList(lastUser);
            // 插入新用户
            address insertAfter = _findInsertPosition(balance);
            _insertUser(user, insertAfter);
        }
    }

    // 自动寻找插入位置（避免用户造假）
    function _findInsertPosition(uint256 balance) internal view returns(address) {
        address current = GUARD;
        while(_nextUsers[current] != GUARD && balances[_nextUsers[current]] >= balance) {
            current = _nextUsers[current];
        }
        return current;
    }

    // 插入用户到指定位置
    function _insertUser(address user, address insertAfter) internal {
        require(_nextUsers[user] == address(0), "User already in list");
        require(_nextUsers[insertAfter] != address(0) || insertAfter == GUARD, "Invalid insert position");
        
        _nextUsers[user] = _nextUsers[insertAfter];
        _nextUsers[insertAfter] = user;
        listSize++;
        
        emit TopListUpdated(user, balances[user], _getUserRank(user));
    }

    // 从榜单中移除用户
    function _removeFromTopList(address user) internal {
        require(_isInTopList(user), "User not in top list");
        
        address prevUser = _findPrevUser(user);
        _nextUsers[prevUser] = _nextUsers[user];
        _nextUsers[user] = address(0);
        listSize--;
    }

    // 检查用户是否在榜单中（优化版本）
    function _isInTopList(address user) internal view returns(bool) {
        // 直接检查指针，避免遍历链表
        return user != GUARD && _nextUsers[user] != address(0);
    }

    // 找到用户的前一个节点
    function _findPrevUser(address user) internal view returns(address) {
        address current = GUARD;
        while(_nextUsers[current] != GUARD && _nextUsers[current] != user) {
            current = _nextUsers[current];
        }
        require(_nextUsers[current] == user, "User not found");
        return current;
    }

    // 获取榜单最后一名用户
    function _getLastUser() internal view returns(address) {
        require(listSize > 0, "List is empty");
        
        address current = GUARD;
        while(_nextUsers[current] != GUARD) {
            if (_nextUsers[_nextUsers[current]] == GUARD) {
                return _nextUsers[current];
            }
            current = _nextUsers[current];
        }
        return current;
    }

    // 获取用户排名
    function _getUserRank(address user) internal view returns(uint256) {
        if (!_isInTopList(user)) return 0;
        
        uint256 rank = 1;
        address current = _nextUsers[GUARD];
        while(current != GUARD && current != user) {
            rank++;
            current = _nextUsers[current];
        }
        return rank;
    }

    // 公开查询函数
    
    // 获取前K名用户（最多10名）
    function getTopUsers(uint256 k) external view returns(address[] memory, uint256[] memory) {
        require(k <= listSize && k <= MAX_TOP_USERS, "Invalid k value");
        
        address[] memory users = new address[](k);
        uint256[] memory userBalances = new uint256[](k);
        
        address current = _nextUsers[GUARD];
        for(uint256 i = 0; i < k; i++) {
            users[i] = current;
            userBalances[i] = balances[current];
            current = _nextUsers[current];
        }
        
        return (users, userBalances);
    }

    // 获取用户排名
    function getUserRank(address user) external view returns(uint256) {
        return _getUserRank(user);
    }

    // 检查用户是否在前10名
    function isInTopList(address user) external view returns(bool) {
        return _isInTopList(user);
    }

    // 获取合约ETH余额
    function getContractBalance() external view returns(uint256) {
        return address(this).balance;
    }

    // 验证插入位置（内部使用）
    function _verifyIndex(address prevUser, uint256 newValue, address nextUser)
    internal
    view
    returns(bool)
    {
        return (prevUser == GUARD || balances[prevUser] >= newValue) && 
              (nextUser == GUARD || newValue > balances[nextUser]);
    }
}