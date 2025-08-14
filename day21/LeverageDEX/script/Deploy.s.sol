// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SimpleLeverageDEX.sol";
import "../src/MockUSDC.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署MockUSDC
        MockUSDC usdc = new MockUSDC();
        console.log("MockUSDC deployed at:", address(usdc));

        // 初始虚拟池参数
        uint256 initialVETH = 1000 * 1e18; // 1000 ETH
        uint256 initialVUSDC = 2000000 * 1e6; // 2,000,000 USDC (价格 = 2000 USDC/ETH)

        // 部署SimpleLeverageDEX
        SimpleLeverageDEX dex = new SimpleLeverageDEX(
            initialVETH,
            initialVUSDC,
            address(usdc)
        );
        console.log("SimpleLeverageDEX deployed at:", address(dex));
        
        // 输出初始状态
        console.log("Initial virtual ETH amount:", dex.vETHAmount());
        console.log("Initial virtual USDC amount:", dex.vUSDCAmount());
        console.log("Initial ETH price (USDC per ETH):", dex.getCurrentPrice() / 1e18);

        vm.stopBroadcast();
    }
}