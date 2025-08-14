// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DeflationToken
 * @dev 通缩型ERC20代币，每年减少1%的总供应量
 * @notice 该代币实现了基于时间的通缩机制，每365天执行一次rebase操作
 */
contract DeflationToken is ERC20, Ownable, ReentrancyGuard {
    /// @dev 基础总供应量，恒定不变
    uint256 private _baseTotalSupply;
    
    /// @dev 缩放因子，初始为1e18，每次rebase乘以0.99
    uint256 private _scaleFactor;
    
    /// @dev 上次rebase的时间戳
    uint256 private _lastRebaseTime;
    
    /// @dev 存储用户的原始余额
    mapping(address => uint256) private _rawBalances;
    
    /// @dev 存储授权的原始金额
    mapping(address => mapping(address => uint256)) private _rawAllowances;
    
    /// @dev rebase计数器
    uint256 private _epoch;
    
    /// @dev 一年的秒数 (365天)
    uint256 public constant YEAR_IN_SECONDS = 365 days;
    
    /// @dev 通缩率 (99%)
    uint256 public constant DEFLATION_RATE = 99;
    uint256 public constant DEFLATION_BASE = 100;
    
    /// @dev 精度常数
    uint256 public constant PRECISION = 1e18;

    /**
     * @dev Rebase事件
     * @param epoch rebase轮次
     * @param newScaleFactor 新的缩放因子
     * @param newTotalSupply 新的总供应量
     */
    event Rebase(uint256 indexed epoch, uint256 newScaleFactor, uint256 newTotalSupply);

    /**
     * @dev 构造函数
     * @notice 初始化代币基本信息和状态变量
     */
    constructor() ERC20("DeflationToken", "DFL") Ownable(msg.sender) {
        _baseTotalSupply = 100_000_000 * 10**18;
        _scaleFactor = PRECISION;
        _lastRebaseTime = block.timestamp;
        _rawBalances[msg.sender] = _baseTotalSupply;
        _epoch = 0;
    }

    /**
     * @dev 执行rebase操作，减少总供应量
     * @notice 只能在距离上次rebase满365天后执行
     */
    function rebase() external nonReentrant {
        require(
            block.timestamp >= _lastRebaseTime + YEAR_IN_SECONDS,
            "DeflationToken: rebase too early"
        );
        
        // 更新缩放因子 (减少1%)
        _scaleFactor = (_scaleFactor * DEFLATION_RATE) / DEFLATION_BASE;
        
        // 更新最后rebase时间
        _lastRebaseTime = block.timestamp;
        
        // 增加epoch计数
        _epoch++;
        
        // 触发Rebase事件
        emit Rebase(_epoch, _scaleFactor, totalSupply());
    }

    /**
     * @dev 返回账户的显示余额
     * @param account 账户地址
     * @return 显示余额
     */
    function balanceOf(address account) public view override returns (uint256) {
        return (_rawBalances[account] * _scaleFactor) / PRECISION;
    }

    /**
     * @dev 返回当前总供应量
     * @return 当前总供应量
     */
    function totalSupply() public view override returns (uint256) {
        return (_baseTotalSupply * _scaleFactor) / PRECISION;
    }

    /**
     * @dev 转账功能
     * @param to 接收地址
     * @param value 转账金额(显示金额)
     * @return 是否成功
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        address owner = _msgSender();
        _transferInternal(owner, to, value);
        return true;
    }

    /**
     * @dev 授权转账功能
     * @param from 发送地址
     * @param to 接收地址
     * @param value 转账金额(显示金额)
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowanceInternal(from, spender, value);
        _transferInternal(from, to, value);
        return true;
    }

    /**
     * @dev 授权功能
     * @param spender 被授权地址
     * @param value 授权金额(显示金额)
     * @return 是否成功
     */
    function approve(address spender, uint256 value) public override returns (bool) {
        address owner = _msgSender();
        _approveInternal(owner, spender, value);
        return true;
    }

    /**
     * @dev 查询授权金额
     * @param owner 授权者地址
     * @param spender 被授权者地址
     * @return 授权的显示金额
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return (_rawAllowances[owner][spender] * _scaleFactor) / PRECISION;
    }

    /**
     * @dev 内部转账函数
     * @param from 发送地址
     * @param to 接收地址
     * @param value 转账金额(显示金额)
     */
    function _transferInternal(address from, address to, uint256 value) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        // 将显示金额转换为原始金额
        uint256 rawValue = (value * PRECISION) / _scaleFactor;
        require(rawValue > 0 || value == 0, "DeflationToken: transfer amount too small");
        
        uint256 fromBalance = _rawBalances[from];
        require(fromBalance >= rawValue, "ERC20: transfer amount exceeds balance");
        
        unchecked {
            _rawBalances[from] = fromBalance - rawValue;
            _rawBalances[to] += rawValue;
        }
        
        emit Transfer(from, to, value);
    }

    /**
     * @dev 内部授权函数
     * @param owner 授权者地址
     * @param spender 被授权者地址
     * @param value 授权金额(显示金额)
     */
    function _approveInternal(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        // 将显示金额转换为原始金额存储
        uint256 rawValue = (value * PRECISION) / _scaleFactor;
        _rawAllowances[owner][spender] = rawValue;
        
        emit Approval(owner, spender, value);
    }

    /**
     * @dev 内部消费授权函数
     * @param owner 授权者地址
     * @param spender 被授权者地址
     * @param value 消费金额(显示金额)
     */
    function _spendAllowanceInternal(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            unchecked {
                _approveInternal(owner, spender, currentAllowance - value);
            }
        }
    }

    // ========== 查询函数 ==========

    /**
     * @dev 获取当前缩放因子
     * @return 当前缩放因子
     */
    function scaleFactor() external view returns (uint256) {
        return _scaleFactor;
    }

    /**
     * @dev 获取基础总供应量
     * @return 基础总供应量
     */
    function baseTotalSupply() external view returns (uint256) {
        return _baseTotalSupply;
    }

    /**
     * @dev 获取上次rebase时间
     * @return 上次rebase时间戳
     */
    function lastRebaseTime() external view returns (uint256) {
        return _lastRebaseTime;
    }

    /**
     * @dev 获取当前epoch
     * @return 当前epoch
     */
    function epoch() external view returns (uint256) {
        return _epoch;
    }

    /**
     * @dev 获取账户的原始余额
     * @param account 账户地址
     * @return 原始余额
     */
    function rawBalanceOf(address account) external view returns (uint256) {
        return _rawBalances[account];
    }

    /**
     * @dev 检查是否可以执行rebase
     * @return 是否可以执行rebase
     */
    function canRebase() external view returns (bool) {
        return block.timestamp >= _lastRebaseTime + YEAR_IN_SECONDS;
    }

    /**
     * @dev 获取距离下次rebase的剩余时间
     * @return 剩余秒数
     */
    function timeToNextRebase() external view returns (uint256) {
        uint256 nextRebaseTime = _lastRebaseTime + YEAR_IN_SECONDS;
        if (block.timestamp >= nextRebaseTime) {
            return 0;
        }
        return nextRebaseTime - block.timestamp;
    }
}