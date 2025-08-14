// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/DeflationToken.sol";

/**
 * @title DeployDeflationToken
 * @dev 部署通缩代币的脚本
 */
contract DeployDeflationToken is Script {
    function run() external {
        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署合约
        DeflationToken token = new DeflationToken();
        
        // 停止广播
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("DeflationToken deployed at:", address(token));
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Initial Total Supply:", token.totalSupply());
        console.log("Deployer Balance:", token.balanceOf(vm.addr(deployerPrivateKey)));
        console.log("Scale Factor:", token.scaleFactor());
        console.log("Last Rebase Time:", token.lastRebaseTime());
        console.log("Current Epoch:", token.epoch());
        console.log("Can Rebase:", token.canRebase());
        console.log("Time to Next Rebase (seconds):", token.timeToNextRebase());
    }
}

/**
 * @title DeployDeflationTokenLocal
 * @dev 本地测试网部署脚本（不需要私钥）
 */
contract DeployDeflationTokenLocal is Script {
    function run() external {
        // 开始广播交易（使用默认账户）
        vm.startBroadcast();
        
        // 部署合约
        DeflationToken token = new DeflationToken();
        
        // 停止广播
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("=== DeflationToken Deployment Info ===");
        console.log("Contract Address:", address(token));
        console.log("Token Name:", token.name());
        console.log("Token Symbol:", token.symbol());
        console.log("Token Decimals:", token.decimals());
        console.log("Initial Total Supply:", token.totalSupply());
        console.log("Base Total Supply:", token.baseTotalSupply());
        console.log("Deployer Balance:", token.balanceOf(msg.sender));
        console.log("Scale Factor:", token.scaleFactor());
        console.log("Last Rebase Time:", token.lastRebaseTime());
        console.log("Current Epoch:", token.epoch());
        console.log("Can Rebase:", token.canRebase());
        console.log("Time to Next Rebase (seconds):", token.timeToNextRebase());
        console.log("Year in Seconds:", token.YEAR_IN_SECONDS());
        console.log("Deflation Rate:", token.DEFLATION_RATE());
        console.log("Precision:", token.PRECISION());
        console.log("========================================");
    }
}