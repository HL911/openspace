import {createPublicClient, http} from "viem"
import {sepolia} from "viem/chains"
import dotenv from "dotenv"
import NFTMarketABI from './abi/NFTMarket.json' assert { type: 'json' }

dotenv.config();

const publicClient = createPublicClient({
    chain: sepolia,
    transport: http()
})

const contractAddress = "0x4c375836912a872989f504c81b90d14272d249ba"
let isListening = true
// 手动开始监听函数
const startListening = async () => {
    // 监听 NFT 上架事件
    publicClient.watchContractEvent({
        address: contractAddress,
        abi:NFTMarketABI,
        eventName: "NFTListed",
        onLogs: async (logs) => {
            try {
              for (const log of logs) {
                const block = await publicClient.getBlock({ blockNumber: log.blockNumber })
                console.log('📝 NFT 上架事件:', {
                  listingId: log.args.listingId.toString(),
                  seller: log.args.seller,
                  nftContract: log.args.nftContract,
                  tokenId: log.args.tokenId.toString(),
                  price: log.args.price.toString(),
                  transactionHash: log.transactionHash,
                  timestamp: new Date(Number(block.timestamp) * 1000).toLocaleString()
                })
              }
            } catch (error) {
              console.error('❌ 处理上架事件时出错:', error)
            }
          },
          onError: (error) => {
            console.error('🔌 上架事件监听连接错误:', error)
            console.log('🔄 尝试重新连接...')
            // 延迟重连，避免频繁重连
            setTimeout(() => {
              if (isListening) {
                console.log('🔄 重新启动上架事件监听')
                startListening()
              }
            }, 3000)
          }
    })

    // 监听 NFT 售出事件
    publicClient.watchContractEvent({
        address: contractAddress,
        abi: NFTMarketABI,
        eventName: 'NFTSold',
        onLogs: async (logs) => {
          try {
            for (const log of logs) {
              const block = await publicClient.getBlock({ blockNumber: log.blockNumber })
              console.log('💰 NFT 售出事件:', {
                listingId: log.args.listingId.toString(),
                buyer: log.args.buyer,
                seller: log.args.seller,
                nftContract: log.args.nftContract,
                tokenId: log.args.tokenId.toString(),
                price: log.args.price.toString(),
                transactionHash: log.transactionHash,
                timestamp: new Date(Number(block.timestamp) * 1000).toLocaleString()
              })
            }
          } catch (error) {
            console.error('❌ 处理售出事件时出错:', error)
          }
        },
        onError: (error) => {
          console.error('🔌 售出事件监听连接错误:', error)
          console.log('🔄 尝试重新连接...')
          setTimeout(() => {
            if (isListening) {
              console.log('🔄 重新启动售出事件监听')
              startListening()
            }
          }, 3000)
        }
    })

    // 监听 NFT 取消上架事件
    publicClient.watchContractEvent({
        address: contractAddress,
          abi: NFTMarketABI,
          eventName: 'NFTListingCancelled',
          onLogs: async (logs) => {
            try {
              for (const log of logs) {
                const block = await publicClient.getBlock({ blockNumber: log.blockNumber })
                console.log('❌ NFT 取消上架事件:', {
                  listingId: log.args.listingId.toString(),
                  transactionHash: log.transactionHash,
                  timestamp: new Date(Number(block.timestamp) * 1000).toLocaleString()
                })
              }
            } catch (error) {
              console.error('❌ 处理取消事件时出错:', error)
            }
          },
          onError: (error) => {
            console.error('🔌 取消事件监听连接错误:', error)
            console.log('🔄 尝试重新连接...')
            setTimeout(() => {
              if (isListening) {
                console.log('🔄 重新启动取消事件监听')
                startListening()
              }
            }, 3000)
          }
    })
}

console.log('🚀 开始监听 NFT 市场事件...')
startListening()

// 优雅关闭处理
process.on('SIGINT', () => {
  console.log('\n🛑 停止监听...')
  isListening = false
  process.exit(0)
})
