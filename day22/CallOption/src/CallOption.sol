// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ICallOption.sol";

/**
 * @title CallOption
 * @dev ETH看涨期权合约实现
 * @notice 用户支付期权费购买期权，可在到期前按行权价格购买ETH
 */
contract CallOption is ERC20, Ownable, ReentrancyGuard, ICallOption {
    using SafeERC20 for IERC20;

    // 状态变量
    uint256 public immutable strikePrice;    // 行权价格 (USDT per ETH)
    uint256 public immutable expiration;     // 到期时间戳
    uint256 public immutable optionPrice;   // 期权费用 (USDT per option)
    IERC20 public immutable usdt;           // USDT代币合约
    
    uint256 public totalLocked;              // 总锁定ETH数量
    bool public expired;                     // 是否已过期

    // 修饰符
    modifier beforeExpiration() {
        require(block.timestamp < expiration, "Option has expired");
        _;
    }

    modifier afterExpiration() {
        require(block.timestamp >= expiration, "Option has not expired yet");
        _;
    }

    modifier notExpired() {
        require(!expired, "Contract is expired");
        _;
    }

    /**
     * @dev 构造函数
     * @param _strikePrice 行权价格 (USDT per ETH, 18位精度)
     * @param _expiration 行权截止时间戳
     * @param _optionPrice 期权费用 (USDT per option, 18位精度)
     * @param _usdtAddress USDT合约地址
     */
    constructor(
        uint256 _strikePrice,
        uint256 _expiration,
        uint256 _optionPrice,
        address _usdtAddress
    ) ERC20(
        string(abi.encodePacked("ETH Call Option ", _timestampToDate(_expiration))),
        string(abi.encodePacked("CALL-", _timestampToDate(_expiration)))
    ) Ownable(msg.sender) {
        require(_strikePrice > 0, "Strike price must be greater than 0");
        require(_expiration > block.timestamp, "Expiration must be in the future");
        require(_optionPrice > 0, "Option price must be greater than 0");
        require(_usdtAddress != address(0), "Invalid USDT address");

        strikePrice = _strikePrice;
        expiration = _expiration;
        optionPrice = _optionPrice;
        usdt = IERC20(_usdtAddress);
    }

    /**
     * @dev 项目方存款ETH作为期权标的资产
     * @notice 只有合约所有者可以调用
     */
    function deposit() external payable onlyOwner beforeExpiration notExpired {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        uint256 ethAmount = msg.value;
        totalLocked += ethAmount;

        emit Deposited(ethAmount, totalLocked);
    }

    /**
     * @dev 用户购买期权
     * @param optionAmount 购买的期权数量 (以ETH为单位)
     */
    function buyOption(uint256 optionAmount) external nonReentrant beforeExpiration notExpired {
        require(optionAmount > 0, "Option amount must be greater than 0");
        require(totalLocked >= optionAmount, "Insufficient ETH locked for options");
        
        // 计算需要支付的期权费
        uint256 totalOptionFee = optionAmount * optionPrice / 1 ether;
        require(usdt.balanceOf(msg.sender) >= totalOptionFee, "Insufficient USDT balance");
        require(usdt.allowance(msg.sender, address(this)) >= totalOptionFee, "Insufficient USDT allowance");

        // 收取期权费
        usdt.safeTransferFrom(msg.sender, owner(), totalOptionFee);
        
        // 铸造期权Token给用户
        _mint(msg.sender, optionAmount);

        emit OptionPurchased(msg.sender, optionAmount, totalOptionFee);
    }

    /**
     * @dev 用户行权函数
     * @param optionAmount 行权的期权Token数量
     */
    function exercise(uint256 optionAmount) external nonReentrant beforeExpiration notExpired {
        require(optionAmount > 0, "Option amount must be greater than 0");
        require(balanceOf(msg.sender) >= optionAmount, "Insufficient option tokens");
        require(address(this).balance >= optionAmount, "Insufficient ETH in contract");

        // 计算需要支付的USDT数量
        uint256 usdtRequired = optionAmount * strikePrice / 1 ether;
        require(usdt.balanceOf(msg.sender) >= usdtRequired, "Insufficient USDT balance");
        require(usdt.allowance(msg.sender, address(this)) >= usdtRequired, "Insufficient USDT allowance");

        // 先销毁期权Token
        _burn(msg.sender, optionAmount);
        
        // 从用户转移USDT到项目方
        usdt.safeTransferFrom(msg.sender, owner(), usdtRequired);
        
        // 向用户转移ETH
        totalLocked -= optionAmount;
        (bool success, ) = payable(msg.sender).call{value: optionAmount}("");
        require(success, "ETH transfer failed");

        emit Exercised(msg.sender, optionAmount, usdtRequired);
    }

    /**
     * @dev 过期清算函数
     * @notice 只有合约所有者可以调用，且必须在过期后
     */
    function expire() external onlyOwner afterExpiration {
        require(!expired, "Already expired");
        
        expired = true;
        uint256 remainingETH = address(this).balance;
        totalLocked = 0;
        
        if (remainingETH > 0) {
            (bool success, ) = payable(owner()).call{value: remainingETH}("");
            require(success, "ETH transfer failed");
        }
        
        emit Expired(remainingETH);
    }

    /**
     * @dev 添加流动性
     * @notice 只有合约所有者可以调用
     */
    function addLiquidity() external payable onlyOwner beforeExpiration notExpired {
        require(msg.value > 0, "Liquidity amount must be greater than 0");
        
        totalLocked += msg.value;
        
        emit LiquidityAdded(msg.value, totalLocked);
    }

    /**
     * @dev 紧急提取函数
     * @notice 只有合约所有者可以调用，用于紧急情况
     */
    function emergencyWithdraw() external onlyOwner {
        require(block.timestamp > expiration + 30 days, "Emergency conditions not met");
        
        uint256 ethBalance = address(this).balance;
        uint256 usdtBalance = usdt.balanceOf(address(this));
        
        totalLocked = 0;
        expired = true;
        
        if (ethBalance > 0) {
            (bool success, ) = payable(owner()).call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }
        
        if (usdtBalance > 0) {
            usdt.safeTransfer(owner(), usdtBalance);
        }
        
        emit EmergencyWithdraw(ethBalance, usdtBalance);
    }

    // 查询函数
    function intrinsicValue(uint256 currentETHPrice) external view returns (uint256) {
        if (currentETHPrice <= strikePrice) {
            return 0;
        }
        return currentETHPrice - strikePrice;
    }

    function isInTheMoney(uint256 currentETHPrice) external view returns (bool) {
        return currentETHPrice > strikePrice;
    }

    function timeToExpiration() external view returns (uint256) {
        if (block.timestamp >= expiration) {
            return 0;
        }
        return expiration - block.timestamp;
    }

    // 内部函数
    function _timestampToDate(uint256 timestamp) internal pure returns (string memory) {
        // 简化的日期转换，实际项目中可能需要更复杂的实现
        return string(abi.encodePacked("T", _toString(timestamp)));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // 接收ETH的回退函数
    receive() external payable {
        // 只允许合约所有者或合约本身发送ETH
        require(msg.sender == owner() || msg.sender == address(this), "Only owner can send ETH directly");
    }
}