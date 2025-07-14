// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Bank {
    receive() external payable { }
    address public owner;
    mapping(address => uint256) public balance;

    function deposit() public payable {
        require(msg.value > 0, "Amount must be greater than 0");
        // 更新用户余额
        balance[msg.sender] += msg.value;

    }
    function withdraw(uint256 amount) public payable {
        require(amount > 0, "You don't have enogh money");
        // 更新用户余额
        balance[msg.sender] -= amount;
    payable(msg.sender).transfer(amount);
    }
}

contract CallTest{ 
    receive() external payable { }
    constructor() payable {}
     function testWithSignatureCall(address targetAddress) public payable {
          bytes memory methodData = abi.encodeWithSignature("deposit()");
          (bool success, )=  targetAddress.call{value: msg.value}(methodData);
          require(success, "Call failed1");
     }

     function testencodePackedCall(address targetAddress) public payable {
        bytes4 depositSelector = bytes4(keccak256("withdraw(uint256)"));
        (bool success, )=  targetAddress.call{value: msg.value}(abi.encodePacked(depositSelector, abi.encode(123)));
        require(success, "Call failed2");
     }
}