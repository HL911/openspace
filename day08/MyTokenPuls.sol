// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyToken {
    
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

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
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
    function _update(address from, address to, uint256 value) internal virtual{
       uint256 fromBalance = balances[from];
       balances[from] = fromBalance - value;
       emit Transfer(from, to, value);
       balances[to] += value;
       emit Transfer(to, from, value);
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

    function transferWithCallback(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        if(isContract(to)) {
            (bool success, ) = to.call(abi.encodeWithSignature("tokensReceived(address,uint256)",msg.sender, value));
            require(success, "ERC20: transfer failed");
        }
        return true;
    }

    function tokensReceived(address from, uint256 value) public {
        _transfer(from, msg.sender, value);
    }


    function isContract(address _addr) public view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }  

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);

}