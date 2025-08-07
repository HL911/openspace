// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "./bank.sol";
contract BankAutomation is AutomationCompatibleInterface {

    Bank public immutable bankContract = Bank(0x08B3B96452ab26aB7E84b34397eEE3fE90361135);

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = bankContract.getContractBalance() >= bankContract.threshold();
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        require(bankContract.getContractBalance() >= bankContract.threshold(), "Threshold not met");
        bankContract.transferHalf();
    }
}