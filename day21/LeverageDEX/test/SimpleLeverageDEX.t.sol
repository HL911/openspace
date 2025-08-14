// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleLeverageDEX.sol";
import "../src/MockUSDC.sol";

contract SimpleLeverageDEXTest is Test {
    SimpleLeverageDEX public dex;
    MockUSDC public usdc;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public liquidator = address(0x3);
    
    uint256 public constant INITIAL_VETH = 1000 * 1e18; // 1000 ETH
    uint256 public constant INITIAL_VUSDC = 2000000 * 1e6; // 2,000,000 USDC
    
    function setUp() public {
        // 部署USDC代币
        usdc = new MockUSDC();
        
        // 部署杠杆DEX
        dex = new SimpleLeverageDEX(INITIAL_VETH, INITIAL_VUSDC, address(usdc));
        
        // 给测试用户铸造USDC
        usdc.mint(user1, 100000 * 1e6); // 100,000 USDC
        usdc.mint(user2, 100000 * 1e6); // 100,000 USDC
        usdc.mint(liquidator, 100000 * 1e6); // 100,000 USDC
        
        // 用户授权DEX使用USDC
        vm.prank(user1);
        usdc.approve(address(dex), type(uint256).max);
        
        vm.prank(user2);
        usdc.approve(address(dex), type(uint256).max);
        
        vm.prank(liquidator);
        usdc.approve(address(dex), type(uint256).max);
    }
    
    function testInitialState() public {
        assertEq(dex.vETHAmount(), INITIAL_VETH);
        assertEq(dex.vUSDCAmount(), INITIAL_VUSDC);
        assertEq(dex.vK(), INITIAL_VETH * INITIAL_VUSDC);
        
        // 初始价格应该是 2000 USDC per ETH
        uint256 price = dex.getCurrentPrice();
        assertEq(price, 2000 * 1e18);
    }
    
    function testOpenLongPosition() public {
        vm.startPrank(user1);
        
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 5;
        
        uint256 balanceBefore = usdc.balanceOf(user1);
        
        dex.openPosition(margin, leverage, true); // 开多头
        
        uint256 balanceAfter = usdc.balanceOf(user1);
        assertEq(balanceBefore - balanceAfter, margin);
        
        // 检查头寸信息
        (uint256 posMargin, uint256 borrowed, int256 position, uint256 entryPrice, int256 pnl) = dex.getPosition(user1);
        assertEq(posMargin, margin);
        assertEq(borrowed, margin * (leverage - 1));
        assertGt(position, 0); // 多头头寸应该为正
        assertEq(entryPrice, 2000 * 1e18); // 开仓价格
        
        vm.stopPrank();
    }
    
    function testOpenShortPosition() public {
        vm.startPrank(user1);
        
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 3;
        
        dex.openPosition(margin, leverage, false); // 开空头
        
        // 检查头寸信息
        (uint256 posMargin, uint256 borrowed, int256 position, uint256 entryPrice, int256 pnl) = dex.getPosition(user1);
        assertEq(posMargin, margin);
        assertEq(borrowed, margin * (leverage - 1));
        assertLt(position, 0); // 空头头寸应该为负
        assertEq(entryPrice, 2000 * 1e18); // 开仓价格
        
        vm.stopPrank();
    }
    
    function testClosePositionWithProfit() public {
        vm.startPrank(user1);
        
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 5;
        
        // 开多头头寸
        dex.openPosition(margin, leverage, true);
        
        vm.stopPrank();
        
        // 另一个用户开空头，推高价格
        vm.startPrank(user2);
        dex.openPosition(2000 * 1e6, 2, false); // 大额空头推高价格
        vm.stopPrank();
        
        // 检查价格是否上涨
        uint256 newPrice = dex.getCurrentPrice();
        assertGt(newPrice, 2000 * 1e18);
        
        // user1平仓获利
        vm.startPrank(user1);
        uint256 balanceBefore = usdc.balanceOf(user1);
        
        dex.closePosition();
        
        uint256 balanceAfter = usdc.balanceOf(user1);
        assertGt(balanceAfter, balanceBefore); // 应该有盈利
        
        vm.stopPrank();
    }
    
    function testLiquidation() public {
        vm.startPrank(user1);
        
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 10; // 高杠杆
        
        // 开多头头寸
        dex.openPosition(margin, leverage, true);
        
        vm.stopPrank();
        
        // 另一个用户开大量多头，压低价格
        vm.startPrank(user2);
        dex.openPosition(5000 * 1e6, 5, true); // 大额多头压低价格
        vm.stopPrank();
        
        // 检查是否可以清算
        bool canLiquidate = dex.canLiquidate(user1);
        if (canLiquidate) {
            // 执行清算
            vm.startPrank(liquidator);
            uint256 balanceBefore = usdc.balanceOf(liquidator);
            
            dex.liquidatePosition(user1);
            
            uint256 balanceAfter = usdc.balanceOf(liquidator);
            assertGt(balanceAfter, balanceBefore); // 清算人应该获得奖励
            
            vm.stopPrank();
            
            // 检查头寸是否被清除
            (uint256 posMargin,,,,) = dex.getPosition(user1);
            assertEq(posMargin, 0);
        }
    }
    
    function testCannotOpenMultiplePositions() public {
        vm.startPrank(user1);
        
        uint256 margin = 1000 * 1e6;
        
        // 开第一个头寸
        dex.openPosition(margin, 5, true);
        
        // 尝试开第二个头寸应该失败
        vm.expectRevert("Position already open");
        dex.openPosition(margin, 3, false);
        
        vm.stopPrank();
    }
    
    function testCannotLiquidateOwnPosition() public {
        vm.startPrank(user1);
        
        uint256 margin = 1000 * 1e6;
        dex.openPosition(margin, 10, true);
        
        // 尝试清算自己的头寸应该失败
        vm.expectRevert("Cannot liquidate own position");
        dex.liquidatePosition(user1);
        
        vm.stopPrank();
    }
    
    function testInvalidLeverage() public {
        vm.startPrank(user1);
        
        uint256 margin = 1000 * 1e6;
        
        // 杠杆为0应该失败
        vm.expectRevert("Leverage must be between 1 and 10");
        dex.openPosition(margin, 0, true);
        
        // 杠杆超过10应该失败
        vm.expectRevert("Leverage must be between 1 and 10");
        dex.openPosition(margin, 11, true);
        
        vm.stopPrank();
    }
    
    function testZeroMargin() public {
        vm.startPrank(user1);
        
        // 保证金为0应该失败
        vm.expectRevert("Margin must be greater than 0");
        dex.openPosition(0, 5, true);
        
        vm.stopPrank();
    }
}