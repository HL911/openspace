// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyErc20 is ERC20 {
    constructor() ERC20("MyErc20", "MYERC20") {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }
}