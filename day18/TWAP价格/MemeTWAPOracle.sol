// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UniswapMemeFactory.sol";

// 简化的 Uniswap V2 Pair 接口
interface IUniswapV2PairSimple {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
}

// 简化的 Uniswap V2 Factory 接口
interface IUniswapV2FactorySimple {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * @title MemeTWAPOracle
 * @dev 用于获取 LaunchPad 发行的 Meme 代币的 TWAP（时间加权平均价格）
 */
contract MemeTWAPOracle {
    
    // TWAP 观察数据结构
    struct Observation {
        uint32 timestamp;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
    }
    
    // 代币对应的观察数据
    mapping(address => Observation[]) public observations;
    
    // 最小观察间隔（秒）
    uint32 public constant MIN_PERIOD = 300; // 5分钟
    
    // 最大观察数量
    uint256 public constant MAX_OBSERVATIONS = 100;
    
    // Uniswap V2 Factory 地址
    IUniswapV2FactorySimple public immutable uniswapV2Factory;
    
    // WETH 地址
    address public immutable WETH;
    
    // Meme Factory 地址
    UniswapMemeFactory public immutable memeFactory;
    
    // 事件
    event ObservationAdded(address indexed token, uint32 timestamp, uint256 price0Cumulative, uint256 price1Cumulative);
    event TWAPUpdated(address indexed token, uint256 twapPrice, uint32 period);
    
    constructor(address _uniswapV2Factory, address _weth, address _memeFactory) {
        uniswapV2Factory = IUniswapV2FactorySimple(_uniswapV2Factory);
        WETH = _weth;
        memeFactory = UniswapMemeFactory(_memeFactory);
    }
    
    /**
     * @dev 添加价格观察数据
     * @param token Meme 代币地址
     */
    function addObservation(address token) external {
        // 验证是否为有效的 Meme 代币
        require(memeFactory.tokenToIssuer(token) != address(0), "MemeTWAPOracle: invalid meme token");
        
        // 获取 Uniswap 交易对
        address pair = uniswapV2Factory.getPair(token, WETH);
        require(pair != address(0), "MemeTWAPOracle: pair does not exist");
        
        IUniswapV2PairSimple pairContract = IUniswapV2PairSimple(pair);
        
        // 获取当前累积价格
        uint256 price0CumulativeLast = pairContract.price0CumulativeLast();
        uint256 price1CumulativeLast = pairContract.price1CumulativeLast();
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        
        // 检查是否需要添加新观察
        Observation[] storage tokenObservations = observations[token];
        
        if (tokenObservations.length == 0 || 
            blockTimestamp - tokenObservations[tokenObservations.length - 1].timestamp >= MIN_PERIOD) {
            
            // 如果观察数据已满，移除最旧的
            if (tokenObservations.length >= MAX_OBSERVATIONS) {
                for (uint256 i = 0; i < tokenObservations.length - 1; i++) {
                    tokenObservations[i] = tokenObservations[i + 1];
                }
                tokenObservations.pop();
            }
            
            // 添加新观察
            tokenObservations.push(Observation({
                timestamp: blockTimestamp,
                price0CumulativeLast: price0CumulativeLast,
                price1CumulativeLast: price1CumulativeLast
            }));
            
            emit ObservationAdded(token, blockTimestamp, price0CumulativeLast, price1CumulativeLast);
        }
    }
    
    /**
     * @dev 获取指定时间段的 TWAP 价格
     * @param token Meme 代币地址
     * @param period 时间段（秒）
     * @return twapPrice TWAP 价格（以 WETH 为单位，18位精度）
     */
    function getTWAP(address token, uint32 period) external view returns (uint256 twapPrice) {
        require(memeFactory.tokenToIssuer(token) != address(0), "MemeTWAPOracle: invalid meme token");
        require(period >= MIN_PERIOD, "MemeTWAPOracle: period too short");
        
        Observation[] storage tokenObservations = observations[token];
        require(tokenObservations.length >= 2, "MemeTWAPOracle: insufficient observations");
        
        // 获取最新观察
        Observation memory latestObs = tokenObservations[tokenObservations.length - 1];
        
        // 查找目标时间点的观察
        uint32 targetTimestamp = latestObs.timestamp - period;
        Observation memory earlierObs;
        bool found = false;
        
        for (int256 i = int256(tokenObservations.length) - 2; i >= 0; i--) {
            if (tokenObservations[uint256(i)].timestamp <= targetTimestamp) {
                earlierObs = tokenObservations[uint256(i)];
                found = true;
                break;
            }
        }
        
        require(found, "MemeTWAPOracle: no observation for the period");
        
        // 计算时间差
        uint32 timeElapsed = latestObs.timestamp - earlierObs.timestamp;
        require(timeElapsed > 0, "MemeTWAPOracle: invalid time elapsed");
        
        // 获取交易对信息
        address pair = uniswapV2Factory.getPair(token, WETH);
        IUniswapV2PairSimple pairContract = IUniswapV2PairSimple(pair);
        
        // 确定代币顺序
        bool isToken0 = pairContract.token0() == token;
        
        // 计算 TWAP
        if (isToken0) {
            // token 是 token0，WETH 是 token1
            // price0 = token1/token0 = WETH/token
            uint256 priceCumulativeDiff = latestObs.price0CumulativeLast - earlierObs.price0CumulativeLast;
            twapPrice = priceCumulativeDiff / timeElapsed;
        } else {
            // token 是 token1，WETH 是 token0  
            // price1 = token0/token1 = WETH/token
            uint256 priceCumulativeDiff = latestObs.price1CumulativeLast - earlierObs.price1CumulativeLast;
            twapPrice = priceCumulativeDiff / timeElapsed;
        }
        
        // 转换为标准 18 位精度（UQ112x112 格式转换）
        // UQ112x112 格式：高112位是整数部分，低112位是小数部分
        // 除以 2^112 转换为普通数值，然后乘以 1e18 得到18位精度
        twapPrice = (twapPrice * 1e18) / (2**112);
    }
    
    /**
     * @dev 获取当前即时价格（非 TWAP）
     * @param token Meme 代币地址
     * @return currentPrice 当前价格（以 WETH 为单位，18位精度）
     */
    function getCurrentPrice(address token) external view returns (uint256 currentPrice) {
        require(memeFactory.tokenToIssuer(token) != address(0), "MemeTWAPOracle: invalid meme token");
        
        address pair = uniswapV2Factory.getPair(token, WETH);
        require(pair != address(0), "MemeTWAPOracle: pair does not exist");
        
        IUniswapV2PairSimple pairContract = IUniswapV2PairSimple(pair);
        (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();
        
        require(reserve0 > 0 && reserve1 > 0, "MemeTWAPOracle: no liquidity");
        
        // 确定代币顺序
        bool isToken0 = pairContract.token0() == token;
        
        if (isToken0) {
            // token 是 token0，WETH 是 token1
            // price = reserve1 / reserve0 = WETH / token
            currentPrice = (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            // token 是 token1，WETH 是 token0
            // price = reserve0 / reserve1 = WETH / token  
            currentPrice = (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }
    
    /**
     * @dev 获取代币的观察数据数量
     * @param token Meme 代币地址
     * @return 观察数据数量
     */
    function getObservationCount(address token) external view returns (uint256) {
        return observations[token].length;
    }
    
    /**
     * @dev 获取指定索引的观察数据
     * @param token Meme 代币地址
     * @param index 观察数据索引
     * @return timestamp 时间戳
     * @return price0CumulativeLast 累积价格0
     * @return price1CumulativeLast 累积价格1
     */
    function getObservation(address token, uint256 index) external view returns (
        uint32 timestamp,
        uint256 price0CumulativeLast,
        uint256 price1CumulativeLast
    ) {
        require(index < observations[token].length, "MemeTWAPOracle: index out of bounds");
        
        Observation memory obs = observations[token][index];
        return (obs.timestamp, obs.price0CumulativeLast, obs.price1CumulativeLast);
    }
    
    /**
     * @dev 批量添加多个代币的观察数据
     * @param tokens Meme 代币地址数组
     */
    function batchAddObservations(address[] calldata tokens) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            this.addObservation(tokens[i]);
        }
    }
    
    /**
     * @dev 获取代币相对于铸币价格的价格变化
     * @param token Meme 代币地址
     * @param period TWAP 计算周期
     * @return twapPrice TWAP 价格
     * @return mintPrice 铸币价格
     * @return priceChange 价格变化百分比（基点，10000 = 100%）
     */
    function getPriceChange(address token, uint32 period) external view returns (
        uint256 twapPrice,
        uint256 mintPrice,
        int256 priceChange
    ) {
        // 获取 TWAP 价格
        twapPrice = this.getTWAP(token, period);
        
        // 获取铸币价格
        (uint256 perMint, uint256 price,,,) = memeFactory.getTokenInfo(token);
        mintPrice = (price * 1e18) / perMint; // 转换为每个代币的 ETH 价格
        
        // 计算价格变化百分比
        if (mintPrice > 0) {
            priceChange = (int256(twapPrice) - int256(mintPrice)) * 10000 / int256(mintPrice);
        } else {
            priceChange = 0;
        }
    }
    
    /**
     * @dev 获取简化的价格信息（用于快速查询）
     * @param token Meme 代币地址
     * @return hasLiquidity 是否有流动性
     * @return currentPrice 当前价格
     * @return observationCount 观察数据数量
     */
    function getSimplePriceInfo(address token) external view returns (
        bool hasLiquidity,
        uint256 currentPrice,
        uint256 observationCount
    ) {
        // 检查是否有流动性池
        address pair = uniswapV2Factory.getPair(token, WETH);
        hasLiquidity = pair != address(0);
        
        if (hasLiquidity) {
            try this.getCurrentPrice(token) returns (uint256 price) {
                currentPrice = price;
            } catch {
                currentPrice = 0;
            }
        }
        
        observationCount = observations[token].length;
    }
    
    /**
     * @dev 获取多个代币的 TWAP 价格（批量查询）
     * @param tokens Meme 代币地址数组
     * @param period TWAP 计算周期
     * @return twapPrices TWAP 价格数组
     * @return success 成功标志数组
     */
    function getBatchTWAP(address[] calldata tokens, uint32 period) external view returns (
        uint256[] memory twapPrices,
        bool[] memory success
    ) {
        twapPrices = new uint256[](tokens.length);
        success = new bool[](tokens.length);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            try this.getTWAP(tokens[i], period) returns (uint256 price) {
                twapPrices[i] = price;
                success[i] = true;
            } catch {
                twapPrices[i] = 0;
                success[i] = false;
            }
        }
    }
    
    /**
     * @dev 检查代币是否可以计算 TWAP
     * @param token Meme 代币地址
     * @param period 所需的时间周期
     * @return canCalculate 是否可以计算
     * @return reason 不能计算的原因（如果适用）
     */
    function canCalculateTWAP(address token, uint32 period) external view returns (
        bool canCalculate,
        string memory reason
    ) {
        // 检查是否为有效的 Meme 代币
        if (memeFactory.tokenToIssuer(token) == address(0)) {
            return (false, "Invalid meme token");
        }
        
        // 检查周期是否足够长
        if (period < MIN_PERIOD) {
            return (false, "Period too short");
        }
        
        // 检查是否有足够的观察数据
        Observation[] storage tokenObservations = observations[token];
        if (tokenObservations.length < 2) {
            return (false, "Insufficient observations");
        }
        
        // 检查是否有足够时间跨度的观察数据
        Observation memory latestObs = tokenObservations[tokenObservations.length - 1];
        uint32 targetTimestamp = latestObs.timestamp - period;
        
        bool found = false;
        for (int256 i = int256(tokenObservations.length) - 2; i >= 0; i--) {
            if (tokenObservations[uint256(i)].timestamp <= targetTimestamp) {
                found = true;
                break;
            }
        }
        
        if (!found) {
            return (false, "No observation for the period");
        }
        
        return (true, "");
    }
}