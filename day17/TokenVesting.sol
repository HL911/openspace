// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenVesting
 * @dev 代币释放合约，实现12个月Cliff期 + 24个月线性释放
 */
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // 事件定义
    event TokensReleased(address token, uint256 amount);
    event VestingRevoked(address token);

    // 受益人地址
    address private _beneficiary;
    
    // 锁定的ERC20代币合约地址
    IERC20 private _token;
    
    // Cliff期结束时间 (部署时间 + 12个月)
    uint256 private _cliff;
    
    // 开始时间 (合约部署时间)
    uint256 private _start;
    
    // 释放期总时长 (24个月)
    uint256 private _duration;
    
    // 是否可撤销
    bool private _revocable;
    
    // 是否已撤销
    bool private _revoked;
    
    // 已释放的代币数量
    uint256 private _released;
    
    // 总锁定代币数量 (100万)
    uint256 private _totalAmount;

    /**
     * @dev 构造函数
     * @param beneficiary_ 受益人地址
     * @param token_ ERC20代币合约地址
     * @param totalAmount_ 总锁定代币数量
     * @param revocable_ 是否可撤销
     */
    constructor(
        address beneficiary_,
        address token_,
        uint256 totalAmount_,
        bool revocable_
    ) Ownable(msg.sender) {
        require(beneficiary_ != address(0), "TokenVesting: beneficiary is the zero address");
        require(token_ != address(0), "TokenVesting: token is the zero address");
        require(totalAmount_ > 0, "TokenVesting: total amount must be greater than 0");

        _beneficiary = beneficiary_;
        _token = IERC20(token_);
        _totalAmount = totalAmount_;
        _revocable = revocable_;
        
        _start = block.timestamp;
        _cliff = _start + 365 days; // 12个月 Cliff期
        _duration = 730 days; // 24个月释放期 (从第13个月开始)
        
        _released = 0;
        _revoked = false;
    }

    /**
     * @dev 获取受益人地址
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @dev 获取代币合约地址
     */
    function token() public view returns (address) {
        return address(_token);
    }

    /**
     * @dev 获取Cliff期结束时间
     */
    function cliff() public view returns (uint256) {
        return _cliff;
    }

    /**
     * @dev 获取开始时间
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @dev 获取释放期总时长
     */
    function duration() public view returns (uint256) {
        return _duration;
    }

    /**
     * @dev 获取是否可撤销
     */
    function revocable() public view returns (bool) {
        return _revocable;
    }

    /**
     * @dev 获取已释放数量
     */
    function released() public view returns (uint256) {
        return _released;
    }

    /**
     * @dev 获取是否已撤销
     */
    function revoked() public view returns (bool) {
        return _revoked;
    }

    /**
     * @dev 获取总锁定数量
     */
    function totalAmount() public view returns (uint256) {
        return _totalAmount;
    }

    /**
     * @dev 计算当前时间点应该释放的代币数量
     */
    function releasableAmount() public view returns (uint256) {
        return _vestedAmount() - _released;
    }

    /**
     * @dev 释放已解锁的代币给受益人
     */
    function release() public nonReentrant {
        uint256 unreleased = releasableAmount();
        require(unreleased > 0, "TokenVesting: no tokens are due");

        _released += unreleased;
        _token.safeTransfer(_beneficiary, unreleased);

        emit TokensReleased(address(_token), unreleased);
    }

    /**
     * @dev 撤销释放计划 (仅owner可调用，且合约必须是可撤销的)
     */
    function revoke() public onlyOwner {
        require(_revocable, "TokenVesting: cannot revoke");
        require(!_revoked, "TokenVesting: token already revoked");

        uint256 balance = _token.balanceOf(address(this));
        uint256 unreleased = releasableAmount();
        uint256 refund = balance - unreleased;

        _revoked = true;

        if (refund > 0) {
            _token.safeTransfer(owner(), refund);
        }

        emit VestingRevoked(address(_token));
    }

    /**
     * @dev 计算在给定时间点已经释放的代币数量
     */
    function _vestedAmount() private view returns (uint256) {
        if (block.timestamp < _cliff) {
            // Cliff期内，没有代币被释放
            return 0;
        } else if (block.timestamp >= _cliff + _duration || _revoked) {
            // 释放期结束或已撤销，返回总数量
            return _totalAmount;
        } else {
            // 在释放期内，线性释放
            // 从Cliff期结束开始计算已过去的时间
            uint256 timeFromCliff = block.timestamp - _cliff;
            // 计算应该释放的比例
            return (_totalAmount * timeFromCliff) / _duration;
        }
    }

    /**
     * @dev 初始化合约，转入代币 (仅owner可调用)
     */
    function initialize() external onlyOwner {
        require(_token.balanceOf(address(this)) == 0, "TokenVesting: already initialized");
        _token.safeTransferFrom(msg.sender, address(this), _totalAmount);
    }

    /**
     * @dev 获取合约当前代币余额
     */
    function getBalance() external view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /**
     * @dev 获取释放进度信息
     */
    function getVestingInfo() external view returns (
        uint256 currentTime,
        uint256 cliffTime,
        uint256 vestingEndTime,
        uint256 totalLocked,
        uint256 alreadyReleased,
        uint256 currentReleasable,
        uint256 remainingLocked,
        bool isCliffPassed,
        bool isFullyVested
    ) {
        currentTime = block.timestamp;
        cliffTime = _cliff;
        vestingEndTime = _cliff + _duration;
        totalLocked = _totalAmount;
        alreadyReleased = _released;
        currentReleasable = releasableAmount();
        remainingLocked = _totalAmount - _released - currentReleasable;
        isCliffPassed = block.timestamp >= _cliff;
        isFullyVested = block.timestamp >= _cliff + _duration;
    }
}
