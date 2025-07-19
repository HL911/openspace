// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

abstract contract BaseCript is Script {
    address internal deployer;
    address internal user;
    string internal mnemonic;
    uint256 internal deployerPrivateKey;
    string internal constant DEPLOYMENTS_DIR = "./deployments/";

    function setUp() public virtual {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        deployerPrivateKey = privateKey;  // 保存到实例变量
        user = vm.addr(privateKey);
        console.log("user:", user);
    }

    function saveContract(string memory name, address addr) public {
        string memory chainId = vm.toString(block.chainid);
        string memory json1 = "key";
        string memory finalJson = vm.serializeAddress(json1, "address", addr);
        
        // 确保目录存在
        string memory dir = string(abi.encodePacked(DEPLOYMENTS_DIR, chainId, "/"));
        try vm.isDir(dir) returns (bool exists) {
            if (!exists) {
                vm.createDir(dir, true);
            }
        } catch {
            vm.createDir(dir, true);
        }
        
        // 保存到文件
        string memory path = string(abi.encodePacked(dir, name, ".json"));
        vm.writeJson(finalJson, path);
    }

    modifier broadcast() {
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }
}