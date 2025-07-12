// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 异常处理示例
 * @dev 本合约演示了 Solidity 中的 assert() 和 require() 的用法
 */
contract ExceptionExample {
    address public owner;
    uint256 public value;
    mapping(address => uint256) public balances;

    // 构造函数，设置合约部署者为拥有者
    constructor() {
        owner = msg.sender;
    }

    // 1. require() 示例
    // require() 用于验证输入和条件，如果条件不满足则回滚状态并返回错误信息
    // 通常用于验证用户输入或外部调用的返回值
    
    // 存款函数
    function deposit(uint256 _amount) public {
        // 使用 require 验证输入
        require(_amount > 0, "Deposit amount must be greater than 0");
        
        // 更新用户余额
        balances[msg.sender] += _amount;
    }

    // 取款函数
    function withdraw(uint256 _amount) public {
        // 使用 require 验证多个条件
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        // 更新余额
        balances[msg.sender] -= _amount;
    }

    // 2. assert() 示例
    // assert() 用于检查内部错误，这些错误理论上不应该发生
    // 如果 assert 失败，说明合约逻辑存在问题
    
    // 设置值的函数，演示 assert 使用
    function setValue(uint256 _newValue) public {
        // 使用 require 验证输入
        require(_newValue != 0, "Value cannot be zero");
        
        uint256 oldValue = value;
        value = _newValue;
        
        // 使用 assert 验证内部状态
        // 这里我们确保新值确实被更新了
        assert(value == _newValue);
        
        // 另一个 assert 示例：确保值确实改变了
        // 注意：这个 assert 在 _newValue 等于 oldValue 时会失败
        // 这展示了 assert 的用途 - 检查不应该发生的情况
        assert(value != oldValue);
    }

    // 3. 结合使用 require 和 assert 的示例
    function transfer(address _to, uint256 _amount) public {
        // 使用 require 验证输入和条件
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Transfer amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        // 记录转账前的余额
        uint256 senderBalanceBefore = balances[msg.sender];
        uint256 receiverBalanceBefore = balances[_to];
        
        // 执行转账
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
        
        // 使用 assert 验证状态一致性
        // 检查发送方余额是否正确减少
        assert(balances[msg.sender] == senderBalanceBefore - _amount);
        
        // 检查接收方余额是否正确增加
        assert(balances[_to] == receiverBalanceBefore + _amount);
        
        // 检查总供应量是否保持不变
        // 这是一个重要的不变量检查
        assert(
            balances[msg.sender] + balances[_to] == 
            senderBalanceBefore + receiverBalanceBefore
        );
    }

    // 4. 另一个 assert 示例 - 检查数学运算
    function divide(uint256 a, uint256 b) public pure returns (uint256) {
        // 使用 require 验证输入
        require(b != 0, "Divisor cannot be zero");
        
        uint256 result = a / b;
        
        // 使用 assert 验证数学运算的正确性
        // 如果 b 为 0，require 会先失败
        // 这个 assert 检查 (a / b) * b + a % b 是否等于 a
        assert((b * result) + (a % b) == a);
        
        return result;
    }

    // 5. 使用 revert 直接回滚交易
    function checkStatus(bool status) public pure returns (string memory) {
        if (!status) {
            revert("Operation failed: Invalid status");
        }
        return "Operation successful";
    }

    // 6. 自定义错误类型
    // 自定义错误比 require 更节省 gas，特别是在错误信息较长时
    error InsufficientBalance(uint256 available, uint256 required);
    error Unauthorized(address caller);
    
    // 使用自定义错误的函数示例
    function transferWithCustomError(address _to, uint256 _amount) public {
        // 检查调用者是否有足够的余额
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance({
                available: balances[msg.sender],
                required: _amount
            });
        }
        
        // 检查接收地址是否有效
        if (_to == address(0)) {
            revert("Invalid recipient address");
        }
        
        // 执行转账
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }
    
    // 7. 结合自定义错误和 require
    function onlyOwner() public view {
        if (msg.sender != owner) {
            revert Unauthorized(msg.sender);
        }
        // 或者等价的 require 写法（更消耗 gas）
        // require(msg.sender == owner, "Caller is not the owner");
    }
    
    // 8. 带有参数的自定义错误示例
    error TransferFailed(
        address from,
        address to,
        uint256 amount,
        string reason
    );
    
    function safeTransfer(address _to, uint256 _amount) public {
        // 检查余额
        if (balances[msg.sender] < _amount) {
            revert TransferFailed({
                from: msg.sender,
                to: _to,
                amount: _amount,
                reason: "Insufficient balance"
            });
        }
        
        // 模拟转账失败的情况
        bool success = _simulateTransfer(_to, _amount);
        
        if (!success) {
            revert TransferFailed({
                from: msg.sender,
                to: _to,
                amount: _amount,
                reason: "Transfer reverted"
            });
        }
        
        // 更新余额
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }
    
    // 模拟转账函数（仅用于演示）
    function _simulateTransfer(address, uint256) private view returns (bool) {
        // 在实际合约中，这里可能是调用外部合约的转账函数
        // 这里为了演示，随机返回 true 或 false
        return block.timestamp % 2 == 0;
    }
}
