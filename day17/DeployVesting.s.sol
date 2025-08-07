// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenVesting.sol";
import "../src/MockERC20.sol";

contract DeployVesting is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署参数
        address beneficiary = 0x742d35CC6634c0532925A3B8d0C9e3E0C0E2E7c6; // 示例受益人地址
        uint256 totalAmount = 1_000_000 * 10**18; // 100万代币
        
        console.log("Deploying contracts with deployer:", deployer);
        console.log("Beneficiary:", beneficiary);
        console.log("Total amount:", totalAmount);
        
        // 1. 部署ERC20代币合约
        MockERC20 token = new MockERC20("Vesting Token", "VEST", totalAmount * 2);
        console.log("ERC20 Token deployed at:", address(token));
        
        // 2. 部署Vesting合约
        TokenVesting vesting = new TokenVesting(
            beneficiary,
            address(token),
            totalAmount,
            true // 可撤销
        );
        console.log("TokenVesting deployed at:", address(vesting));
        
        // 3. 授权并初始化Vesting合约
        token.approve(address(vesting), totalAmount);
        vesting.initialize();
        
        console.log("Vesting contract initialized with", totalAmount, "tokens");
        console.log("Cliff period: 12 months from deployment");
        console.log("Vesting period: 24 months linear release starting from month 13");
        
        // 输出重要信息
        console.log("\n=== Deployment Summary ===");
        console.log("ERC20 Token:", address(token));
        console.log("TokenVesting:", address(vesting));
        console.log("Beneficiary:", beneficiary);
        console.log("Total Locked Amount:", totalAmount);
        console.log("Cliff End Time:", vesting.cliff());
        console.log("Vesting End Time:", vesting.cliff() + vesting.duration());
        
        vm.stopBroadcast();
    }
}
