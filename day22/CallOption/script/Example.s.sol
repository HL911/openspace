// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CallOption.sol";
import "../script/DeployCallOption.s.sol";

/**
 * @title Example
 * @dev 演示期权合约完整使用流程的脚本
 */
contract Example is Script {
    CallOption public callOption;
    MockUSDT public usdt;
    
    address public projectOwner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public user2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    function run() external {
        console.log(unicode"\n=== ETH 看涨期权合约演示 ===");
        
        // 给账户分配ETH
        vm.deal(projectOwner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        vm.startBroadcast(projectOwner);
        
        // 1. 部署Mock USDT
        console.log(unicode"\n1. 部署 Mock USDT...");
        usdt = new MockUSDT();
        console.log(unicode"USDT 地址:", address(usdt));
        
        // 给用户分配USDT
        usdt.mint(user1, 50000 * 10**18); // 5万USDT
        usdt.mint(user2, 50000 * 10**18); // 5万USDT
        console.log(unicode"已为用户分配 USDT");
        
        // 2. 部署期权合约
        console.log(unicode"\n2. 部署期权合约...");
        uint256 strikePrice = 3200 * 10**18; // 3200 USDT per ETH
        uint256 expiration = block.timestamp + 30 days; // 30天后到期
        uint256 optionPrice = 100 * 10**18; // 100 USDT per option
        
        callOption = new CallOption(strikePrice, expiration, optionPrice, address(usdt));
        console.log(unicode"期权合约地址:", address(callOption));
        console.log(unicode"行权价格:", strikePrice / 10**18, "USDT per ETH");
        console.log(unicode"期权费用:", optionPrice / 10**18, "USDT per option");
        console.log(unicode"到期时间:", expiration);
        
        // 3. 项目方存入ETH作为期权标的资产
        console.log(unicode"\n3. 项目方存入 ETH...");
        uint256 depositAmount = 10 ether;
        callOption.deposit{value: depositAmount}();
        console.log(unicode"存入 ETH:", depositAmount / 1e18);
        console.log(unicode"合约ETH余额:", address(callOption).balance / 1e18, "ETH");
        
        vm.stopBroadcast();
        
        // 4. 用户购买期权
        console.log(unicode"\n4. 用户购买期权...");
        
        // 用户1购买期权
        vm.startBroadcast(user1);
        uint256 user1OptionAmount = 3 ether;
        uint256 user1OptionFee = user1OptionAmount * optionPrice / 1 ether;
        usdt.approve(address(callOption), user1OptionFee);
        callOption.buyOption(user1OptionAmount);
        console.log(unicode"用户1购买期权:", user1OptionAmount / 1e18, "ETH");
        console.log(unicode"用户1支付期权费:", user1OptionFee / 1e18, "USDT");
        vm.stopBroadcast();
        
        // 用户2购买期权
        vm.startBroadcast(user2);
        uint256 user2OptionAmount = 2 ether;
        uint256 user2OptionFee = user2OptionAmount * optionPrice / 1 ether;
        usdt.approve(address(callOption), user2OptionFee);
        callOption.buyOption(user2OptionAmount);
        console.log(unicode"用户2购买期权:", user2OptionAmount / 1e18, "ETH");
        console.log(unicode"用户2支付期权费:", user2OptionFee / 1e18, "USDT");
        vm.stopBroadcast();
        
        console.log(unicode"用户1 期权余额:", callOption.balanceOf(user1) / 1e18);
        console.log(unicode"用户2 期权余额:", callOption.balanceOf(user2) / 1e18);
        
        // 5. 用户1行权
        console.log(unicode"\n5. 用户1 行权...");
        uint256 exerciseAmount = 2 ether;
        uint256 usdtRequired = exerciseAmount * strikePrice / 1e18;
        
        vm.startBroadcast(user1);
        
        console.log(unicode"行权前 ETH 余额:", user1.balance / 1e18);
        console.log(unicode"行权前 USDT 余额:", usdt.balanceOf(user1) / 1e18);
        console.log(unicode"需要支付 USDT:", usdtRequired / 1e18);
        
        // 授权USDT
        usdt.approve(address(callOption), usdtRequired);
        
        // 行权
        callOption.exercise(exerciseAmount);
        
        console.log(unicode"行权后 ETH 余额:", user1.balance / 1e18);
        console.log(unicode"行权后 USDT 余额:", usdt.balanceOf(user1) / 1e18);
        console.log(unicode"剩余期权 Token:", callOption.balanceOf(user1) / 1e18);
        
        vm.stopBroadcast();
        
        // 6. 查看合约状态
        console.log(unicode"\n6. 合约当前状态:");
        console.log(unicode"合约 ETH 余额:", address(callOption).balance / 1e18);
        console.log(unicode"合约 USDT 余额:", usdt.balanceOf(address(callOption)) / 1e18);
        console.log(unicode"总锁定 ETH:", callOption.totalLocked() / 1e18);
        console.log(unicode"期权 Token 总供应量:", callOption.totalSupply() / 1e18);
        
        // 7. 期权分析
        console.log(unicode"\n7. 期权分析:");
        uint256[] memory ethPrices = new uint256[](4);
        ethPrices[0] = 3000 * 1e18; // 价外
        ethPrices[1] = 3200 * 1e18; // 平价
        ethPrices[2] = 3500 * 1e18; // 价内
        ethPrices[3] = 4000 * 1e18; // 深度价内
        
        for (uint i = 0; i < ethPrices.length; i++) {
            uint256 price = ethPrices[i];
            console.log(unicode"ETH 价格:", price / 1e18, "USDT");
            console.log(unicode"  价内状态:", callOption.isInTheMoney(price));
            console.log(unicode"  内在价值:", callOption.intrinsicValue(price) / 1e18, "USDT");
        }
        
        // 8. 时间信息
        console.log(unicode"\n8. 时间信息:");
        console.log(unicode"当前时间:", block.timestamp);
        console.log(unicode"到期时间:", callOption.expiration());
        console.log(unicode"剩余时间:", callOption.timeToExpiration(), unicode"秒");
        console.log(unicode"剩余天数:", callOption.timeToExpiration() / 86400, unicode"天");
        
        console.log(unicode"\n=== 演示完成 ===");
        console.log(unicode"\n提示:");
        console.log(unicode"- 用户可以继续行权直到到期");
        console.log(unicode"- 项目方可以在到期后调用 expire() 回收剩余 ETH");
        console.log(unicode"- 期权 Token 可以在二级市场交易");
        console.log(unicode"- 合约包含完整的安全机制和紧急功能");
    }
    
    /**
     * @dev 演示过期清算流程
     */
    function demonstrateExpiration() external {
        // 需要先运行主演示
        require(address(callOption) != address(0), "Please run main demo first");
        
        console.log(unicode"\n=== 过期清算演示 ===");
        
        // 快进到过期后
        vm.warp(callOption.expiration() + 1);
        console.log(unicode"时间已快进到过期后");
        
        vm.startBroadcast(projectOwner);
        
        uint256 ownerETHBefore = projectOwner.balance;
        uint256 contractETHBefore = address(callOption).balance;
        
        console.log(unicode"清算前项目方 ETH 余额:", ownerETHBefore / 1e18);
        console.log(unicode"清算前合约 ETH 余额:", contractETHBefore / 1e18);
        
        // 执行过期清算
        callOption.expire();
        
        console.log(unicode"清算后项目方 ETH 余额:", projectOwner.balance / 1e18);
        console.log(unicode"清算后合约 ETH 余额:", address(callOption).balance / 1e18);
        console.log(unicode"回收的 ETH:", (projectOwner.balance - ownerETHBefore) / 1e18);
        console.log(unicode"合约已标记为过期:", callOption.expired());
        
        vm.stopBroadcast();
        
        console.log(unicode"\n=== 过期清算完成 ===");
    }
}