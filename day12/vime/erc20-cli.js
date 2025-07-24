import readline from 'readline';
import { sendERC20Transfer, getTokenBalance } from './erc20.js';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

async function main() {
    console.log('=== ERC20 代币转账工具 ===');
    
    while (true) {
        console.log('\n请选择操作:');
        console.log('1. 发送 ERC20 代币');
        console.log('2. 查询代币余额');
        console.log('3. 查看发送方账户余额');
        console.log('4. 退出');
        
        const choice = await new Promise(resolve => {
            rl.question('请输入选项 (1-4): ', resolve);
        });
        
        try {
            switch (choice) {
                case '1': {
                    const tokenAddress = await new Promise(resolve => {
                        rl.question('请输入代币合约地址: ', resolve);
                    });
                    
                    const toAddress = await new Promise(resolve => {
                        rl.question('请输入接收地址: ', resolve);
                    });
                    
                    const amount = await new Promise(resolve => {
                        rl.question('请输入转账数量 (单位: wei): ', resolve);
                    });
                    
                    console.log('\n发送中，请稍候...');
                    await sendERC20Transfer(tokenAddress, toAddress, amount);
                    break;
                }
                
                case '2': {
                    const tokenAddress = await new Promise(resolve => {
                        rl.question('请输入代币合约地址: ', resolve);
                    });
                    
                    const address = await new Promise(resolve => {
                        rl.question('请输入要查询的地址: ', resolve);
                    });
                    
                    console.log('\n查询中，请稍候...');
                    const balance = await getTokenBalance(tokenAddress, address);
                    console.log(`\n地址 ${address} 的代币余额: ${balance} wei`);
                    break;
                }
                
                case '3': {
                    const tokenAddress = await new Promise(resolve => {
                        rl.question('请输入代币合约地址: ', resolve);
                    });
                    
                    console.log('\n查询中，请稍候...');
                    // 获取发送方账户地址
                    const { getAccount } = await import('./erc20.js');
                    const account = getAccount();
                    const balance = await getTokenBalance(tokenAddress, account.address);
                    console.log(`\n发送方账户 ${account.address} 的代币余额: ${balance} wei`);
                    break;
                }
                
                case '4':
                    console.log('感谢使用，再见！');
                    rl.close();
                    process.exit(0);
                
                default:
                    console.log('无效的选项，请重新输入。');
            }
        } catch (error) {
            console.error('错误:', error.message);
        }
    }
}

// 检查环境变量
if (!process.env.PRIVATE_KEY) {
    console.error('错误: 请先在 .env 文件中设置 PRIVATE_KEY');
    process.exit(1);
}

main().catch(console.error);
