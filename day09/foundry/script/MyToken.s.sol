// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {BaseCript} from "./BaseScript.s.sol";

contract MyTokenScript is BaseCript {
    MyToken public myToken;
    
    function run() public broadcast {
        console.log("Deploying MyToken contract...");
        myToken = new MyToken("MyToken", "MTK");
        address myTokenAddress = address(myToken);
        
        console.log("MyToken contract deployed successfully!");
        console.log("Contract address:", myTokenAddress);
        
        saveContract("myToken", myTokenAddress);
        
        // Verify deployment
        require(myTokenAddress != address(0), "Deployment failed: invalid address");
        console.log("Contract info saved to deployments directory");
    }
}