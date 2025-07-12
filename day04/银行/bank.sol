//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract Bank {
       // 存储的地址余额
    mapping(address => uint256) public balance;
    
    // 记录前三名地址及其余额
    struct TopHolder {
        address holder;
        uint256 amount;
    }
    TopHolder[3] public topAddresses;
    
    // 合约拥有者
    address public owner = msg.sender;
    
    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed from, address indexed to, uint256 amount);
    event TopHoldersUpdated(TopHolder[3] topHolders);

    // 修饰器：仅所有者
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    // 接收以太币
    receive() external payable {
        deposit();
    }
    // 存款函数
    function deposit() public payable {
        require(msg.value > 0, "Amount must be greater than 0");
        
        // 更新用户余额
        balance[msg.sender] += msg.value;
        
        // 更新前三名
        _updateTopHolders(msg.sender, balance[msg.sender]);
        
        emit Deposit(msg.sender, msg.value);
    }
       // 更新前三名持有者
    function _updateTopHolders(address _user, uint256 _newBalance) private {
        uint256 minIndex = 0;
        uint256 minBalance = type(uint256).max;
        bool userInTop = false;
        uint256 userIndex = 3;

        // 一次遍历完成两个任务：
        // 1. 找到最小余额及其索引
        // 2. 检查用户是否已经在排行榜中
        for (uint256 i = 0; i < 3; i++) {
            // 更新最小余额信息
            if (topAddresses[i].amount < minBalance) {
                minBalance = topAddresses[i].amount;
                minIndex = i;
            }
            // 检查是否是当前用户
            if (topAddresses[i].holder == _user) {
                userInTop = true;
                userIndex = i;
                break;
            }
        }

        // 如果用户不在排行榜中，检查是否需要替换最小余额
        if (!userInTop && _newBalance > minBalance) {
            // 替换最小余额的位置
            topAddresses[minIndex] = TopHolder(_user, _newBalance);
        } 
        // 如果用户在排行榜中，更新其余额
        else if (userInTop) {
            topAddresses[userIndex].amount = _newBalance;
        }
    }
        // 取款
    function withdraw(address _from, address payable _to, uint256 _amount) public onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= balance[_from], "Insufficient balance");
        require(_to != address(0), "Invalid recipient address");
        
        // 更新用户余额
        balance[_from] -= _amount;
        
        // 转账到指定地址
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(_from, _to, _amount);
    }
    // 获取合约余额
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // 获取用户余额
    function getUserBalance(address _user) external view returns (uint256) {
        return balance[_user];
    }
    
    // 获取前三名信息
    function getTopHolders() external view returns (TopHolder[3] memory) {
        return topAddresses;
    }

    // 更新前三名（由后端计算后调用）
    function updateTopHolders(TopHolder[3] memory _topAddresses) public onlyOwner {
        // 验证输入的有效性
        for (uint i = 0; i < 3; i++) {
            require(_topAddresses[i].holder != address(0), "Invalid holder address");
            if (i > 0) {
                require(
                    _topAddresses[i].amount <= _topAddresses[i-1].amount,
                    "Holders must be in descending order by amount"
                );
            }
            
            // 手动复制每个元素
            topAddresses[i] = TopHolder({
                holder: _topAddresses[i].holder,
                amount: _topAddresses[i].amount
            });
        }
    }
}