package main

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"os"
	"strings"
	"time"
)

// GenerateRSAKeyPair 生成指定长度的RSA密钥对
// bits: 密钥长度，建议2048或4096位
// saveToFile: 是否保存到文件
// 返回: 公钥PEM, 私钥PEM, 错误
func GenerateRSAKeyPair(bits int, saveToFile bool) ([]byte, []byte, error) {
	// 生成RSA密钥对
	privateKey, err := rsa.GenerateKey(rand.Reader, bits)
	if err != nil {
		return nil, nil, fmt.Errorf("生成RSA密钥对失败: %v", err)
	}

	// 编码私钥为PKCS#1格式
	privateKeyBytes := x509.MarshalPKCS1PrivateKey(privateKey)
	privateKeyPEM := pem.EncodeToMemory(
		&pem.Block{
			Type:  "RSA PRIVATE KEY",
			Bytes: privateKeyBytes,
		},
	)

	// 编码公钥为PKIX格式
	publicKeyBytes, err := x509.MarshalPKIXPublicKey(&privateKey.PublicKey)
	if err != nil {
		return nil, nil, fmt.Errorf("编码公钥失败: %v", err)
	}

	publicKeyPEM := pem.EncodeToMemory(
		&pem.Block{
			Type:  "PUBLIC KEY",
			Bytes: publicKeyBytes,
		},
	)

	// 如果需要保存到文件
	if saveToFile {
		err = os.WriteFile("private_key.pem", privateKeyPEM, 0600)
		if err != nil {
			return nil, nil, fmt.Errorf("保存私钥到文件失败: %v", err)
		}

		err = os.WriteFile("public_key.pem", publicKeyPEM, 0644)
		if err != nil {
			return nil, nil, fmt.Errorf("保存公钥到文件失败: %v", err)
		}
	}

	return publicKeyPEM, privateKeyPEM, nil
}

// SignMessage 使用私钥对消息进行签名
func SignMessage(privateKey *rsa.PrivateKey, message string) ([]byte, error) {
	hasher := sha256.New()
	hasher.Write([]byte(message))
	hash := hasher.Sum(nil)

	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, hash)
	if err != nil {
		return nil, fmt.Errorf("签名失败: %v", err)
	}

	return signature, nil
}

// VerifySignature 使用公钥验证签名
func VerifySignature(publicKey *rsa.PublicKey, message string, signature []byte) error {
	hasher := sha256.New()
	hasher.Write([]byte(message))
	hash := hasher.Sum(nil)

	return rsa.VerifyPKCS1v15(publicKey, crypto.SHA256, hash, signature)
}

// FindValidHash 查找符合条件的哈希值
func FindValidHash(nickname string, zeroCount int) (string, int64, string) {
	targetPrefix := strings.Repeat("0", zeroCount)
	iteration := 0
	var timestamp int64
	var data string
	var hashStr string

	for {
		// 获取当前时间戳（纳秒级）
		timestamp = time.Now().UnixNano()
		data = fmt.Sprintf("%s%d", nickname, timestamp)

		// 计算SHA-256哈希
		hash := sha256.Sum256([]byte(data))
		hashStr = hex.EncodeToString(hash[:])

		// 检查是否满足条件
		if len(hashStr) >= zeroCount && hashStr[:zeroCount] == targetPrefix {
			return data, timestamp, hashStr
		}

		iteration++

		// 每1000次输出一次进度
		if iteration%1000 == 0 {
			fmt.Printf("\r已尝试 %d 次...", iteration)
		}
	}
}

func main() {
	// 生成2048位的RSA密钥对
	fmt.Println("正在生成RSA 2048位密钥对...")
	publicKeyPEM, privateKeyPEM, err := GenerateRSAKeyPair(2048, true)
	if err != nil {
		fmt.Printf("生成密钥对失败: %v\n", err)
		return
	}

	// 解析私钥
	block, _ := pem.Decode(privateKeyPEM)
	if block == nil {
		fmt.Println("解析私钥PEM失败")
		return
	}

	privateKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		fmt.Printf("解析私钥失败: %v\n", err)
		return
	}

	// 解析公钥
	block, _ = pem.Decode(publicKeyPEM)
	if block == nil {
		fmt.Println("解析公钥PEM失败")
		return
	}

	pubInterface, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		fmt.Printf("解析公钥失败: %v\n", err)
		return
	}

	publicKey := pubInterface.(*rsa.PublicKey)

	// 查找符合条件的哈希值
	nickname := "胡良"
	zeroCount := 4
	fmt.Printf("\n正在查找以%d个0开头的哈希值...\n", zeroCount)

	data, timestamp, hashStr := FindValidHash(nickname, zeroCount)

	// 使用私钥签名
	signature, err := SignMessage(privateKey, data)
	if err != nil {
		fmt.Printf("签名失败: %v\n", err)
		return
	}

	// 验证签名
	err = VerifySignature(publicKey, data, signature)
	if err != nil {
		fmt.Printf("签名验证失败: %v\n", err)
		return
	}

	// 输出结果
	fmt.Println("\n\n===== 结果 =====")
	fmt.Printf("昵称: %s\n", nickname)
	fmt.Printf("时间戳: %d\n", timestamp)
	fmt.Printf("输入数据: %s\n", data)
	fmt.Printf("哈希值: %s\n", hashStr)
	fmt.Printf("签名: %x\n", signature)
	fmt.Println("签名验证成功！")
}
