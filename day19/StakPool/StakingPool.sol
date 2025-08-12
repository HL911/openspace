// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./IStakingPool.sol";
import "./ILendingMarket.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StakingPool 质押池合约
 * @dev 实现 ETH 质押和 KK Token 奖励分配，集成借贷市场赚取额外利息
 */
contract StakingPool is IStaking, ReentrancyGuard, Ownable {
    IToken public immutable kkToken;
    ILendingMarket public lendingMarket;
    
    // 每个区块产出 10 个 KK Token
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    
    // 质押信息
    struct StakeInfo {
        uint256 amount;           // 质押数量
        uint256 rewardDebt;       // 已计算的奖励债务
        uint256 lastStakeBlock;   // 最后质押区块
    }
    
    mapping(address => StakeInfo) public stakeInfo;
    
    uint256 public totalStaked;              // 总质押数量
    uint256 public accRewardPerShare;        // 累积每股奖励
    uint256 public lastRewardBlock;          // 最后奖励区块
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 reward);
    event LendingMarketSet(address indexed lendingMarket);

    constructor(address _kkToken) Ownable(msg.sender) {
        kkToken = IToken(_kkToken);
        lastRewardBlock = block.number;
    }

    /**
     * @dev 设置借贷市场地址
     * @param _lendingMarket 借贷市场合约地址
     */
    function setLendingMarket(address _lendingMarket) external onlyOwner {
        lendingMarket = ILendingMarket(_lendingMarket);
        emit LendingMarketSet(_lendingMarket);
    }

    /**
     * @dev 质押 ETH 到合约
     */
    function stake() external payable override nonReentrant {
        require(msg.value > 0, "Stake amount must be greater than 0");
        
        updatePool();
        
        StakeInfo storage user = stakeInfo[msg.sender];
        
        // 如果用户已有质押，先领取之前的奖励
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                kkToken.mint(msg.sender, pending);
                emit Claimed(msg.sender, pending);
            }
        }
        
        // 更新用户质押信息
        user.amount += msg.value;
        user.lastStakeBlock = block.number;
        totalStaked += msg.value;
        
        // 计算新的奖励债务
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        
        // 如果设置了借贷市场，将 ETH 存入借贷市场赚取利息
        if (address(lendingMarket) != address(0)) {
            lendingMarket.deposit{value: msg.value}();
        }
        
        emit Staked(msg.sender, msg.value);
    }

    /**
     * @dev 赎回质押的 ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external override nonReentrant {
        StakeInfo storage user = stakeInfo[msg.sender];
        require(user.amount >= amount, "Insufficient staked amount");
        require(amount > 0, "Unstake amount must be greater than 0");
        
        updatePool();
        
        // 计算并发放待领取的奖励
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            kkToken.mint(msg.sender, pending);
            emit Claimed(msg.sender, pending);
        }
        
        // 更新用户质押信息
        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        
        // 从借贷市场提取 ETH（如果有的话）
        if (address(lendingMarket) != address(0)) {
            lendingMarket.withdraw(amount);
        }
        
        // 转账 ETH 给用户
        payable(msg.sender).transfer(amount);
        
        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev 领取 KK Token 收益
     */
    function claim() external override nonReentrant {
        updatePool();
        
        StakeInfo storage user = stakeInfo[msg.sender];
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
        
        require(pending > 0, "No pending rewards");
        
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        kkToken.mint(msg.sender, pending);
        
        emit Claimed(msg.sender, pending);
    }

    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view override returns (uint256) {
        return stakeInfo[account].amount;
    }

    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
    function earned(address account) external view override returns (uint256) {
        StakeInfo storage user = stakeInfo[account];
        uint256 _accRewardPerShare = accRewardPerShare;
        
        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 blocksPassed = block.number - lastRewardBlock;
            uint256 reward = blocksPassed * REWARD_PER_BLOCK;
            _accRewardPerShare += (reward * 1e12) / totalStaked;
        }
        
        return (user.amount * _accRewardPerShare) / 1e12 - user.rewardDebt;
    }

    /**
     * @dev 更新奖励池
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;  // 如果当前区块 <= 上次更新区块，无需更新
        }
        
        if (totalStaked == 0) {
            lastRewardBlock = block.number;  // 没有质押时，只更新区块号
            return;
        }
        
        // 计算经过的区块数
        uint256 blocksPassed = block.number - lastRewardBlock;
        // 计算总奖励 = 区块数 × 每区块奖励
        uint256 reward = blocksPassed * REWARD_PER_BLOCK;
        
        // 更新累积每股奖励 = 累积每股奖励 + (总奖励 × 精度) / 总质押量
        accRewardPerShare += (reward * 1e12) / totalStaked;
        lastRewardBlock = block.number;
    }

    /**
     * @dev 获取借贷市场中的总余额（包括利息）
     * @return 借贷市场中的总余额
     */
    function getLendingBalance() external view returns (uint256) {
        if (address(lendingMarket) == address(0)) {
            return 0;
        }
        return lendingMarket.balanceOf(address(this));
    }

    /**
     * @dev 获取借贷市场中赚取的利息
     * @return 赚取的利息
     */
    function getLendingInterest() external view returns (uint256) {
        if (address(lendingMarket) == address(0)) {
            return 0;
        }
        return lendingMarket.earnedInterest(address(this));
    }

    /**
     * @dev 紧急提取函数，只有 owner 可以调用
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev 接收 ETH
     */
    receive() external payable {}
}