// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 基础合约，包含可被重写的函数
contract Animal {
    // 使用 virtual 关键字标记函数，表示它可以被子合约重写
    function makeSound() public pure virtual returns (string memory) {
        return "Some sound";
    }
    
    // 另一个可被重写的函数
    function sleep() public pure virtual returns (string memory) {
        return "Zzz...";
    }
    
    // 不可被重写的函数（没有 virtual 关键字）
    function breathe() public pure returns (string memory) {
        return "Breathing...";
    }
}

// 子合约，继承自 Animal
contract Dog is Animal {
    // 使用 override 关键字重写父合约的 virtual 函数
    function makeSound() public pure override returns (string memory) {
        return "Woof!";
    }
    
    // 可以调用父合约的实现
    function makeAnimalSound() public pure returns (string memory) {
        return super.makeSound();
    }
}

// 多重继承示例
contract Bird is Animal {
    function makeSound() public pure virtual override returns (string memory) {
        return "Chirp!";
    }
    
    function fly() public pure returns (string memory) {
        return "Flying high!";
    }
}

// 多重继承和重写
contract Parrot is Bird {
    // 重写 Bird 的 makeSound 函数
    function makeSound() public pure override returns (string memory) {
        return "Polly wants a cracker!";
    }
    
    // 重写并保留对父类实现的访问
    function birdSound() public pure returns (string memory) {
        return super.makeSound();
    }
}

// 接口也可以有 virtual 函数
interface IPet {
    function name() external view virtual returns (string memory);
}

// 实现接口并重写函数
contract Pet is IPet {
    // 实现接口中的 virtual 函数
    function name() public pure virtual override returns (string memory) {
        return "Generic Pet";
    }
}

// 重写接口实现
contract Cat is Pet {
    // 重写 Pet 合约中的 name 函数
    function name() public pure override returns (string memory) {
        return "Whiskers";
    }
}