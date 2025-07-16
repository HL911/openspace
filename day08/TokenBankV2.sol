// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {TokenBank} from "./TokenBank.sol";
contract TokenBankV2 is TokenBank {
    constructor(address _token) TokenBank(_token) {
    }
    function tokensReceived(address from, uint256 value) public {
        balances[from] += value;
    }
}
