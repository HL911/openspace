// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ERC20 扩展接口 - 接收代币的合约需要实现此接口
interface IERC20Receiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external returns (bool);
}

contract MyTokenPuls is IERC20 {
    
    string public name = "MyToken";
    string public symbol = "MTK";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10 ** decimals;
    address public owner = msg.sender;
    
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;



    constructor() {
        balances[msg.sender] = totalSupply;
    }
    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        return balances[_owner];
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        if (from != msg.sender) {
            uint256 currentAllowance = allowances[from][msg.sender];
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            unchecked {
                _approve(from, msg.sender, currentAllowance - value);
            }
        }
        _transfer(from, to, value); 
        return true;
    }
    
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "ERC20: transfer to the zero address");
        require(balances[from] >= value, "Insufficient balance");
        if (from == address(0)) {
            revert ERC20InvalidSender(from);
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(to);
        }
        _update(from, to, value);
    }
    
    function _update(address from, address to, uint256 value) internal virtual {
        uint256 fromBalance = balances[from];
        balances[from] = fromBalance - value;
        unchecked {
            // 不会溢出，因为 transfer 中已经检查了余额足够
            balances[to] += value;
        }
        emit Transfer(from, to, value);
    }

    function allowance(address _owner, address spender) public view returns (uint256) {
        return allowances[_owner][spender];
    }
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }
    
    function _approve(address _owner, address spender, uint256 value) internal {
        allowances[_owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    // 扩展的转账函数，支持回调
    function transferWithCallback(address to, uint256 value, bytes calldata data) public returns (bool) {
        _transfer(msg.sender, to, value);
        
        // 如果目标地址是合约，调用其 tokensReceived 回调
        if (isContract(to)) {
            try IERC20Receiver(to).tokensReceived(msg.sender, value, data) {
                // 回调成功
            } catch {
                revert("ERC20: tokensReceived callback failed");
            }
        }
        
        return true;
    }
    
    // 标准转账函数重写，添加对回调的支持
    function transfer(address to, uint256 value) public override returns (bool) {
        _transfer(msg.sender, to, value);
        
        // 如果目标地址是合约，调用其 tokensReceived 回调
        if (isContract(to)) {
            try IERC20Receiver(to).tokensReceived(msg.sender, value, "") {
                // 回调成功
            } catch {
                // 忽略回调失败，保持向后兼容性
            }
        }
        
        return true;
    }


    function isContract(address _addr) public view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }  

    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);

}