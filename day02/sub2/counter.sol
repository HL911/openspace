//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract Counter {
    uint public count;

    constructor() {
        count = 0;
    }
    
    function add(uint x) external {
        count += x;
    }
    
    function get() public view returns(uint256) {
        return count;
    }
    
    // 使用pure关键字的函数示例
    // 这个函数不读取也不修改合约状态
    function addNumbers(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }
    
    // 使用view关键字的函数示例
    // 这个函数可以读取状态变量count，但不会修改它
    // 调用这个函数不需要消耗gas（本地调用时）
    function addToCount(uint256 x) public view returns (uint256) {
        return count + x;
    }
    
    // 接收以太币的payable函数
    // 当用户发送以太币到合约时，count会增加相应的wei数量
    function addWithPayment() public payable {
        require(msg.value > 0, "Must send some ETH");
        count += msg.value;
    }
    
    // 获取合约余额
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    // 允许合约所有者提取资金
    function withdraw() public {
        // 注意：在生产环境中，您应该添加权限控制（如onlyOwner）
        payable(msg.sender).transfer(address(this).balance);
    }
}
