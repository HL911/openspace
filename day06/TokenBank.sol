// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenBank is ReentrancyGuard {
    // 代币合约地址
    IERC20 public immutable token;
    
    // 记录每个地址的存款余额
    mapping(address => uint256) public balances;
    
    // 事件
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    
    // 构造函数，设置代币合约地址
    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }
    
    // 存款函数
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        
        // 将代币从用户转移到合约
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");
        
        // 更新用户余额
        balances[msg.sender] += _amount;
        
        emit Deposited(msg.sender, _amount);
    }
    
    // 取款函数
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        // 更新用户余额（防止重入攻击）
        balances[msg.sender] -= _amount;
        
        // 将代币转回给用户
        bool success = token.transfer(msg.sender, _amount);
        require(success, "Token transfer failed");
        
        emit Withdrawn(msg.sender, _amount);
    }
    
    // 查询合约中的代币余额
    function getBankTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    // 查询用户存款余额
    function getUserBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }
}