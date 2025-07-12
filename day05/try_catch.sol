// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 一个可能失败的简单合约
contract SimpleMath {
    // 可能失败的计算函数
    function divide(uint256 a, uint256 b) external pure returns (uint256) {
        require(b != 0, "Cannot divide by zero");
        return a / b;
    }
    
    // 可能触发 assert 的函数
    function checkPositive(int256 number) external pure returns (bool) {
        assert(number >= 0);
        return true;
    }
}

// 主合约，演示 try-catch 用法
contract TryCatchExample {
    event Log(string message);
    
    SimpleMath public mathContract;
    
    constructor() {
        mathContract = new SimpleMath();
    }
    
    // 1. 基本 try-catch 示例
    function safeDivide(uint256 a, uint256 b) external returns (uint256) {
        try mathContract.divide(a, b) returns (uint256 result) {
            // 如果调用成功，执行这里的代码
            emit Log("Division successful");
            return result;
        } catch Error(string memory reason) {
            // 捕获 revert("reason") 和 require(false, "reason") 抛出的错误
            emit Log(string(abi.encodePacked("Error: ", reason)));
            return 0;
        } catch (bytes memory) {
            // 捕获其他类型的错误
            emit Log("Unknown error occurred");
            return 0;
        }
    }
    
    // 2. 捕获 assert 错误
    function testAssert(int256 number) external returns (bool) {
        try mathContract.checkPositive(number) returns (bool) {
            emit Log("Number is positive");
            return true;
        } catch (bytes memory) {
            // assert 错误会在这里被捕获
            emit Log("Assertion failed: Number is negative");
            return false;
        }
    }
    
    // 3. 外部调用中的 try-catch
    function callExternal(address contractAddress, bytes calldata data) external {
        (bool success, ) = contractAddress.call(data);
        
        if (!success) {
            emit Log("External call failed");
            // 可以在这里处理失败逻辑
        } else {
            emit Log("External call succeeded");
        }
    }
}
