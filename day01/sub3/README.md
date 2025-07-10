# 简单区块链实现

这是一个使用 Go 语言实现的简单区块链，包含以下功能：

- 工作量证明（Proof of Work）
- 交易处理
- 区块链验证
- 简单的 P2P 网络
- RESTful API 接口

## 功能特点

- **区块**：包含索引、时间戳、交易列表、工作量证明、前一个区块的哈希和当前区块的哈希
- **区块链**：维护一个区块链，支持添加新区块和验证区块链的完整性
- **工作量证明**：使用简单的哈希碰撞算法实现工作量证明
- **交易**：支持创建和验证交易
- **网络**：简单的 P2P 网络实现，支持节点注册和区块链同步

## 快速开始

### 安装

确保已安装 Go 1.16 或更高版本。

### 运行节点

```bash
# 启动第一个节点（默认端口5000）
go run . -port 5000 -id node1

# 在另一个终端启动第二个节点，并注册到第一个节点
go run . -port 5001 -id node2 --register http://localhost:5000
```

### API 端点

- `GET /chain` - 获取整个区块链
- `GET /mine` - 挖矿（创建新区块）
- `POST /transactions/new` - 创建新交易
- `POST /nodes/register` - 注册新节点

### 创建交易

```bash
curl -X POST -H "Content-Type: application/json" -d '{
    "sender": "Alice",
    "recipient": "Bob",
    "amount": 1.5
}' "http://localhost:5000/transactions/new"
```

### 挖矿

```bash
curl "http://localhost:5000/mine"
```

### 查看区块链

```bash
curl "http://localhost:5000/chain"
```

## 项目结构

- `main.go` - 主程序入口
- `block.go` - 区块链核心实现
- `server.go` - HTTP 服务器和网络实现
- `README.md` - 项目说明文档

## 实现细节

### 工作量证明

使用简单的哈希碰撞算法，寻找一个数 `p` 使得 `hash(pp')` 的前 `n` 位为 0，其中 `p'` 是前一个区块的工作量证明。

### 区块链验证

验证每个区块的哈希值是否正确，以及前一个区块的哈希值是否匹配。

### 网络同步

节点可以注册到网络中，并使用最长链规则解决冲突。

## 许可证

MIT
