package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

func main() {
	// 读取用户输入
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("请输入您的昵称（直接回车使用默认值'胡良'）: ")
	nickname, _ := reader.ReadString('\n')
	nickname = strings.TrimSpace(nickname)
	if nickname == "" {
		nickname = "胡良"
	}

	// 读取需要的0的个数
	var zeroCount int
	for {
		fmt.Print("请输入需要匹配的0的个数（1-10）: ")
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)
		count, err := strconv.Atoi(input)
		if err != nil || count < 1 || count > 10 {
			fmt.Println("输入无效，请输入1-10之间的数字")
			continue
		}
		zeroCount = count
		break
	}

	targetPrefix := strings.Repeat("0", zeroCount)
	nonce := 0
	startTime := time.Now()
	fmt.Printf("开始计算，目标：找到以%d个0开头的哈希值...\n", zeroCount)

	for {
		// 将昵称和nonce拼接成字符串
		data := fmt.Sprintf("%s%d", nickname, nonce)

		// 计算SHA-256哈希
		hash := sha256.Sum256([]byte(data))
		hashStr := hex.EncodeToString(hash[:])

		// 检查是否满足条件
		if len(hashStr) >= zeroCount && hashStr[:zeroCount] == targetPrefix {
			elapsed := time.Since(startTime)
			fmt.Printf("\n找到符合条件的哈希值！\n")
			fmt.Printf("输入字符串: %s\n", data)
			fmt.Printf("Hash值: %s\n", hashStr)
			fmt.Printf("计算次数: %d\n", nonce+1)
			fmt.Printf("耗时: %v\n", elapsed)
			break
		}

		nonce++

		// 每100万次输出一次进度
		if nonce%1000000 == 0 {
			fmt.Printf("\r已尝试 %d 次...", nonce)
		}
	}
}
