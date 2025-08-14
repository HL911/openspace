// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 模拟USDC代币
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        // 铸造1000万个USDC给部署者
        _mint(msg.sender, 10_000_000 * 10**decimals());
    }

    // 允许任何人铸造代币用于测试
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // 设置6位小数，与真实USDC一致
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}