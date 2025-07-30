import { createPublicClient, http } from "viem";
import { sepolia } from 'viem/chains';

// 创建公共客户端
const publicClient = createPublicClient({
    chain: sepolia,
    transport: http()
});

// 合约地址 - 请替换为实际部署的合约地址
const CONTRACT_ADDRESS = "0x10df29ecfa89b63e891e029f1f045a7ffefa7a29";

// 读取 _locks 数组的所有元素
async function readLocksArray() {
    try {
        console.log("开始读取 _locks 数组...\n");

        // 首先读取数组长度（存储在 slot 0）
        const arrayLengthHex = await publicClient.getStorageAt({
            address: CONTRACT_ADDRESS,
            slot: "0x0"
        });
        
        const arrayLength = parseInt(arrayLengthHex, 16);
        console.log(`_locks 数组长度: ${arrayLength}\n`);

        if (arrayLength === 0) {
            console.log("数组为空");
            return;
        }

        // 计算动态数组元素的起始存储位置
        // 对于 slot 0 的动态数组，元素存储在 keccak256(0) 开始的位置
        const { keccak256, toHex } = await import('viem');
        const arrayStartSlot = keccak256(toHex(0, { size: 32 }));
        const arrayStartSlotBigInt = BigInt(arrayStartSlot);

        // 读取每个 LockInfo 结构体
        for (let i = 0; i < arrayLength; i++) {
            console.log(`读取 locks[${i}]:`);
            
            // 每个 LockInfo 结构体占用 3 个存储槽位
            // slot 0: user (address, 20 bytes)
            // slot 1: startTime (uint64, 8 bytes) 
            // slot 2: amount (uint256, 32 bytes)
            const baseSlot = arrayStartSlotBigInt + BigInt(i * 3);

            // 读取 user 地址
            const userSlot = "0x" + baseSlot.toString(16).padStart(64, '0');
            const userHex = await publicClient.getStorageAt({
                address: CONTRACT_ADDRESS,
                slot: userSlot
            });
            // 地址存储在低 20 字节中
            const user = "0x" + userHex.slice(-40);

            // 读取 startTime
            const startTimeSlot = "0x" + (baseSlot + 1n).toString(16).padStart(64, '0');
            const startTimeHex = await publicClient.getStorageAt({
                address: CONTRACT_ADDRESS,
                slot: startTimeSlot
            });
            const startTime = parseInt(startTimeHex, 16);

            // 读取 amount
            const amountSlot = "0x" + (baseSlot + 2n).toString(16).padStart(64, '0');
            const amountHex = await publicClient.getStorageAt({
                address: CONTRACT_ADDRESS,
                slot: amountSlot
            });
            const amount = BigInt(amountHex);

            // 格式化输出
            console.log(`locks[${i}]: user: ${user}, startTime: ${startTime}, amount: ${amount.toString()}`);
            console.log(""); // 空行分隔
        }

    } catch (error) {
        console.error("读取 _locks 数组时发生错误:", error);
    }
}

// 执行读取函数
readLocksArray();
