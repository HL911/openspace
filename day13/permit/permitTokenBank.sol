// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PermitTokenBank is ReentrancyGuard {
    // 代币合约地址
    IERC20 public immutable token;
    // Permit 接口
    IERC20Permit public immutable permitToken;
     // 委托授权结构体
    struct DelegateAuthorization {
        address owner;        // 代币所有者
        address delegate;     // 被委托人
        uint256 amount;       // 授权金额
        uint256 deadline;     // 授权截止时间
        bool used;           // 是否已使用
    }
    
    // 委托授权映射：授权哈希 => 授权信息
    mapping(bytes32 => DelegateAuthorization) public delegateAuthorizations;   
    // 记录每个地址的存款余额
    mapping(address => uint256) public balances;
    

    // 事件
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event DelegateAuthorizationCreated(address indexed owner, address indexed delegate, uint256 amount, uint256 deadline, bytes32 authHash);
    event DelegateDepositExecuted(address indexed owner, address indexed delegate, uint256 amount, bytes32 authHash);
    
    
    // owner
    address public owner;
    
    // 构造函数，设置代币合约地址
    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
        permitToken = IERC20Permit(_token);
        owner = msg.sender;
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
    
    // 修改owner
    function changeOwner(address _newOwner) external{
        require(msg.sender == owner, "Only owner can change owner");
        owner = _newOwner;
    }

    // 支持离线签名授权存款
    function permitDeposit(
        address tokenOwner,   // 代币所有者（存款人）
        uint256 value,        // 存款金额
        uint256 deadline,     // 签名有效期截止时间
        uint8 v,              // 签名参数 v
        bytes32 r,            // 签名参数 r
        bytes32 s             // 签名参数 s
    ) external nonReentrant {
        require(value > 0, "Amount must be greater than zero");
        require(deadline >= block.timestamp, "Permit expired");
        require(tokenOwner != address(0), "Invalid owner address");
        
        // 使用 permit 进行离线签名授权
        // 这将授权当前合约从 owner 账户转移 value 数量的代币
        permitToken.permit(
            tokenOwner,      // 代币所有者
            address(this),   // 被授权的地址（当前合约）
            value,           // 授权金额
            deadline,        // 授权截止时间
            v,               // 签名参数
            r,               // 签名参数
            s                // 签名参数
        );
        
        // 执行代币转移
        bool success = token.transferFrom(tokenOwner, address(this), value);
        require(success, "Token transfer failed");
        
        // 更新用户余额
        balances[tokenOwner] += value;
        
        // 触发存款事件
        emit Deposited(tokenOwner, value);
    }

}