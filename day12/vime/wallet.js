import { createWalletClient, http, createPublicClient, formatEther } from 'viem';
import { privateKeyToAccount, generatePrivateKey } from 'viem/accounts';
import { mainnet } from 'viem/chains';
import dotenv from 'dotenv';
import { createObjectCsvWriter } from 'csv-writer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config();

// 配置
const config = {
    rpcUrl: process.env.RPC_URL || 'https://eth.llamarpc.com',
    privateKey: process.env.PRIVATE_KEY
};

// 创建钱包客户端
const walletClient = createWalletClient({
    chain: mainnet,
    transport: http(config.rpcUrl)
});

// 1. 生成新私钥和地址
export async function generateWallet() {
    const privateKey = generatePrivateKey();
    const account = privateKeyToAccount(privateKey);
    const walletInfo = {
        privateKey: privateKey,
        address: account.address,
        createdAt: new Date().toISOString()
    };
    
    // 保存到CSV
    await saveWalletToCsv(walletInfo);
    
    return walletInfo;
}

// 2. 查询余额
export async function getBalance(address) {
    try {
        const publicClient = createPublicClient({
            chain: mainnet,
            transport: http(config.rpcUrl)
        });
        
        const balance = await publicClient.getBalance({
            address: address
        });
        
        return {
            wei: balance.toString(),
            eth: parseFloat(formatEther(balance))
        };
    } catch (error) {
        console.error('获取余额失败:', error);
        throw error;
    }
}

// 3. 保存钱包信息到CSV
async function saveWalletToCsv(walletInfo) {
    const csvPath = path.join(__dirname, 'wallets.csv');
    const fileExists = fs.existsSync(csvPath);
    
    const csvWriter = createObjectCsvWriter({
        path: csvPath,
        header: [
            {id: 'address', title: 'Address'},
            {id: 'privateKey', title: 'Private Key'},
            {id: 'createdAt', title: 'Created At'}
        ],
        append: fileExists
    });
    
    await csvWriter.writeRecords([walletInfo]);
}

// 4. 从CSV读取所有钱包
export async function readWalletsFromCsv() {
    const csvPath = path.join(__dirname, 'wallets.csv');
    
    if (!fs.existsSync(csvPath)) {
        return [];
    }
    
    const csv = await fs.promises.readFile(csvPath, 'utf-8');
    const lines = csv.split('\n').filter(line => line.trim() !== '');
    
    if (lines.length <= 1) return []; // 只有标题行
    
    const headers = lines[0].split(',');
    return lines.slice(1).map(line => {
        const values = line.split(',');
        return headers.reduce((obj, header, index) => {
            obj[header.trim()] = values[index] ? values[index].trim() : '';
            return obj;
        }, {});
    });
}

// 3. 从私钥获取地址
export function getAddressFromPrivateKey(privateKey) {
    try {
        const account = privateKeyToAccount(privateKey);
        return account.address;
    } catch (error) {
        console.error('从私钥获取地址失败:', error);
        throw error;
    }
}
