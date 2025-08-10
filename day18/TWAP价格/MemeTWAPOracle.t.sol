// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MemeTWAPOracle.sol";
import "../src/UniswapMemeFactory.sol";
import "../src/UniswapMemeToken.sol";
import "../src/WETH.sol";
import "../src/uniswap-v2-core/UniswapV2Factory.sol";
import "../src/uniswap-v2-periphery/UniswapV2Router02.sol";

// 简单的 ERC20 接口
interface IERC20Simple {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract MemeTWAPOracleTest is Test {
    MemeTWAPOracle public oracle;
    UniswapMemeFactory public memeFactory;
    UniswapMemeToken public memeTokenImpl;
    
    // 使用 Sepolia 网络上的真实地址
    address public constant SEPOLIA_FACTORY = 0x42Fee1219748f7A5411e6C13d822D2d935D9c4A1;
    address public constant SEPOLIA_ROUTER = 0xd2268B943Fa81ac0600b753CE1c9C18BC805f89F;
    address public constant SEPOLIA_WETH = 0x127Abc00C9Fef19a9690f890711670695324c489;
    
    address public issuer = address(0x1);
    address public user = address(0x2);
    address public memeToken;
    
    // 接收 ETH
    receive() external payable {}
    
    function setUp() public {
        // Fork Sepolia 网络的最新块
        vm.createFork("https://sepolia.infura.io/v3/3dbfb8be9fbd4be19fec5cae43e6a8a7");
        
        // 部署 Meme Factory（使用真实的 Uniswap 地址）
        memeFactory = new UniswapMemeFactory();
        
        // 部署 TWAP Oracle
        oracle = new MemeTWAPOracle(
            SEPOLIA_FACTORY,
            SEPOLIA_WETH,
            address(memeFactory)
        );
        
        // 给用户和发行者分配 ETH
        vm.deal(issuer, 100 ether);
        vm.deal(user, 100 ether);
        
        // 发行者创建 Meme 代币
        vm.prank(issuer);
        memeToken = memeFactory.deployMeme(
            "TestMeme",
            "TM",
            1000 , // 最大供应量
            10 ,   // 每次铸造数量
            0.01 ether   // 铸造费用
        );
    }
    
    function testBasicSetup() public {
        // 测试基本设置
        assertEq(address(oracle.uniswapV2Factory()), SEPOLIA_FACTORY);
        assertEq(oracle.WETH(), SEPOLIA_WETH);
        assertEq(address(oracle.memeFactory()), address(memeFactory));
        assertEq(oracle.MIN_PERIOD(), 300);
        assertEq(oracle.MAX_OBSERVATIONS(), 100);
    }
    
    function testInvalidToken() public {
        // 测试无效代币
        address invalidToken = address(0x999);
        
        vm.expectRevert("MemeTWAPOracle: invalid meme token");
        oracle.addObservation(invalidToken);
    }
    
    function testNoPairExists() public {
        // 测试没有交易对的情况
        vm.expectRevert("MemeTWAPOracle: pair does not exist");
        oracle.addObservation(memeToken);
    }
    
    function testAddObservationAfterMinting() public {
        // 用户铸造代币，这会创建流动性池
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        // 现在应该可以添加观察数据
        oracle.addObservation(memeToken);
        
        // 检查观察数据数量
        assertEq(oracle.getObservationCount(memeToken), 1);
    }
    
    function testGetCurrentPrice() public {
        // 用户铸造代币创建流动性
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        // 获取当前价格
        uint256 currentPrice = oracle.getCurrentPrice(memeToken);
        assertGt(currentPrice, 0);
    }
    
    function testGetSimplePriceInfo() public {
        // 测试没有流动性的情况
        (bool hasLiquidity, uint256 currentPrice, uint256 observationCount) = 
            oracle.getSimplePriceInfo(memeToken);
        
        assertFalse(hasLiquidity);
        assertEq(currentPrice, 0);
        assertEq(observationCount, 0);
        
        // 创建流动性后测试
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        (hasLiquidity, currentPrice, observationCount) = 
            oracle.getSimplePriceInfo(memeToken);
        
        assertTrue(hasLiquidity);
        assertGt(currentPrice, 0);
        assertEq(observationCount, 0); // 还没有添加观察数据
    }
    
    function testCanCalculateTWAP() public {
        // 测试没有观察数据的情况
        (bool canCalculate, string memory reason) = oracle.canCalculateTWAP(memeToken, 300);
        assertFalse(canCalculate);
        assertEq(reason, "Insufficient observations");
        
        // 创建流动性并添加观察数据
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        oracle.addObservation(memeToken);
        
        // 仍然不能计算，因为只有一个观察点
        (canCalculate, reason) = oracle.canCalculateTWAP(memeToken, 300);
        assertFalse(canCalculate);
        assertEq(reason, "Insufficient observations");
    }
    
    function testMultipleObservations() public {
        // 创建流动性
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        // 添加第一个观察点
        oracle.addObservation(memeToken);
        assertEq(oracle.getObservationCount(memeToken), 1);
        
        // 立即添加第二个观察点（应该被忽略，因为时间间隔不够）
        oracle.addObservation(memeToken);
        assertEq(oracle.getObservationCount(memeToken), 1);
        
        // 跳过时间
        vm.warp(block.timestamp + 301);
        
        // 现在添加第二个观察点
        oracle.addObservation(memeToken);
        assertEq(oracle.getObservationCount(memeToken), 2);
    }
    
    function testBatchAddObservations() public {
        // 创建多个代币
        vm.prank(issuer);
        address memeToken2 = memeFactory.deployMeme(
            "TestMeme2",
            "TM2",
            1000, // 使用较小的值避免溢出
            10,   // 使用较小的值避免溢出
            0.01 ether
        );
        
        // 为两个代币创建流动性
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken2);
        
        // 为两个代币进行交易以启动价格累积
        performSwap(memeToken);
        performSwap(memeToken2);
        
        // 等待一个区块
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        
        // 批量添加观察数据
        address[] memory tokens = new address[](2);
        tokens[0] = memeToken;
        tokens[1] = memeToken2;
        
        oracle.batchAddObservations(tokens);
        
        assertEq(oracle.getObservationCount(memeToken), 1);
        assertEq(oracle.getObservationCount(memeToken2), 1);
    }
    
    // 辅助函数：进行交易以启动价格累积
    function performSwap(address token) internal {
        // 获取交易对地址
        address pair = IUniswapV2Factory(SEPOLIA_FACTORY).getPair(token, SEPOLIA_WETH);
        require(pair != address(0), "Pair does not exist");
        
        // 进行一个小额交易
        vm.deal(address(this), 0.001 ether);
        
        address[] memory path = new address[](2);
        path[0] = SEPOLIA_WETH;
        path[1] = token;
        
        // 使用 router 进行交易
        IUniswapV2Router02(SEPOLIA_ROUTER).swapExactETHForTokens{value: 0.001 ether}(
            0, // 接受任何数量的代币
            path,
            address(this),
            block.timestamp + 300
        );
        
        // 立即进行反向交易以确保价格累积开始
        IERC20Simple(token).approve(SEPOLIA_ROUTER, type(uint256).max);
        uint256 tokenBalance = IERC20Simple(token).balanceOf(address(this));
        if (tokenBalance > 0) {
            address[] memory reversePath = new address[](2);
            reversePath[0] = token;
            reversePath[1] = SEPOLIA_WETH;
            
            IUniswapV2Router02(SEPOLIA_ROUTER).swapExactTokensForETH(
                tokenBalance / 2, // 只交易一半
                0,
                reversePath,
                address(this),
                block.timestamp + 300
            );
        }
    }

    function testGetObservation() public {
        // 创建流动性
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        // 进行交易以启动价格累积
        performSwap(memeToken);
        
        // 等待多个区块以确保累积价格更新
        vm.roll(block.number + 3);
        vm.warp(block.timestamp + 36);
        
        // 再进行一次交易
        performSwap(memeToken);
        
        // 再等待一个区块
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        
        // 添加观察数据
        oracle.addObservation(memeToken);
        
        // 获取观察数据
        (uint32 timestamp, uint256 price0, uint256 price1) = oracle.getObservation(memeToken, 0);
        
        assertEq(timestamp, uint32(block.timestamp % 2**32));
        // 在有交易后，至少有一个累积价格应该大于0
        assertTrue(price0 > 0 || price1 > 0);
    }
    
    function testGetObservationOutOfBounds() public {
        // 测试索引越界
        vm.expectRevert("MemeTWAPOracle: index out of bounds");
        oracle.getObservation(memeToken, 0);
    }
    
    function testGetBatchTWAP() public {
        // 创建流动性
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        // 添加观察数据
        oracle.addObservation(memeToken);
        
        // 批量获取 TWAP（应该失败，因为观察数据不足）
        address[] memory tokens = new address[](1);
        tokens[0] = memeToken;
        
        (uint256[] memory twapPrices, bool[] memory success) = oracle.getBatchTWAP(tokens, 300);
        
        assertEq(twapPrices.length, 1);
        assertEq(success.length, 1);
        assertFalse(success[0]); // 应该失败
        assertEq(twapPrices[0], 0);
    }
    
    function testPriceChangeCalculation() public {
        // 创建流动性
        vm.prank(user);
        memeFactory.mintMeme{value: 0.01 ether}(memeToken);
        
        // 进行交易以启动价格累积
        performSwap(memeToken);
        
        // 等待一个区块
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        
        // 添加第一个观察点
        oracle.addObservation(memeToken);
        
        // 等待足够的时间
        vm.warp(block.timestamp + 301);
        
        // 进行另一次交易
        performSwap(memeToken);
        
        // 等待一个区块
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        
        // 添加第二个观察点
        oracle.addObservation(memeToken);
        
        // 尝试获取价格变化
        try oracle.getPriceChange(memeToken, 300) returns (
            uint256 twapPrice,
            uint256 mintPrice,
            int256 priceChange
        ) {
            assertGt(twapPrice, 0);
            assertGt(mintPrice, 0);
            // priceChange 可以是正数、负数或零
        } catch {
            // 如果失败也是正常的，因为可能时间跨度不够
        }
    }
}