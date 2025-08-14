// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CallOption.sol";

/**
 * @title DeployCallOption
 * @dev 部署看涨期权合约的脚本
 */
contract DeployCallOption is Script {
    // 网络配置
    struct NetworkConfig {
        address usdtAddress;
        uint256 deployerPrivateKey;
    }
    
    // 主网USDT地址
    address constant MAINNET_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    // Sepolia测试网USDT地址 (需要部署或使用现有的)
    address constant SEPOLIA_USDT = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;
    
    function run() external {
        NetworkConfig memory config = getNetworkConfig();
        
        // 期权参数配置
        uint256 strikePrice = 3200 * 10**18; // 3200 USDT per ETH
        uint256 expiration = block.timestamp + 90 days; // 90天后到期
        uint256 optionPrice = 100 * 10**18; // 100 USDT per option
        
        console.log("Deploying CallOption with parameters:");
        console.log("Strike Price:", strikePrice / 10**18, "USDT per ETH");
        console.log("Option Price:", optionPrice / 10**18, "USDT per option");
        console.log("Expiration:", expiration);
        console.log("USDT Address:", config.usdtAddress);
        
        vm.startBroadcast(config.deployerPrivateKey);
        
        CallOption callOption = new CallOption(
            strikePrice,
            expiration,
            optionPrice,
            config.usdtAddress
        );
        
        vm.stopBroadcast();
        
        console.log("CallOption deployed at:", address(callOption));
        console.log("Owner:", callOption.owner());
        console.log("Token Name:", callOption.name());
        console.log("Token Symbol:", callOption.symbol());
        
        // 保存部署信息到文件
        saveDeploymentInfo(address(callOption), strikePrice, expiration, config.usdtAddress);
    }
    
    function getNetworkConfig() internal returns (NetworkConfig memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) {
            // Ethereum Mainnet
            return NetworkConfig({
                usdtAddress: MAINNET_USDT,
                deployerPrivateKey: vm.envUint("PRIVATE_KEY")
            });
        } else if (chainId == 11155111) {
            // Sepolia Testnet
            return NetworkConfig({
                usdtAddress: SEPOLIA_USDT,
                deployerPrivateKey: vm.envUint("PRIVATE_KEY")
            });
        } else if (chainId == 31337) {
            // Local Anvil
            return NetworkConfig({
                usdtAddress: deployMockUSDT(),
                deployerPrivateKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            });
        } else {
            revert("Unsupported network");
        }
    }
    
    function deployMockUSDT() internal returns (address) {
        console.log("Deploying Mock USDT for local testing...");
        
        // 简单的Mock USDT合约
        bytes memory bytecode = abi.encodePacked(
            type(MockUSDT).creationCode
        );
        
        address mockUSDT;
        bytes32 saltValue = keccak256(abi.encodePacked("MockUSDT", block.timestamp));
        assembly {
            mockUSDT := create2(0, add(bytecode, 0x20), mload(bytecode), saltValue)
        }
        
        console.log("Mock USDT deployed at:", mockUSDT);
        return mockUSDT;
    }
    

    
    function saveDeploymentInfo(
        address callOptionAddress,
        uint256 strikePrice,
        uint256 expiration,
        address usdtAddress
    ) internal {
        string memory deploymentInfo = string(abi.encodePacked(
            "CallOption Deployment Info\n",
            "========================\n",
            "Network: ", vm.toString(block.chainid), "\n",
            "CallOption Address: ", vm.toString(callOptionAddress), "\n",
            "Strike Price: ", vm.toString(strikePrice / 10**18), " USDT per ETH\n",
            "Expiration: ", vm.toString(expiration), "\n",
            "USDT Address: ", vm.toString(usdtAddress), "\n",
            "Deployed at: ", vm.toString(block.timestamp), "\n"
        ));
        
        console.log(deploymentInfo);
    }
}

// Mock USDT合约用于本地测试
contract MockUSDT {
    string public name = "Mock USDT";
    string public symbol = "USDT";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000000 * 10**18; // 10亿USDT
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor() {
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}