import { createWalletClient, http, createPublicClient, formatEther, encodeFunctionData, getContract } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import MyTokenABI from './MyToken.json' assert { type: 'json' };
import dotenv from 'dotenv';

dotenv.config();

// 配置
const config = {
    rpcUrl: process.env.RPC_URL || 'https://eth.llamarpc.com',
    privateKey: process.env.PRIVATE_KEY
};

// 创建客户端
const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(config.rpcUrl)
});

const walletClient = createWalletClient({
    chain: sepolia,
    transport: http(config.rpcUrl)
});

// 获取账户
export function getAccount() {
    if (!config.privateKey) {
        throw new Error('请设置 .env 文件中的 PRIVATE_KEY');
    }
    return privateKeyToAccount(config.privateKey);
}


/**
 * 发送 ERC20 转账交易
 * @param {string} tokenAddress - ERC20 代币合约地址
 * @param {string} to - 接收地址
 * @param {string} amount - 转账数量（单位：wei）
 * @returns {Promise<string>} 交易哈希
 */
export async function sendERC20Transfer(tokenAddress, to, amount) {
    try {
        const account = getAccount();
        
        // 创建合约实例
        const contract = getContract({
            address: tokenAddress,
            abi: MyTokenABI,
            client: { public: publicClient, wallet: walletClient }
        });
        
        // 使用合约实例直接发送交易
        const hash = await contract.write.transfer([to, amount], {
            account,
        });
        
        console.log(`交易已发送！`);
        console.log(`从: ${account.address}`);
        console.log(`到: ${to}`);
        console.log(`数量: ${amount} wei`);
        console.log(`交易哈希: ${hash}`);
        console.log(`在浏览器查看: https://sepolia.etherscan.io/tx/${hash}`);
        
        // 等待交易确认
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        console.log('交易已确认:', receipt.status === 'success' ? '成功' : '失败');
        
        return hash;
    } catch (error) {
        // 简化错误信息显示
        if (error.message.includes('Insufficient balance')) {
            console.error('发送交易失败: 账户代币余额不足');
        } else if (error.message.includes('Invalid parameters')) {
            console.error('发送交易失败: 交易参数无效');
        } else if (error.message.includes('nonce too low')) {
            console.error('发送交易失败: nonce 值过低，请稍后重试');
        } else if (error.message.includes('gas')) {
            console.error('发送交易失败: gas 费用相关错误');
        } else {
            console.error('发送交易失败:', error.message || '未知错误');
        }
        throw new Error(error.message.includes('Insufficient balance') ? '账户代币余额不足' : error.message);
    }
}

/**
 * 获取 ERC20 代币余额
 * @param {string} tokenAddress - ERC20 代币合约地址
 * @param {string} address - 要查询的地址
 * @returns {Promise<string>} 代币余额（wei）
 */
export async function getTokenBalance(tokenAddress, address) {
    try {
        const data = encodeFunctionData({
            abi: MyTokenABI,
            functionName: 'balanceOf',
            args: [address]
        });
        
        const result = await publicClient.call({
            to: tokenAddress,
            data: data // viem 原生 encodeFunctionData 直接返回十六进制字符串
        });
        
        if (!result.data || result.data === '0x') {
            return '0';
        }
        
        // 将十六进制余额转换为十进制字符串
        return BigInt(result.data).toString();
    } catch (error) {
        console.error('查询代币余额失败:', error);
        throw error;
    }
}


