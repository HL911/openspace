// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// 极简的杠杆 DEX 实现
contract SimpleLeverageDEX is ReentrancyGuard {
    uint public vK;  // 常数乘积 K = vETH * vUSDC
    uint public vETHAmount;  // 虚拟ETH数量
    uint public vUSDCAmount; // 虚拟USDC数量

    IERC20 public USDC;  // USDC代币合约

    // 清算阈值：当亏损达到保证金的80%时可以被清算
    uint public constant LIQUIDATION_THRESHOLD = 80; // 80%
    
    // 清算奖励：清算人获得被清算头寸保证金的5%
    uint public constant LIQUIDATION_REWARD = 5; // 5%

    struct PositionInfo {
        uint256 margin;     // 保证金 (真实的USDC资金)
        uint256 borrowed;   // 借入的资金
        int256 position;    // 虚拟ETH持仓 (正数表示多头，负数表示空头)
        uint256 entryPrice; // 开仓时的价格 (USDC per ETH)
    }
    
    mapping(address => PositionInfo) public positions;

    event PositionOpened(address indexed user, uint256 margin, uint256 leverage, bool isLong, int256 position);
    event PositionClosed(address indexed user, int256 pnl);
    event PositionLiquidated(address indexed user, address indexed liquidator, int256 pnl);

    constructor(uint vEth, uint vUSDC, address _usdc) {
        require(vEth > 0 && vUSDC > 0, "Invalid virtual amounts");
        require(_usdc != address(0), "Invalid USDC address");
        
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;
        USDC = IERC20(_usdc);
    }

    // 获取当前ETH价格 (USDC per ETH，以1e18精度返回)
    function getCurrentPrice() public view returns (uint256) {
        // vUSDCAmount是6位小数，vETHAmount是18位小数
        // 价格 = vUSDCAmount / vETHAmount * 1e12 * 1e18 = vUSDCAmount * 1e30 / vETHAmount
        return vUSDCAmount * 1e30 / vETHAmount;
    }

    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint level, bool long) external nonReentrant {
        require(positions[msg.sender].position == 0, "Position already open");
        require(_margin > 0, "Margin must be greater than 0");
        require(level >= 1 && level <= 10, "Leverage must be between 1 and 10");

        PositionInfo storage pos = positions[msg.sender];

        // 转入保证金
        USDC.transferFrom(msg.sender, address(this), _margin);
        
        uint256 totalAmount = _margin * level;
        uint256 borrowAmount = totalAmount - _margin;

        pos.margin = _margin;
        pos.borrowed = borrowAmount;
        pos.entryPrice = getCurrentPrice();

        if (long) {
            // 做多：用总资金买入虚拟ETH
            // 计算能买到多少虚拟ETH: deltaETH = vETH - vK/(vUSDC + totalAmount)
            uint256 newVUSDC = vUSDCAmount + totalAmount;
            uint256 newVETH = vK / newVUSDC;
            uint256 deltaETH = vETHAmount - newVETH;
            
            pos.position = int256(deltaETH);
            
            // 更新虚拟池状态
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        } else {
            // 做空：卖出虚拟ETH获得USDC
            // 计算需要卖出多少虚拟ETH来获得totalAmount的USDC
            // deltaETH = vK/(vUSDC - totalAmount) - vETH
            require(vUSDCAmount > totalAmount, "Insufficient virtual USDC");
            uint256 newVUSDC = vUSDCAmount - totalAmount;
            uint256 newVETH = vK / newVUSDC;
            uint256 deltaETH = newVETH - vETHAmount;
            
            pos.position = -int256(deltaETH);
            
            // 更新虚拟池状态
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        }

        emit PositionOpened(msg.sender, _margin, level, long, pos.position);
    }

    // 关闭头寸并结算
    function closePosition() external nonReentrant {
        PositionInfo memory pos = positions[msg.sender];
        require(pos.position != 0, "No open position");

        int256 pnl = calculatePnL(msg.sender);
        
        // 更新虚拟池状态 - 反向操作
        if (pos.position > 0) {
            // 平多头：卖出虚拟ETH
            uint256 deltaETH = uint256(pos.position);
            uint256 newVETH = vETHAmount + deltaETH;
            uint256 newVUSDC = vK / newVETH;
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        } else {
            // 平空头：买入虚拟ETH
            uint256 deltaETH = uint256(-pos.position);
            uint256 newVETH = vETHAmount - deltaETH;
            uint256 newVUSDC = vK / newVETH;
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        }

        // 计算最终返还金额
        uint256 finalAmount;
        if (pnl >= 0) {
            finalAmount = pos.margin + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            if (loss >= pos.margin) {
                finalAmount = 0; // 亏光了
            } else {
                finalAmount = pos.margin - loss;
            }
        }

        // 清除头寸
        delete positions[msg.sender];

        // 返还资金
        if (finalAmount > 0) {
            USDC.transfer(msg.sender, finalAmount);
        }

        emit PositionClosed(msg.sender, pnl);
    }

    // 清算头寸
    function liquidatePosition(address _user) external nonReentrant {
        require(_user != msg.sender, "Cannot liquidate own position");
        
        PositionInfo memory position = positions[_user];
        require(position.position != 0, "No open position");
        
        int256 pnl = calculatePnL(_user);
        
        // 检查清算条件：亏损大于保证金的80%
        require(pnl < 0, "Position is profitable, cannot liquidate");
        uint256 loss = uint256(-pnl);
        uint256 liquidationThreshold = position.margin * LIQUIDATION_THRESHOLD / 100;
        require(loss >= liquidationThreshold, "Position not eligible for liquidation");

        // 更新虚拟池状态 - 反向操作
        if (position.position > 0) {
            // 平多头：卖出虚拟ETH
            uint256 deltaETH = uint256(position.position);
            uint256 newVETH = vETHAmount + deltaETH;
            uint256 newVUSDC = vK / newVETH;
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        } else {
            // 平空头：买入虚拟ETH
            uint256 deltaETH = uint256(-position.position);
            uint256 newVETH = vETHAmount - deltaETH;
            uint256 newVUSDC = vK / newVETH;
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        }

        // 计算清算奖励
        uint256 liquidationReward = position.margin * LIQUIDATION_REWARD / 100;
        
        // 清除头寸
        delete positions[_user];
        
        // 给清算人奖励
        if (liquidationReward > 0) {
            USDC.transfer(msg.sender, liquidationReward);
        }

        emit PositionLiquidated(_user, msg.sender, pnl);
    }

    // 计算盈亏：对比当前价格和开仓价格
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory pos = positions[user];
        if (pos.position == 0) {
            return 0;
        }

        uint256 currentPrice = getCurrentPrice();
        uint256 entryPrice = pos.entryPrice;
        
        if (pos.position > 0) {
            // 多头：当前价格 > 开仓价格 = 盈利
            int256 priceDiff = int256(currentPrice) - int256(entryPrice);
            // position是ETH数量(18位小数)，priceDiff是价格差(18位小数)，结果需要转换为USDC(6位小数)
            return priceDiff * pos.position / 1e30;
        } else {
            // 空头：当前价格 < 开仓价格 = 盈利
            int256 priceDiff = int256(entryPrice) - int256(currentPrice);
            // position是ETH数量(18位小数)，priceDiff是价格差(18位小数)，结果需要转换为USDC(6位小数)
            return priceDiff * (-pos.position) / 1e30;
        }
    }

    // 获取用户头寸信息
    function getPosition(address user) external view returns (
        uint256 margin,
        uint256 borrowed,
        int256 position,
        uint256 entryPrice,
        int256 pnl
    ) {
        PositionInfo memory pos = positions[user];
        return (
            pos.margin,
            pos.borrowed,
            pos.position,
            pos.entryPrice,
            calculatePnL(user)
        );
    }

    // 检查头寸是否可以被清算
    function canLiquidate(address user) external view returns (bool) {
        PositionInfo memory position = positions[user];
        if (position.position == 0) {
            return false;
        }
        
        int256 pnl = calculatePnL(user);
        if (pnl >= 0) {
            return false;
        }
        
        uint256 loss = uint256(-pnl);
        uint256 liquidationThreshold = position.margin * LIQUIDATION_THRESHOLD / 100;
        return loss >= liquidationThreshold;
    }
}