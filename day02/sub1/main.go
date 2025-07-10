package main

import (
	"fmt"
	"math/big"
)

// weiToEth 将wei转换为ETH
func weiToEth(wei *big.Int) *big.Float {
	// 1 ETH = 10^18 wei
	return new(big.Float).Quo(new(big.Float).SetInt(wei), big.NewFloat(1e18))
}

// gweiToWei 将gwei转换为wei
func gweiToWei(gwei float64) *big.Int {
	// 1 gwei = 10^9 wei
	gweiBig := new(big.Float).SetFloat64(gwei)
	weiFloat := new(big.Float).Mul(gweiBig, big.NewFloat(1e9))

	weiInt := new(big.Int)
	weiFloat.Int(weiInt) // 转换为整数部分
	return weiInt
}

// 计算gas费用
func main() {
	// 定义gas价格（以gwei为单位）
	gasPriceGwei := 0.000000002 // 2 gwei
	// 定义gas限制
	gasLimit := uint64(195268)

	// 将gas价格从gwei转换为wei
	gasPriceWei := gweiToWei(gasPriceGwei)

	// 计算总gas费用（以wei为单位）
	totalGasWei := new(big.Int).Mul(gasPriceWei, new(big.Int).SetUint64(gasLimit))

	// 将wei转换为ETH
	totalGasEth := weiToEth(totalGasWei)

	// 输出结果
	fmt.Printf("Gas价格: %.18f gwei\n", gasPriceGwei)
	fmt.Printf("Gas价格: %s wei\n", gasPriceWei.String())
	fmt.Printf("Gas限制: %d\n", gasLimit)
	fmt.Printf("总Gas费用: %s wei\n", totalGasWei.String())
	fmt.Printf("总Gas费用: %.19f ETH\n", totalGasEth)
}
