// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入必要的OpenZeppelin合约
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";          // ERC20接口
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";  // ERC20元数据扩展
import "@openzeppelin/contracts/utils/Context.sol";                // 提供_msgSender()等上下文函数
import "@openzeppelin/contracts/utils/Address.sol";                // 提供地址工具函数

/**
 * @dev ERC1363代币标准实现
 * 
 * 这个合约实现了IERC1363接口，扩展了ERC20标准，增加了代币转移后执行合约调用的功能
 */
contract ERC1363 is Context, IERC20, IERC20Metadata, IERC1363 {
    using Address for address;  // 使用Address库中的函数扩展address类型

    // 余额映射：地址 => 代币数量
    mapping(address => uint256) private _balances;
    
    // 授权映射：所有者 => (操作者 => 授权数量)
    mapping(address => mapping(address => uint256)) private _allowances;

    // 代币元数据
    string private _name;     // 代币名称
    string private _symbol;   // 代币符号
    uint8 private _decimals;  // 代币小数位
    uint256 private _totalSupply;  // 总供应量

    /**
     * @dev 构造函数，初始化代币的基本信息
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param decimals_ 代币小数位
     * @param initialSupply_ 初始供应量（以最小单位计算）
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 initialSupply_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        // 将初始供应量铸造给合约部署者
        _mint(_msgSender(), initialSupply_ * (10 ** uint256(decimals_)));
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     */
    /**
     * @dev 内部转账函数，实现代币转移的核心逻辑
     * @param from 发送方地址
     * @param to 接收方地址
     * @param amount 转账数量
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: 不能从零地址转账");
        require(to != address(0), "ERC20: 不能转账到零地址");

        // 转账前的钩子函数
        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: 转账数量超过余额");
        
        // 使用unchecked块优化gas消耗
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        // 触发转账事件
        emit Transfer(from, to, amount);

        // 转账后的钩子函数
        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     */
    /**
     * @dev 内部授权函数，设置一个地址可以操作调用者代币的数量
     * @param owner 代币拥有者地址
     * @param spender 被授权人地址
     * @param amount 授权数量
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: 不能从零地址授权");
        require(spender != address(0), "ERC20: 不能授权给零地址");

        _allowances[owner][spender] = amount;
        // 触发授权事件
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    // ERC1363 Implementation

    /**
     * @dev Transfer tokens to a contract address with additional data if the recipient is a contract.
     * @param to The address to transfer to.
     * @param amount The amount to be transferred.
     * @return A boolean that indicates if the operation was successful.
     */
    /**
     * @dev 转账并调用接收方合约（不包含附加数据）
     * @param to 接收方地址
     * @param amount 转账数量
     * @return 操作是否成功
     */
    function transferAndCall(address to, uint256 amount) public virtual override returns (bool) {
        return transferAndCall(to, amount, "");
    }

    /**
     * @dev Transfer tokens to a contract address with additional data if the recipient is a contract.
     * @param to The address to transfer to.
     * @param amount The amount to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean that indicates if the operation was successful.
     */
    /**
     * @dev 转账并调用接收方合约（包含附加数据）
     * @param to 接收方地址
     * @param amount 转账数量
     * @param data 附加数据
     * @return 操作是否成功
     */
    function transferAndCall(
        address to,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        // 执行转账
        transfer(to, amount);
        // 检查接收方是否实现了IERC1363Receiver接口，并调用其onTransferReceived方法
        require(_checkOnTransferReceived(_msgSender(), to, amount, data), "ERC1363: 接收方返回了错误的数据");
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another and then execute a callback on recipient.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param amount The amount of tokens to be transferred.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        return transferFromAndCall(from, to, amount, "");
    }

    /**
     * @dev Transfer tokens from one address to another and then execute a callback on recipient.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param amount The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        transferFrom(from, to, amount);
        require(_checkOnTransferReceived(from, to, amount, data), "ERC1363: receiver returned wrong data");
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender
     * and then execute a callback on the spender.
     * @param spender The address which will spend the funds.
     * @param amount The amount of tokens to be spent.
     * @return A boolean that indicates if the operation was successful.
     */
    function approveAndCall(address spender, uint256 amount) public virtual override returns (bool) {
        return approveAndCall(spender, amount, "");
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender
     * and then execute a callback on the spender.
     * @param spender The address which will spend the funds.
     * @param amount The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean that indicates if the operation was successful.
     */
    function approveAndCall(
        address spender,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        approve(spender, amount);
        require(_checkApprovalReceived(spender, amount, data), "ERC1363: spender returned wrong data");
        return true;
    }

    /**
     * @dev Internal function to invoke {IERC1363Receiver-onTransferReceived} on a target address.
     */
    /**
     * @dev 检查接收方是否实现了IERC1363Receiver接口，并调用其onTransferReceived方法
     * @param sender 发送方地址
     * @param recipient 接收方地址
     * @param amount 转账数量
     * @param data 附加数据
     * @return 是否成功调用接收方合约
     */
    function _checkOnTransferReceived(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        // 如果接收方不是合约，直接返回true
        if (!recipient.isContract()) {
            return true;
        }

        try IERC1363Receiver(recipient).onTransferReceived(_msgSender(), sender, amount, data) returns (bytes4 retval) {
            // 检查接收方合约是否返回了正确的函数选择器
            return retval == IERC1363Receiver.onTransferReceived.selector;
        } catch (bytes memory reason) {
            // 如果调用失败，返回错误信息
            if (reason.length == 0) {
                revert("ERC1363: 接收方未实现IERC1363Receiver接口");
            } else {
                // 使用内联汇编来返回原始错误信息
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    /**
     * @dev Internal function to invoke {IERC1363Receiver-approvalReceived} on a target address.
     */
    function _checkApprovalReceived(
        address spender,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        if (!spender.isContract()) {
            return true;
        }

        try IERC1363Spender(spender).onApprovalReceived(_msgSender(), amount, data) returns (bytes4 retval) {
            return retval == IERC1363Spender.onApprovalReceived.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("ERC1363: approve a non ERC1363Spender implementer");
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }
}

/**
 * @title ERC1363Token
 * @dev Implementation of the ERC1363 token with custom token name, symbol, and initial supply.
 */
contract ERC1363Token is ERC1363 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply_
    ) ERC1363(name_, symbol_, decimals_, initialSupply_) {}
}

/**
 * @title IERC1363Receiver
 * @dev Interface for any contract that wants to support `transferAndCall` or `transferFromAndCall`
 * from ERC1363 token contracts.
 */
interface IERC1363Receiver {
    /**
     * @notice Handle the receipt of ERC1363 tokens
     * @dev Any ERC1363 smart contract calls this function on the recipient
     * after a `transfer` or `transferFrom`. This function MAY throw to revert and reject the
     * transfer. Return of other than the magic value MUST result in the
     * transaction being reverted.
     * Note: the token contract address is always the message sender.
     * @param operator address The address which called `transferAndCall` or `transferFromAndCall` function
     * @param from address The address which are token transferred from
     * @param value uint256 The amount of tokens transferred
     * @param data bytes Additional data with no specified format
     * @return `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))` unless throwing
     */
    function onTransferReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title IERC1363Spender
 * @dev Interface for any contract that wants to support `approveAndCall`
 * from ERC1363 token contracts.
 */
interface IERC1363Spender {
    /**
     * @notice Handle the approval of ERC1363 tokens
     * @dev Any ERC1363 smart contract calls this function on the recipient
     * after an `approve`. This function MAY throw to revert and reject the
     * approval. Return of other than the magic value MUST result in the
     * transaction being reverted.
     * Note: the token contract address is always the message sender.
     * @param owner address The address which called `approveAndCall` function
     * @param value uint256 The amount of tokens to be spent
     * @param data bytes Additional data with no specified format
     * @return `bytes4(keccak256("onApprovalReceived(address,uint256,bytes)"))` unless throwing
     */
    function onApprovalReceived(
        address owner,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title IERC1363
 * @dev Interface of the ERC1363 standard as defined in the ERC1363.
 */
interface IERC1363 is IERC20 {
    /**
     * @dev Transfer tokens to a specified address and then execute a callback on the recipient.
     * @param to The address to transfer to.
     * @param amount The amount to be transferred.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferAndCall(address to, uint256 amount) external returns (bool);

    /**
     * @dev Transfer tokens to a specified address with data and then execute a callback on the recipient.
     * @param to The address to transfer to.
     * @param amount The amount to be transferred.
     * @param data Additional data with no specified format.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferAndCall(
        address to,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);

    /**
     * @dev Transfer tokens from one address to another and then execute a callback on the recipient.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param amount The amount of tokens to be transferred.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Transfer tokens from one address to another with data and then execute a callback on the recipient.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param amount The amount of tokens to be transferred.
     * @param data Additional data with no specified format.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);

    /**
     * @dev Approve spender to spend tokens and then execute a callback on the spender.
     * @param spender The address which will spend the funds.
     * @param amount The amount of tokens to be spent.
     * @return A boolean that indicates if the operation was successful.
     */
    function approveAndCall(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Approve spender to spend tokens with data and then execute a callback on the spender.
     * @param spender The address which will spend the funds.
     * @param amount The amount of tokens to be spent.
     * @param data Additional data with no specified format.
     * @return A boolean that indicates if the operation was successful.
     */
    function approveAndCall(
        address spender,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}
