// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title 计数器合约
/// @notice 这是一个简单的计数器合约
/// @dev 版本: 1.0.0
contract Counter {
    uint256 public number;

    /// @notice 设置数字
    /// @param newNumber 要设置的新数字
    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    /// @notice 数字加1
    function increment() public {
        number++;
    }
}