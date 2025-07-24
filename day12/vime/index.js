import { generateWallet, getBalance, getAddressFromPrivateKey, readWalletsFromCsv } from './wallet.js';
import readline from 'readline';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

async function main() {
    console.log('=== Viem.js 钱包工具 ===');
    
    while (true) {
        console.log('\n请选择操作:');
        console.log('1. 生成新钱包');
        console.log('2. 查询余额');
        console.log('3. 从私钥获取地址');
        console.log('4. 查看所有钱包');
        console.log('5. 退出');
        
        const choice = await new Promise(resolve => {
            rl.question('请输入选项 (1-4): ', resolve);
        });
        
        try {
            switch (choice) {
                case '1': {
                    const wallet = await generateWallet();
                    console.log('\n=== 新钱包已生成 ===');
                    console.log('地址:', wallet.address);
                    console.log('私钥:', wallet.privateKey);
                    console.log('警告: 请安全保存您的私钥，不要与他人分享！');
                    break;
                }
                
                case '2': {
                    const address = await new Promise(resolve => {
                        rl.question('请输入要查询的地址: ', resolve);
                    });
                    const balance = await getBalance(address);
                    console.log(`\n地址 ${address} 的余额:`);
                    console.log(`ETH: ${balance.eth}`);
                    console.log(`Wei: ${balance.wei}`);
                    break;
                }
                
                case '3': {
                    const privateKey = await new Promise(resolve => {
                        rl.question('请输入私钥: ', resolve);
                    });
                    const address = getAddressFromPrivateKey(privateKey);
                    console.log(`\n私钥对应的地址: ${address}`);
                    break;
                }
                
                case '4': {
                    console.log('\n=== 已保存的钱包列表 ===');
                    const wallets = await readWalletsFromCsv();
                    if (wallets.length === 0) {
                        console.log('没有找到已保存的钱包');
                    } else {
                        wallets.forEach((wallet, index) => {
                            console.log(`\n钱包 #${index + 1}:`);
                            console.log(`地址: ${wallet.Address}`);
                            console.log(`创建时间: ${wallet['Created At']}`);
                            console.log('------------------------');
                        });
                    }
                    break;
                }
                
                case '5':
                    console.log('感谢使用，再见！');
                    rl.close();
                    process.exit(0);
                
                default:
                    console.log('无效的选项，请重新输入。');
            }
        } catch (error) {
            console.error('发生错误:', error.message);
        }
    }
}

main().catch(console.error);
