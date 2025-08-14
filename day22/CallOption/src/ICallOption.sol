// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ICallOption
 * @dev 看涨期权合约接口
 */
interface ICallOption is IERC20 {
    // 事件定义
    event Deposited(uint256 ethAmount, uint256 totalLocked);
    event OptionPurchased(address indexed buyer, uint256 optionAmount, uint256 optionFee);
    event Exercised(address indexed user, uint256 optionAmount, uint256 usdtCost);
    event Expired(uint256 totalRecovered);
    event LiquidityAdded(uint256 ethAmount, uint256 totalLocked);
    event EmergencyWithdraw(uint256 ethAmount, uint256 usdtAmount);

    // 核心功能函数
    function deposit() external payable;
    function buyOption(uint256 optionAmount) external;
    function exercise(uint256 optionAmount) external;
    function expire() external;
    function addLiquidity() external payable;
    
    // 查询函数
    function strikePrice() external view returns (uint256);
    function expiration() external view returns (uint256);
    function optionPrice() external view returns (uint256);
    function totalLocked() external view returns (uint256);
    function expired() external view returns (bool);
    
    // 期权分析函数
    function intrinsicValue(uint256 ethPrice) external view returns (uint256);
    function isInTheMoney(uint256 ethPrice) external view returns (bool);
    function timeToExpiration() external view returns (uint256);
    
    // 紧急功能
    function emergencyWithdraw() external;
}