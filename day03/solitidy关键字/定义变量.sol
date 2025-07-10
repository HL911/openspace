// 基础声明（internal可见性，可修改）
uint256 internal totalSupply; 

// 公开可见性 + 声明时初始化
address public owner = msg.sender; 

// 私有常量（编译时确定）
bytes32 private constant HASH = keccak256("SECRET");

// 不可变量（构造函数赋值）
uint256 public immutable creationTime;
constructor() {
    creationTime = block.timestamp; // 只能在构造器赋值一次
}

// 完整语法示例
string public constant TOKEN_SYMBOL = "ETH";