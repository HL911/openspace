//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bank  {
    address public owner = msg.sender;
    address public automationContract;
    uint256 public threshold = 10 * 10**18; // 10个代币，假设18位小数
    IERC20 public token; // ERC20代币合约
    
    // 存储的地址余额
    mapping(address => uint256) public balance;
    
    // 合约总存款余额
    uint256 public totalDeposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event ThresholdUpdated(uint256 newThreshold);
    event AutomationContractUpdated(address newAutomationContract);
    event TokenUpdated(address indexed newToken);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    
    modifier onlyAutomation() {
        require(msg.sender == automationContract, "Only automation can call this function");
        _;
    }   
    

    // 构造函数，设置ERC20代币地址
    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }
    
    function deposit(uint256 _amount) public  {
        require(_amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        balance[msg.sender] += _amount;
        totalDeposits += _amount;
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public  {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= balance[msg.sender], "Insufficient user balance");
        require(_amount <= token.balanceOf(address(this)), "Insufficient contract balance");
        
        balance[msg.sender] -= _amount;
        totalDeposits -= _amount;
        require(token.transfer(msg.sender, _amount), "Transfer failed");
        emit Withdrawal(msg.sender, _amount);
    }

    // 转账一半资金到指定地址，只能由自动化合约调用
    function transferHalf() external onlyAutomation  {
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= threshold, "Contract balance below threshold");
        
        uint256 amountToTransfer = contractBalance / 2;
        require(amountToTransfer > 0, "Amount to transfer must be greater than 0");
        
        require(token.transfer(owner, amountToTransfer), "Transfer failed");
        
        emit Withdrawal(owner, amountToTransfer);
    }

    // Owner可以更新阈值
    function setThreshold(uint256 _newThreshold) external onlyOwner {
        threshold = _newThreshold;
        emit ThresholdUpdated(_newThreshold);
    }
    // 设置自动化合约地址
    function setAutomationContract(address _automationContract) external onlyOwner {
        require(_automationContract != address(0), "Automation contract cannot be zero address");
        automationContract = _automationContract;
        emit AutomationContractUpdated(_automationContract);
    }
    
    // 设置ERC20代币地址
    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
        emit TokenUpdated(_token);
    }
    
    // 获取合约代币余额
    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

}