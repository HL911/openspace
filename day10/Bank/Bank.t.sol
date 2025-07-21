// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    
    // 测试用地址
    address public admin = 0xB6924ca382D64CbA2E31DfCD3892AE2a3D9377a4;  // 管理员地址
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);
    address public user4 = address(5);

    function setUp() public {
        // 使用 vm.prank 设置 msg.sender 为管理员地址
        vm.prank(admin);
        bank = new Bank();
        
        // 给测试账户分配测试币
        deal(admin, 1000 ether);
        deal(user1, 1000 ether);
        deal(user2, 1000 ether);
        deal(user3, 1000 ether);
        deal(user4, 1000 ether);
    }

    // 辅助函数：检查 top 排行榜
    function _checkTopAddresses(
        address first, uint256 firstAmount,
        address second, uint256 secondAmount,
        address third, uint256 thirdAmount
    ) internal view {
        (address addr1, uint256 amount1) = bank.topAddresses(0);
        (address addr2, uint256 amount2) = bank.topAddresses(1);
        (address addr3, uint256 amount3) = bank.topAddresses(2);

        if (first != address(0)) {
            assertEq(addr1, first, "First place address mismatch");
            assertEq(amount1, firstAmount, "First place amount mismatch");
        }
        if (second != address(0)) {
            assertEq(addr2, second, "Second place address mismatch");
            assertEq(amount2, secondAmount, "Second place amount mismatch");
        }
        if (third != address(0)) {
            assertEq(addr3, third, "Third place address mismatch");
            assertEq(amount3, thirdAmount, "Third place amount mismatch");
        }
    }

    // 测试单个用户存款
    function test_SingleUserDeposit() public {
        vm.prank(user1);
        bank.deposit{value: 100 ether}();
        
        _checkTopAddresses(
            user1, 100 ether,
            address(0), 0,
            address(0), 0
        );
    }

    // 测试两个用户存款
    function test_TwoUsersDeposit() public {
        // 用户1存款
        vm.prank(user1);
        bank.deposit{value: 50 ether}();
        
        // 用户2存款（金额更大）
        vm.prank(user2);
        bank.deposit{value: 100 ether}();
        
        _checkTopAddresses(
            user2, 100 ether,
            user1, 50 ether,
            address(0), 0
        );
    }

    // 测试三个用户存款
    function test_ThreeUsersDeposit() public {
        // 用户1存款
        vm.prank(user1);
        bank.deposit{value: 100 ether}();
        
        // 用户2存款（金额最大）
        vm.prank(user2);
        bank.deposit{value: 200 ether}();
        
        // 用户3存款（金额中等）
        vm.prank(user3);
        bank.deposit{value: 150 ether}();
        _checkTopAddresses(
            user2, 200 ether,  // 第一名
            user3, 150 ether,  // 第二名
            user1, 100 ether   // 第三名
        );
    }

    // 测试四个用户存款，检查前三名
    function test_FourUsersDeposit() public {
        // 用户1存款（第四名）
        vm.prank(user1);
        bank.deposit{value: 50 ether}();
        
        // 用户2存款（第二名）
        vm.prank(user2);
        bank.deposit{value: 150 ether}();
        
        // 用户3存款（第一名）
        vm.prank(user3);
        bank.deposit{value: 200 ether}();
        
        // 用户4存款（第三名）
        vm.prank(user4);
        bank.deposit{value: 100 ether}();
        
        _checkTopAddresses(
            user3, 200 ether,  // 第一名
            user2, 150 ether,  // 第二名
            user4, 100 ether   // 第三名
        );
        
        // 验证用户1不在前三名
        (address addr1, ) = bank.topAddresses(0);
        (address addr2, ) = bank.topAddresses(1);
        (address addr3, ) = bank.topAddresses(2);
        assertTrue(
            addr1 != user1 && 
            addr2 != user1 && 
            addr3 != user1, 
            "User1 should not be in top 3"
        );
    }

    // 测试同一用户多次存款
    function test_SameUserMultipleDeposits() public {
        // 第一次存款
        vm.prank(user1);
        bank.deposit{value: 50 ether}();
        
        _checkTopAddresses(
            user1, 50 ether,
            address(0), 0,
            address(0), 0
        );
        
        // 第二次存款（增加金额）
        vm.prank(user1);
        bank.deposit{value: 100 ether}();
        
        _checkTopAddresses(
            user1, 150 ether,  // 金额累加
            address(0), 0,
            address(0), 0
        );
        
        // 添加其他用户进行比较
        vm.prank(user2);
        bank.deposit{value: 100 ether}();
        
        _checkTopAddresses(
            user1, 150 ether,
            user2, 100 ether,
            address(0), 0
        );
        
        // 用户1再次存款，成为第一名
        vm.prank(user1);
        bank.deposit{value: 100 ether}();
        
        _checkTopAddresses(
            user1, 250 ether,  // 金额再次累加
            user2, 100 ether,
            address(0), 0
        );
    }

    // 测试管理员可以取款
    function test_AdminCanWithdraw() public {
        // 管理员先存入一些资金
        vm.prank(admin);
        // 记录初始余额
        uint256 initialBalance = admin.balance;
        bank.deposit{value: 100 ether}();
        
        // 管理员提取50 ether
        uint256 withdrawAmount = 50 ether;
        vm.prank(admin);
        bank.withdraw(withdrawAmount);
        
        // 验证余额更新
        assertEq(bank.balances(admin), 50 ether, "Admin balance should be reduced");
        
        // 验证用户收到的ETH
        assertEq(admin.balance, initialBalance - 100 ether + 50 ether, "Admin should receive the withdrawn ETH");
    }

    // 测试非管理员不能取款
    function test_NonAdminCannotWithdraw() public {
        // 管理员先存入一些资金
        vm.prank(admin);
        bank.deposit{value: 100 ether}();
        
        // 用户1尝试提取资金（非管理员）
        uint256 withdrawAmount = 50 ether;
        
        // 预期会失败，因为只有管理员可以取款
        vm.expectRevert("Only owner can withdraw");
        vm.prank(user1);
        bank.withdraw(withdrawAmount);
    }

    // 测试不能提取超过余额
    function test_CannotWithdrawMoreThanBalance() public {
        // 管理员先存入一些资金
        vm.prank(admin);
        bank.deposit{value: 100 ether}();
        
        // 尝试提取超过余额的金额
        uint256 withdrawAmount = 200 ether;
        
        // 预期会失败，因为提取金额超过余额
        vm.expectRevert("Insufficient balance");
        vm.prank(admin);
        bank.withdraw(withdrawAmount);
    }

}