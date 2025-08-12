// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title 借贷市场接口
 * @dev 简化的借贷市场接口，用于存入 ETH 赚取利息
 */
interface ILendingMarket {
    /**
     * @dev 存入 ETH 到借贷市场
     */
    function deposit() external payable;

    /**
     * @dev 从借贷市场提取 ETH
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external;

    /**
     * @dev 获取账户在借贷市场的余额
     * @param account 账户地址
     * @return 余额
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 获取账户赚取的利息
     * @param account 账户地址
     * @return 利息数量
     */
    function earnedInterest(address account) external view returns (uint256);
}

/**
 * @title 简单的借贷市场实现
 * @dev 模拟借贷市场，提供基本的存取款和利息计算功能
 */
contract SimpleLendingMarket is ILendingMarket {
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _lastUpdateTime; // 上次更新时间
    
    uint256 public constant INTEREST_RATE = 5; // 5% 年利率
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 3600;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    /**
     * @dev 存入 ETH 到借贷市场
     */
    function deposit() external payable override {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        // 更新利息
        _updateInterest(msg.sender);
        
        _balances[msg.sender] += msg.value;
        _lastUpdateTime[msg.sender] = block.timestamp;
        
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 从借贷市场提取 ETH
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external override {
        require(amount > 0, "Withdraw amount must be greater than 0");
        
        // 更新利息
        _updateInterest(msg.sender);
        
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        
        _balances[msg.sender] -= amount;
        _lastUpdateTime[msg.sender] = block.timestamp;
        
        payable(msg.sender).transfer(amount);
        
        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev 获取账户在借贷市场的余额
     * @param account 账户地址
     * @return 余额
     */
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account] + earnedInterest(account);
    }

    /**
     * @dev 获取账户赚取的利息
     * @param account 账户地址
     * @return 利息数量
     * @notice 外部函数，用于获取账户的利息余额
     */
    function earnedInterest(address account) public view override returns (uint256) {
        if (_balances[account] == 0 || _lastUpdateTime[account] == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - _lastUpdateTime[account];
        return (_balances[account] * INTEREST_RATE * timeElapsed) / (100 * SECONDS_PER_YEAR);
    }

    /**
     * @dev 内部函数：更新利息
     * @param account 账户地址
     * @notice 内部函数，用于更新账户的利息余额
     */
    function _updateInterest(address account) internal {
        uint256 interest = earnedInterest(account);
        if (interest > 0) {
            _balances[account] += interest;
        }
    }
}