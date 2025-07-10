package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
)

// Node 表示网络中的一个节点
type Node struct {
	ID        string   `json:"id"`
	Addresses []string `json:"addresses"`
}

// Network 表示P2P网络
type Network struct {
	nodes    map[string]*Node
	blockchain *Blockchain
	sync.RWMutex
}

// NewNetwork 创建新的网络
func NewNetwork() *Network {
	return &Network{
		nodes:     make(map[string]*Node),
		blockchain: NewBlockchain(),
	}
}

// RegisterNode 注册新节点
func (n *Network) RegisterNode(nodeID, address string) {
	n.Lock()
	defer n.Unlock()

	if _, exists := n.nodes[nodeID]; !exists {
		n.nodes[nodeID] = &Node{
			ID:        nodeID,
			Addresses: []string{address},
		}
	} else {
		// 添加新地址（如果不存在）
		for _, addr := range n.nodes[nodeID].Addresses {
			if addr == address {
				return
			}
		}
		n.nodes[nodeID].Addresses = append(n.nodes[nodeID].Addresses, address)
	}
}

// ResolveConflicts 使用最长链规则解决冲突
func (n *Network) ResolveConflicts() bool {
	n.Lock()
	defer n.Unlock()

	maxLength := len(n.blockchain.Chain)
	var newChain []*Block

	// 从所有节点获取区块链
	for _, node := range n.nodes {
		for _, addr := range node.Addresses {
			resp, err := http.Get(fmt.Sprintf("http://%s/chain", addr))
			if err != nil {
				continue
			}
			defer resp.Body.Close()

			var chainResp struct {
				Chain  []*Block `json:"chain"`
				Length int      `json:"length"`
			}

			if err := json.NewDecoder(resp.Body).Decode(&chainResp); err != nil {
				continue
			}

			// 检查是否是最长链
			if chainResp.Length > maxLength && n.blockchain.IsChainValid() {
				maxLength = chainResp.Length
				newChain = chainResp.Chain
			}
		}
	}

	// 如果找到更长的有效链，则替换当前链
	if newChain != nil {
		n.blockchain.Chain = newChain
		return true
	}

	return false
}

// StartServer 启动HTTP服务器
func (n *Network) StartServer(port int) {
	http.HandleFunc("/mine", func(w http.ResponseWriter, r *http.Request) {
		n.Lock()
		defer n.Unlock()

		// 挖矿
		block := n.blockchain.Mine("miner-address")

		response := struct {
			Message string `json:"message"`
			Block   *Block `json:"block"`
		}{
			Message: "New Block Mined",
			Block:   block,
		}

		sendJSON(w, http.StatusOK, response)
	})

	http.HandleFunc("/transactions/new", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var tx Transaction
		if err := json.NewDecoder(r.Body).Decode(&tx); err != nil {
			http.Error(w, "Invalid transaction data", http.StatusBadRequest)
			return
		}

		n.Lock()
		n.blockchain.CreateTransaction(tx.Sender, tx.Recipient, tx.Amount)
		n.Unlock()

		response := struct {
			Message string `json:"message"`
		}{
			Message: "Transaction will be added to the next block",
		}

		sendJSON(w, http.StatusCreated, response)
	})

	http.HandleFunc("/chain", func(w http.ResponseWriter, r *http.Request) {
		n.RLock()
		defer n.RUnlock()

		response := struct {
			Chain  []*Block `json:"chain"`
			Length int      `json:"length"`
		}{
			Chain:  n.blockchain.Chain,
			Length: len(n.blockchain.Chain),
		}

		sendJSON(w, http.StatusOK, response)
	})

	http.HandleFunc("/nodes/register", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var data struct {
			NodeID  string   `json:"node_id"`
			Address string   `json:"address"`
		}

		if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
			http.Error(w, "Invalid data", http.StatusBadRequest)
			return
		}

		n.RegisterNode(data.NodeID, data.Address)

		response := struct {
			Message string   `json:"message"`
			Total   int      `json:"total_nodes"`
			Nodes   []string `json:"nodes"`
		}{
			Message: "New nodes have been added",
			Total:   len(n.nodes),
		}

		// 收集所有节点ID
		for id := range n.nodes {
			response.Nodes = append(response.Nodes, id)
		}

		sendJSON(w, http.StatusCreated, response)
	})

	// 启动服务器
	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("Starting server on port %d\n", port)
	http.ListenAndServe(addr, nil)
}

func sendJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
