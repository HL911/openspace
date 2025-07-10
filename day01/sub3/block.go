package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"strconv"
	"time"
)

// Transaction 表示一个交易
type Transaction struct {
	Sender    string  `json:"sender"`    // 发送方
	Recipient string  `json:"recipient"` // 接收方
	Amount    float64 `json:"amount"`    // 金额
}

// Block 表示区块链中的一个区块
type Block struct {
	Index        int           `json:"index"`         // 区块高度
	Timestamp    int64         `json:"timestamp"`     // 时间戳
	Transactions []Transaction `json:"transactions"`  // 交易列表
	Proof        int64         `json:"proof"`         // 工作量证明
	PreviousHash string        `json:"previous_hash"` // 前一个区块的哈希
	Hash         string        `json:"hash"`          // 当前区块的哈希
}

// ToJSON 将区块转换为JSON字符串
func (b *Block) ToJSON() (string, error) {
	data, err := json.MarshalIndent(b, "", "  ")
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// FromJSON 从JSON字符串解析区块
func (b *Block) FromJSON(data []byte) error {
	return json.Unmarshal(data, b)
}

// Blockchain 表示区块链
type Blockchain struct {
	Chain        []*Block     `json:"chain"`         // 区块链
	Transactions []Transaction `json:"pending_transactions"` // 待处理交易
}

// ToJSON 将区块链转换为JSON字符串
func (bc *Blockchain) ToJSON() (string, error) {
	data, err := json.MarshalIndent(bc, "", "  ")
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// FromJSON 从JSON字符串解析区块链
func (bc *Blockchain) FromJSON(data []byte) error {
	return json.Unmarshal(data, bc)
}

// GetChain 获取区块链的副本
func (bc *Blockchain) GetChain() []*Block {
	return bc.Chain
}

// GetPendingTransactions 获取待处理交易
func (bc *Blockchain) GetPendingTransactions() []Transaction {
	return bc.Transactions
}

// ClearPendingTransactions 清空待处理交易
func (bc *Blockchain) ClearPendingTransactions() {
	bc.Transactions = []Transaction{}
}

// NewBlock 创建新区块
func NewBlock(proof int64, previousHash string) *Block {
	block := &Block{
		Index:        0,
		Timestamp:    time.Now().Unix(),
		Transactions: []Transaction{},
		Proof:        proof,
		PreviousHash: previousHash,
	}
	block.Hash = block.CalculateHash()
	return block
}

// CalculateHash 计算区块的哈希值
func (b *Block) CalculateHash() string {
	hasher := sha256.New()
	record := strconv.Itoa(b.Index) +
		strconv.FormatInt(b.Timestamp, 10) +
		hashTransactions(b.Transactions) +
		strconv.FormatInt(b.Proof, 10) +
		b.PreviousHash
	hasher.Write([]byte(record))
	return hex.EncodeToString(hasher.Sum(nil))
}

// hashTransactions 计算交易列表的哈希值
func hashTransactions(transactions []Transaction) string {
	txHashes := ""
	for _, tx := range transactions {
		txData, _ := json.Marshal(tx)
		h := sha256.Sum256(txData)
		txHashes += hex.EncodeToString(h[:])
	}

	h := sha256.Sum256([]byte(txHashes))
	return hex.EncodeToString(h[:])
}

// ProofOfWork 工作量证明算法
func ProofOfWork(lastProof int64) int64 {
	var proof int64 = 0
	for !ValidProof(lastProof, proof) {
		proof++
	}
	return proof
}

// ValidProof 验证工作量证明
func ValidProof(lastProof, proof int64) bool {
	hasher := sha256.New()
	hasher.Write([]byte(strconv.FormatInt(lastProof, 10) + strconv.FormatInt(proof, 10)))
	hash := hex.EncodeToString(hasher.Sum(nil))
	return hash[:4] == "0000" // 要求哈希值以4个0开头
}

// NewBlockchain 创建新的区块链
func NewBlockchain() *Blockchain {
	bc := &Blockchain{
		Chain:        []*Block{},
		Transactions: []Transaction{},
	}

	// 创建创世区块
	bc.CreateGenesisBlock()
	return bc
}

// CreateGenesisBlock 创建创世区块
func (bc *Blockchain) CreateGenesisBlock() {
	genesisBlock := NewBlock(1, "0")
	bc.Chain = append(bc.Chain, genesisBlock)
}

// GetLastBlock 获取最后一个区块
func (bc *Blockchain) GetLastBlock() *Block {
	return bc.Chain[len(bc.Chain)-1]
}

// CreateTransaction 创建新交易
func (bc *Blockchain) CreateTransaction(sender, recipient string, amount float64) int {
	tx := Transaction{
		Sender:    sender,
		Recipient: recipient,
		Amount:    amount,
	}

	bc.Transactions = append(bc.Transactions, tx)
	return len(bc.Chain) // 返回将包含此交易的区块索引
}

// Mine 挖矿，创建新区块
func (bc *Blockchain) Mine(minerAddress string) *Block {
	// 获取最后一个区块
	lastBlock := bc.GetLastBlock()
	lastProof := lastBlock.Proof

	// 计算工作量证明
	proof := ProofOfWork(lastProof)

	// 给矿工奖励
	bc.CreateTransaction("network", minerAddress, 1.0)

	// 创建新区块
	block := &Block{
		Index:        lastBlock.Index + 1,
		Timestamp:    time.Now().Unix(),
		Transactions: bc.Transactions,
		Proof:        proof,
		PreviousHash: lastBlock.Hash,
	}

	// 计算新区块的哈希
	block.Hash = block.CalculateHash()

	// 将新区块添加到链上
	bc.Chain = append(bc.Chain, block)

	// 清空待处理交易
	bc.Transactions = []Transaction{}

	return block
}

// IsChainValid 验证区块链是否有效
func (bc *Blockchain) IsChainValid() bool {
	for i := 1; i < len(bc.Chain); i++ {
		currentBlock := bc.Chain[i]
		previousBlock := bc.Chain[i-1]

		// 验证当前区块的哈希值是否正确
		if currentBlock.Hash != currentBlock.CalculateHash() {
			return false
		}

		// 验证区块的PreviousHash是否等于前一个区块的哈希
		if currentBlock.PreviousHash != previousBlock.Hash {
			return false
		}

		// 验证工作量证明
		if !ValidProof(previousBlock.Proof, currentBlock.Proof) {
			return false
		}
	}
	return true
}
