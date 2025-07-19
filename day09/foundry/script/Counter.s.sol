// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";
import {BaseCript} from "./BaseScript.s.sol";

contract CounterScript is BaseCript {
    Counter public counter;


    function run() public broadcast {
        counter = new Counter();
        saveContract("counter",address(counter));
    }
}
