// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CallOption.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title InteractCallOption
 * @dev 与已部署的看涨期权合约交互的脚本
 */
contract InteractCallOption is Script {
    CallOption public callOption;
    IERC20 public usdt;
    
    function setUp() public {
        // 从环境变量获取合约地址
        address callOptionAddress = vm.envAddress("CALL_OPTION_ADDRESS");
        callOption = CallOption(payable(callOptionAddress));
        usdt = callOption.usdt();
        
        console.log("Interacting with CallOption at:", address(callOption));
        console.log("USDT Address:", address(usdt));
    }
    
    /**
     * @dev 项目方存款ETH并铸造期权Token
     */
    function deposit() external {
        uint256 depositAmount = vm.envUint("DEPOSIT_AMOUNT"); // 以wei为单位
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Depositing", depositAmount / 1e18, "ETH...");
        
        vm.startBroadcast(privateKey);
        
        callOption.deposit{value: depositAmount}();
        
        vm.stopBroadcast();
        
        console.log("Deposit successful!");
        console.log("Total Locked:", callOption.totalLocked() / 1e18, "ETH");
        console.log("Option Tokens Minted:", callOption.balanceOf(vm.addr(privateKey)) / 1e18);
    }
    
    /**
     * @dev 用户行权期权
     */
    function exercise() external {
        uint256 optionAmount = vm.envUint("OPTION_AMOUNT"); // 以wei为单位
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(privateKey);
        
        console.log("User:", user);
        console.log("Exercising", optionAmount / 1e18, "option tokens...");
        
        // 检查用户余额
        uint256 userOptionBalance = callOption.balanceOf(user);
        uint256 userUSDTBalance = usdt.balanceOf(user);
        uint256 usdtRequired = optionAmount * callOption.strikePrice() / 1e18;
        
        console.log("User Option Balance:", userOptionBalance / 1e18);
        console.log("User USDT Balance:", userUSDTBalance / 1e18);
        console.log("USDT Required:", usdtRequired / 1e18);
        
        require(userOptionBalance >= optionAmount, "Insufficient option tokens");
        require(userUSDTBalance >= usdtRequired, "Insufficient USDT balance");
        
        vm.startBroadcast(privateKey);
        
        // 授权USDT
        usdt.approve(address(callOption), usdtRequired);
        
        // 行权
        callOption.exercise(optionAmount);
        
        vm.stopBroadcast();
        
        console.log("Exercise successful!");
        console.log("User received", optionAmount / 1e18, "ETH");
    }
    
    /**
     * @dev 过期清算
     */
    function expire() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Expiring contract...");
        console.log("Current time:", block.timestamp);
        console.log("Expiration time:", callOption.expiration());
        
        require(block.timestamp > callOption.expiration(), "Contract has not expired yet");
        
        vm.startBroadcast(privateKey);
        
        callOption.expire();
        
        vm.stopBroadcast();
        
        console.log("Contract expired successfully!");
    }
    
    /**
     * @dev 查看合约状态
     */
    function status() external view {
        console.log("\n=== CallOption Contract Status ===");
        console.log("Contract Address:", address(callOption));
        console.log("Owner:", callOption.owner());
        console.log("Token Name:", callOption.name());
        console.log("Token Symbol:", callOption.symbol());
        console.log("Strike Price:", callOption.strikePrice() / 1e18, "USDT per ETH");
        console.log("Expiration:", callOption.expiration());
        console.log("Current Time:", block.timestamp);
        console.log("Time to Expiration:", callOption.timeToExpiration(), "seconds");
        console.log("Total Locked ETH:", callOption.totalLocked() / 1e18);
        console.log("Contract ETH Balance:", address(callOption).balance / 1e18);
        console.log("Contract USDT Balance:", usdt.balanceOf(address(callOption)) / 1e18);
        console.log("Total Supply:", callOption.totalSupply() / 1e18);
        console.log("Expired:", callOption.expired());
        
        // 期权分析
        console.log("\n=== Option Analysis ===");
        uint256[] memory ethPrices = new uint256[](3);
        ethPrices[0] = 3000 * 1e18; // 价外
        ethPrices[1] = 3200 * 1e18; // 平价
        ethPrices[2] = 3500 * 1e18; // 价内
        
        for (uint i = 0; i < ethPrices.length; i++) {
            uint256 price = ethPrices[i];
            console.log("ETH Price:", price / 1e18, "USDT");
            console.log("  In the Money:", callOption.isInTheMoney(price));
            console.log("  Intrinsic Value:", callOption.intrinsicValue(price) / 1e18, "USDT");
        }
    }
    
    /**
     * @dev 转移期权Token
     */
    function transferTokens() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address to = vm.envAddress("TRANSFER_TO");
        uint256 amount = vm.envUint("TRANSFER_AMOUNT");
        
        console.log("Transferring", amount / 1e18, "option tokens to", to);
        
        vm.startBroadcast(privateKey);
        
        callOption.transfer(to, amount);
        
        vm.stopBroadcast();
        
        console.log("Transfer successful!");
    }
    
    /**
     * @dev 添加流动性
     */
    function addLiquidity() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        uint256 ethAmount = vm.envUint("ETH_AMOUNT");
        
        console.log("Adding ETH liquidity:");
        console.log("ETH Amount:", ethAmount / 1e18);
        
        vm.startBroadcast(privateKey);
        
        // 添加ETH流动性
        callOption.addLiquidity{value: ethAmount}();
        
        vm.stopBroadcast();
        
        console.log("ETH liquidity added successfully!");
        console.log("Total locked ETH:", callOption.totalLocked() / 1e18);
    }
    
    /**
     * @dev 紧急提取
     */
    function emergencyWithdraw() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Performing emergency withdraw...");
        
        vm.startBroadcast(privateKey);
        
        callOption.emergencyWithdraw();
        
        vm.stopBroadcast();
        
        console.log("Emergency withdraw completed!");
    }
    
    /**
     * @dev 批量查看用户信息
     */
    function userInfo() external view {
        address[] memory users = new address[](3);
        users[0] = vm.envAddress("USER1");
        users[1] = vm.envAddress("USER2");
        users[2] = vm.envAddress("USER3");
        
        console.log("\n=== User Information ===");
        
        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            if (user == address(0)) continue;
            
            console.log("User:", user);
            console.log("  ETH Balance:", user.balance / 1e18);
            console.log("  USDT Balance:", usdt.balanceOf(user) / 1e18);
            console.log("  Option Token Balance:", callOption.balanceOf(user) / 1e18);
            console.log("  USDT Allowance:", usdt.allowance(user, address(callOption)) / 1e18);
        }
    }
    
    /**
     * @dev 模拟完整的期权生命周期
     */
    function simulateLifecycle() external {
        console.log("\n=== Simulating Option Lifecycle ===");
        
        // 1. 查看初始状态
        console.log("1. Initial State:");
        this.status();
        
        // 2. 存款（如果是所有者）
        if (callOption.owner() == vm.addr(vm.envUint("PRIVATE_KEY"))) {
            console.log("\n2. Depositing ETH...");
            this.deposit();
        }
        
        // 3. 查看存款后状态
        console.log("\n3. After Deposit:");
        this.status();
        
        // 4. 模拟时间推进
        console.log("\n4. Time progression simulation:");
        uint256 timeSteps = 5;
        uint256 timeInterval = callOption.timeToExpiration() / timeSteps;
        
        for (uint i = 1; i <= timeSteps; i++) {
            uint256 newTime = block.timestamp + (timeInterval * i);
            console.log("Time step", i, "- Timestamp:", newTime);
            
            if (newTime <= callOption.expiration()) {
                console.log("  Status: Active");
                console.log("  Time to expiration:", callOption.expiration() - newTime, "seconds");
            } else {
                console.log("  Status: Expired");
            }
        }
    }
}