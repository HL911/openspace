// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenVesting.sol";
import "../src/MockERC20.sol";

contract TokenVestingTest is Test {
    TokenVesting public vesting;
    MockERC20 public token;
    
    address public owner = address(0x1);
    address public beneficiary = address(0x2);
    uint256 public constant TOTAL_AMOUNT = 1_000_000 * 10**18; // 100万代币
    
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署ERC20代币
        token = new MockERC20("Test Token", "TEST", TOTAL_AMOUNT * 2);
        
        // 部署Vesting合约
        vesting = new TokenVesting(
            beneficiary,
            address(token),
            TOTAL_AMOUNT,
            true // 可撤销
        );
        
        // 授权并初始化合约
        token.approve(address(vesting), TOTAL_AMOUNT);
        vesting.initialize();
        
        vm.stopPrank();
    }
    
    function testInitialState() public {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.token(), address(token));
        assertEq(vesting.totalAmount(), TOTAL_AMOUNT);
        assertEq(vesting.released(), 0);
        assertEq(vesting.revoked(), false);
        assertEq(vesting.getBalance(), TOTAL_AMOUNT);
        
        // 检查时间设置
        assertEq(vesting.start(), block.timestamp);
        assertEq(vesting.cliff(), block.timestamp + 365 days);
        assertEq(vesting.duration(), 730 days);
    }
    
    function testNoReleaseBeforeCliff() public {
        // Cliff期前不能释放任何代币
        assertEq(vesting.releasableAmount(), 0);
        
        // 尝试释放应该失败
        vm.expectRevert("TokenVesting: no tokens are due");
        vesting.release();
        
        // 时间推进到Cliff期前一天
        vm.warp(vesting.start() + 364 days);
        assertEq(vesting.releasableAmount(), 0);
    }
    
    function testReleaseAfterCliff() public {
        // 时间推进到Cliff期结束
        vm.warp(vesting.start() + 365 days);
        
        // 此时应该可以释放0代币（刚好到Cliff期结束）
        assertEq(vesting.releasableAmount(), 0);
        
        // 时间推进到第13个月的一半（Cliff期后15天）
        vm.warp(vesting.start() + 365 days + 15 days);
        
        // 计算预期释放量：15天 / 730天 * 总量
        uint256 expected = (TOTAL_AMOUNT * 15 days) / 730 days;
        assertApproxEqAbs(vesting.releasableAmount(), expected, 1e15); // 允许小误差
    }
    
    function testLinearVesting() public {
        // 时间推进到第18个月（Cliff期后5个月）
        vm.warp(vesting.start() + 365 days + 150 days);
        
        uint256 releasable = vesting.releasableAmount();
        uint256 expected = (TOTAL_AMOUNT * 150 days) / 730 days;
        assertApproxEqAbs(releasable, expected, 1e15);
        
        // 执行释放
        uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary);
        vesting.release();
        
        // 检查受益人余额增加
        assertApproxEqAbs(
            token.balanceOf(beneficiary) - beneficiaryBalanceBefore,
            expected,
            1e15
        );
        
        // 检查已释放量更新
        assertApproxEqAbs(vesting.released(), expected, 1e15);
        
        // 检查不能重复释放
        assertEq(vesting.releasableAmount(), 0);
    }
    
    function testFullVesting() public {
        // 时间推进到释放期结束（37个月后）
        vm.warp(vesting.start() + 365 days + 730 days);
        
        // 应该可以释放全部代币
        assertEq(vesting.releasableAmount(), TOTAL_AMOUNT);
        
        // 执行释放
        vesting.release();
        
        // 检查受益人获得全部代币
        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
        assertEq(vesting.released(), TOTAL_AMOUNT);
        assertEq(vesting.getBalance(), 0);
    }
    
    function testRevoke() public {
        // 时间推进到第18个月
        vm.warp(vesting.start() + 365 days + 150 days);
        
        uint256 releasable = vesting.releasableAmount();
        
        // 只有owner可以撤销
        vm.expectRevert();
        vm.prank(beneficiary);
        vesting.revoke();
        
        // owner撤销
        vm.prank(owner);
        vesting.revoke();
        
        // 检查状态
        assertTrue(vesting.revoked());
        
        // 撤销后，可释放量应该是总数量（因为撤销后_vestedAmount返回_totalAmount）
        assertEq(vesting.releasableAmount(), TOTAL_AMOUNT);
        
        // 不能重复撤销
        vm.expectRevert("TokenVesting: token already revoked");
        vm.prank(owner);
        vesting.revoke();
    }
    
    function testGetVestingInfo() public {
        // 时间推进到第18个月
        vm.warp(block.timestamp + 365 days + 150 days);
        
        (
            uint256 currentTime,
            uint256 cliffTime,
            uint256 vestingEndTime,
            uint256 totalLocked,
            uint256 alreadyReleased,
            uint256 currentReleasable,
            uint256 remainingLocked,
            bool isCliffPassed,
            bool isFullyVested
        ) = vesting.getVestingInfo();
        
        assertEq(currentTime, block.timestamp);
        assertEq(cliffTime, vesting.start() + 365 days);
        assertEq(vestingEndTime, vesting.start() + 365 days + 730 days);
        assertEq(totalLocked, TOTAL_AMOUNT);
        assertEq(alreadyReleased, 0);
        assertGt(currentReleasable, 0);
        assertTrue(isCliffPassed);
        assertFalse(isFullyVested);
    }
    
    function testMultipleReleases() public {
        // 第一次释放：第15个月
        vm.warp(vesting.start() + 365 days + 60 days);
        uint256 firstRelease = vesting.releasableAmount();
        vesting.release();
        
        // 第二次释放：第20个月
        vm.warp(vesting.start() + 365 days + 210 days);
        uint256 secondRelease = vesting.releasableAmount();
        vesting.release();
        
        // 检查总释放量
        assertApproxEqAbs(
            vesting.released(),
            firstRelease + secondRelease,
            1e15
        );
        
        // 检查受益人余额
        assertApproxEqAbs(
            token.balanceOf(beneficiary),
            firstRelease + secondRelease,
            1e15
        );
    }
}
