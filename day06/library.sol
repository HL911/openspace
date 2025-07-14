// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 1. 库定义
library Math {
    // 内部函数 - 直接内联到调用合约中
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
    
    // 公共函数 - 会被部署为独立的合约
    function subtract(uint256 a, uint256 b) public pure returns (uint256) {
        require(b <= a, "Subtraction underflow");
        return a - b;
    }
    
    
    // 返回多个值
    function divide(uint256 a, uint256 b) internal pure returns (uint256, bool) {
        if (b == 0) return (0, false);
        return (a / b, true);
    }
}

// 2. 使用库的合约
contract Calculator {
    using Math for uint256;  // 将库函数附加到 uint256 类型
    
    uint256 public counter;
    
    // 使用库的加法函数
    function addNumbers(uint256 a, uint256 b) public pure returns (uint256) {
        return a.add(b);  // 使用库函数
    }
    
    // 使用库的减法函数
    function subtractNumbers(uint256 a, uint256 b) public pure returns (uint256) {
        return Math.subtract(a, b);  // 直接调用库函数
    }
    
    
    // 使用返回多个值的库函数
    function safeDivide(uint256 a, uint256 b) public pure returns (uint256, bool) {
        return a.divide(b);
    }
}

// 3. 使用库的数据结构
library ArrayUtils {
    // 从数组中删除指定索引的元素
    function remove(uint256[] storage array, uint256 index) internal {
        require(index < array.length, "Index out of bounds");
        
        for (uint256 i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
    }
    
    // 检查数组中是否包含某个值
    function contains(uint256[] storage array, uint256 value) internal view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        return false;
    }
}

// 4. 使用数组工具库的合约
contract ArrayManager {
    using ArrayUtils for uint256[];
    
    uint256[] public numbers;
    
    function addNumber(uint256 _number) public {
        numbers.push(_number);
    }
    
    function removeNumber(uint256 _index) public {
        numbers.remove(_index);  // 使用库函数
    }
    
    function containsNumber(uint256 _number) public view returns (bool) {
        return numbers.contains(_number);  // 使用库函数
    }
}