package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
)

func main() {
	// 解析命令行参数
	port := flag.Int("port", 5000, "Port to run the server on")
	nodeID := flag.String("id", "node1", "Node ID")
	flag.Parse()

	// 创建网络和区块链
	network := NewNetwork()

	// 启动HTTP服务器
	go network.StartServer(*port)

	// 注册自己到网络
	if len(os.Args) > 1 && os.Args[1] == "--register" && len(os.Args) > 2 {
		// 在实际应用中，这里应该向其他节点注册自己
		// 这里简化为直接添加到自己的节点列表
		network.RegisterNode(*nodeID, fmt.Sprintf("localhost:%d", *port))
	}

	// 演示区块链功能
	demoBlockchain(network.blockchain)
}

func demoBlockchain(bc *Blockchain) {
	// 创建一些交易
	fmt.Println("创建交易...")
	bc.CreateTransaction("Alice", "Bob", 1.5)
	bc.CreateTransaction("Bob", "Charlie", 2.3)

	// 挖矿（创建新区块）
	fmt.Println("\n开始挖矿...")
	lastProof := bc.GetLastBlock().Proof
	_ = ProofOfWork(lastProof) // 计算工作量证明
	bc.Mine("miner-address")

	// 创建更多交易
	fmt.Println("\n创建更多交易...")
	bc.CreateTransaction("Charlie", "Alice", 0.7)
	bc.CreateTransaction("Alice", "David", 0.3)

	// 再次挖矿
	fmt.Println("\n再次挖矿...")
	lastProof = bc.GetLastBlock().Proof
	_ = ProofOfWork(lastProof) // 计算工作量证明
	bc.Mine("miner-address")

	// 打印区块链信息
	fmt.Println("\n区块链信息:")
	for i, block := range bc.Chain {
		blockJSON, _ := json.MarshalIndent(block, "", "  ")
		fmt.Printf("区块 %d:\n%s\n", i, string(blockJSON))
	}

	// 验证区块链
	fmt.Println("\n验证区块链是否有效:", bc.IsChainValid())

	// 尝试篡改区块链
	if len(bc.Chain) > 1 {
		// 修改第二个区块中的交易
		bc.Chain[1].Transactions[0].Amount = 100.0
		// 重新计算哈希值（但不会更新后续区块的PreviousHash）
		bc.Chain[1].Hash = bc.Chain[1].CalculateHash()
	}

	// 再次验证区块链
	fmt.Println("修改后验证区块链是否有效:", bc.IsChainValid())

	// 等待用户输入以保持程序运行
	fmt.Println("\n按Enter键退出...")
	fmt.Scanln()
}
