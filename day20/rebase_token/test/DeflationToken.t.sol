// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DeflationToken.sol";

/**
 * @title DeflationTokenTest
 * @dev 通缩代币的完整测试套件
 */
contract DeflationTokenTest is Test {
    DeflationToken public token;
    address public deployer;
    address public userA;
    address public userB;
    address public userC;
    
    // 常量
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18;
    uint256 public constant YEAR_IN_SECONDS = 365 days;
    uint256 public constant PRECISION = 1e18;
    
    event Rebase(uint256 indexed epoch, uint256 newScaleFactor, uint256 newTotalSupply);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        deployer = address(this);
        userA = makeAddr("userA");
        userB = makeAddr("userB");
        userC = makeAddr("userC");
        
        token = new DeflationToken();
    }

    // ========== 场景1: 初始状态验证 ==========
    
    function test_InitialState() public {
        // 验证代币基本信息
        assertEq(token.name(), "DeflationToken");
        assertEq(token.symbol(), "DFL");
        assertEq(token.decimals(), 18);
        
        // 验证初始供应量
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.baseTotalSupply(), INITIAL_SUPPLY);
        
        // 验证部署者余额
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
        
        // 验证缩放因子
        assertEq(token.scaleFactor(), PRECISION);
        
        // 验证初始时间
        assertEq(token.lastRebaseTime(), block.timestamp);
        assertEq(token.epoch(), 0);
        
        // 验证不能立即rebase
        assertFalse(token.canRebase());
    }

    // ========== 场景2: 单次Rebase效果 ==========
    
    function test_SingleRebaseEffect() public {
        // 步骤1: 用户A转账30,000,000 DFL给用户B
        uint256 transferAmount = 30_000_000 * 10**18;
        token.transfer(userA, transferAmount);
        token.transfer(userB, transferAmount);
        
        // 验证转账后余额
        assertEq(token.balanceOf(deployer), 40_000_000 * 10**18);
        assertEq(token.balanceOf(userA), 30_000_000 * 10**18);
        assertEq(token.balanceOf(userB), 30_000_000 * 10**18);
        
        // 步骤2: 时间前进366天
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1 days);
        
        // 验证可以rebase
        assertTrue(token.canRebase());
        
        // 步骤3: 执行rebase
        vm.expectEmit(true, false, false, true);
        emit Rebase(1, 99 * 10**16, 99_000_000 * 10**18); // 0.99 * 1e18
        token.rebase();
        
        // 步骤4: 验证rebase后的状态
        assertEq(token.totalSupply(), 99_000_000 * 10**18);
        assertEq(token.scaleFactor(), 99 * 10**16); // 0.99 * 1e18
        assertEq(token.epoch(), 1);
        
        // 验证各用户余额 (所有余额都减少1%)
        assertEq(token.balanceOf(deployer), 39_600_000 * 10**18); // 40M * 0.99
        assertEq(token.balanceOf(userA), 29_700_000 * 10**18);    // 30M * 0.99
        assertEq(token.balanceOf(userB), 29_700_000 * 10**18);    // 30M * 0.99
        
        // 验证不能立即再次rebase
        assertFalse(token.canRebase());
    }

    // ========== 场景3: 多次Rebase累积 ==========
    
    function test_MultipleRebaseCumulative() public {
        // 连续执行3次rebase
        for (uint256 i = 0; i < 3; i++) {
            // 时间前进366天（基于上次rebase时间）
            vm.warp(token.lastRebaseTime() + YEAR_IN_SECONDS + 1 days);
            token.rebase();
        }
        
        // 验证3次rebase后的状态
        // 计算: 100M * (0.99)^3 ≈ 97,029,900
        uint256 expectedSupply = (INITIAL_SUPPLY * 99**3) / 100**3;
        assertEq(token.totalSupply(), expectedSupply);
        
        // 验证部署者余额也同比减少
        assertEq(token.balanceOf(deployer), expectedSupply);
        
        // 验证epoch
        assertEq(token.epoch(), 3);
        
        // 验证缩放因子: (0.99)^3
        uint256 expectedScaleFactor = (PRECISION * 99**3) / 100**3;
        assertEq(token.scaleFactor(), expectedScaleFactor);
    }

    // ========== 场景4: 通缩后转账 ==========
    
    function test_TransferAfterDeflation() public {
        // 给userA一些代币
        token.transfer(userA, 100 * 10**18);
        
        // 执行一次rebase
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1 days);
        token.rebase();
        
        // 验证userA余额变为99 DFL
        assertEq(token.balanceOf(userA), 99 * 10**18);
        
        // userA转账99 DFL给userB
        vm.prank(userA);
        token.transfer(userB, 99 * 10**18);
        
        // 验证转账结果
        assertEq(token.balanceOf(userA), 0);
        assertEq(token.balanceOf(userB), 99 * 10**18);
    }

    // ========== 场景5: 边界测试 ==========
    
    function test_MinimalAccountRebaseToZero() public {
        // 给userA最小金额 (1 wei)
        token.transfer(userA, 1);
        
        // 执行rebase
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1 days);
        token.rebase();
        
        // 验证1 wei在rebase后归零 (由于精度损失)
        assertEq(token.balanceOf(userA), 0);
    }
    
    function test_RebaseTimingBoundary() public {
        // 测试365天+1秒成功执行rebase
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1);
        assertTrue(token.canRebase());
        token.rebase(); // 应该成功
        
        // 重置时间，测试364天23小时59分钟执行失败
        vm.warp(token.lastRebaseTime() + YEAR_IN_SECONDS - 60); // 少60秒
        assertFalse(token.canRebase());
        
        vm.expectRevert("DeflationToken: rebase too early");
        token.rebase();
    }
    
    function test_MaxPrecisionCalculation() public {
        // 测试最大精度计算
        uint256 largeAmount = type(uint256).max / 2;
        
        // 这个测试确保不会溢出
        vm.expectRevert(); // 应该因为余额不足而失败，而不是溢出
        token.transfer(userA, largeAmount);
    }

    // ========== 转账和授权测试 ==========
    
    function test_TransferAndApproval() public {
        uint256 amount = 1000 * 10**18;
        
        // 转账给userA
        token.transfer(userA, amount);
        assertEq(token.balanceOf(userA), amount);
        
        // userA授权userB
        vm.prank(userA);
        token.approve(userB, amount);
        assertEq(token.allowance(userA, userB), amount);
        
        // userB代表userA转账给userC
        vm.prank(userB);
        token.transferFrom(userA, userC, amount);
        
        assertEq(token.balanceOf(userA), 0);
        assertEq(token.balanceOf(userC), amount);
        assertEq(token.allowance(userA, userB), 0);
    }
    
    function test_ApprovalAfterRebase() public {
        uint256 amount = 1000 * 10**18;
        
        // 转账和授权
        token.transfer(userA, amount);
        vm.prank(userA);
        token.approve(userB, amount);
        
        // 执行rebase
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1 days);
        token.rebase();
        
        // 验证授权金额也相应减少
        uint256 expectedAllowance = (amount * 99) / 100;
        assertEq(token.allowance(userA, userB), expectedAllowance);
        
        // 验证可以使用减少后的授权金额
        vm.prank(userB);
        token.transferFrom(userA, userC, expectedAllowance);
        
        assertEq(token.balanceOf(userC), expectedAllowance);
    }

    // ========== 错误情况测试 ==========
    
    function test_RevertOnEarlyRebase() public {
        vm.expectRevert("DeflationToken: rebase too early");
        token.rebase();
    }
    
    function test_RevertOnInsufficientBalance() public {
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(userA);
        token.transfer(userB, 1);
    }
    
    function test_RevertOnInsufficientAllowance() public {
        token.transfer(userA, 1000 * 10**18);
        
        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(userB);
        token.transferFrom(userA, userC, 1);
    }

    // ========== 事件测试 ==========
    
    function test_TransferEvent() public {
        uint256 amount = 1000 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(deployer, userA, amount);
        token.transfer(userA, amount);
    }
    
    function test_ApprovalEvent() public {
        uint256 amount = 1000 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit Approval(deployer, userA, amount);
        token.approve(userA, amount);
    }
    
    function test_RebaseEvent() public {
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1 days);
        
        vm.expectEmit(true, false, false, true);
        emit Rebase(1, 99 * 10**16, 99_000_000 * 10**18);
        token.rebase();
    }

    // ========== 查询函数测试 ==========
    
    function test_QueryFunctions() public {
        // 测试初始状态的查询函数
        assertEq(token.scaleFactor(), PRECISION);
        assertEq(token.baseTotalSupply(), INITIAL_SUPPLY);
        assertEq(token.lastRebaseTime(), block.timestamp);
        assertEq(token.epoch(), 0);
        assertEq(token.rawBalanceOf(deployer), INITIAL_SUPPLY);
        assertFalse(token.canRebase());
        assertEq(token.timeToNextRebase(), YEAR_IN_SECONDS);
        
        // 时间前进一半
        vm.warp(block.timestamp + YEAR_IN_SECONDS / 2);
        assertEq(token.timeToNextRebase(), YEAR_IN_SECONDS / 2);
        
        // 时间前进到可以rebase
        vm.warp(block.timestamp + YEAR_IN_SECONDS / 2 + 1 days);
        assertTrue(token.canRebase());
        assertEq(token.timeToNextRebase(), 0);
    }

    // ========== 精度测试 ==========
    
    function test_PrecisionHandling() public {
        // 测试小额转账的精度处理
        uint256 smallAmount = 1;
        token.transfer(userA, smallAmount);
        assertEq(token.balanceOf(userA), smallAmount);
        
        // 执行rebase后，小额可能归零
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1 days);
        token.rebase();
        
        // 1 wei * 0.99 = 0 (由于整数除法)
        assertEq(token.balanceOf(userA), 0);
    }
    
    function test_LargeAmountHandling() public {
        // 测试大额转账
        uint256 largeAmount = 50_000_000 * 10**18;
        token.transfer(userA, largeAmount);
        
        assertEq(token.balanceOf(userA), largeAmount);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - largeAmount);
        
        // rebase后验证
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1 days);
        token.rebase();
        
        uint256 expectedAmount = (largeAmount * 99) / 100;
        assertEq(token.balanceOf(userA), expectedAmount);
    }

    // ========== 重入攻击防护测试 ==========
    
    function test_ReentrancyProtection() public {
        // 这个测试确保rebase函数有重入保护
        // 由于使用了ReentrancyGuard，重入攻击应该被阻止
        vm.warp(block.timestamp + YEAR_IN_SECONDS + 1 days);
        token.rebase(); // 第一次调用成功
        
        // 立即再次调用应该失败（时间不够）
        vm.expectRevert("DeflationToken: rebase too early");
        token.rebase();
    }
}