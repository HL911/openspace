// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/CallOption.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDT合约用于测试
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        _mint(msg.sender, 1000000 * 10**18); // 铸造100万USDT
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CallOptionTest is Test {
    CallOption public callOption;
    MockUSDT public usdt;
    
    address public owner;
    address public user1;
    address public user2;
    
    uint256 public constant STRIKE_PRICE = 3200 * 10**18; // 3200 USDT per ETH
    uint256 public constant EXPIRATION = 1735689600; // 2025-01-01 00:00:00 UTC
    uint256 public constant OPTION_PRICE = 100 * 10**18; // 100 USDT per option
    uint256 public constant DEPOSIT_AMOUNT = 10 ether; // 10 ETH
    
    // 事件定义
    event Deposited(uint256 amount, uint256 totalLocked);
    event LiquidityAdded(uint256 amount, uint256 totalLocked);
    event OptionPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event Exercised(address indexed user, uint256 amount, uint256 cost);
    event Expired(uint256 totalLocked);
    event EmergencyWithdraw(uint256 ethAmount, uint256 usdtAmount);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署Mock USDT
        usdt = new MockUSDT();
        
        // 使用owner地址部署期权合约
        vm.startPrank(owner);
        callOption = new CallOption(STRIKE_PRICE, EXPIRATION, OPTION_PRICE, address(usdt));
        vm.stopPrank();
        
        // 给用户分配USDT
        usdt.mint(user1, 100000 * 10**18); // 10万USDT
        usdt.mint(user2, 100000 * 10**18); // 10万USDT
        usdt.mint(owner, 100000 * 10**18); // 给owner也分配USDT
        
        // 给测试账户一些ETH
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testConstructor() public {
        assertEq(callOption.strikePrice(), STRIKE_PRICE);
        assertEq(callOption.expiration(), EXPIRATION);
        assertEq(callOption.optionPrice(), OPTION_PRICE);
        assertEq(address(callOption.usdt()), address(usdt));
        assertEq(callOption.totalLocked(), 0);
        assertEq(callOption.expired(), false);
        assertEq(callOption.owner(), owner);
    }

    function testDeposit() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit Deposited(DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);
        
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        assertEq(callOption.totalLocked(), DEPOSIT_AMOUNT);
        assertEq(address(callOption).balance, DEPOSIT_AMOUNT);
        // 注意：现在deposit不再铸造代币给owner
        assertEq(callOption.balanceOf(owner), 0);
        vm.stopPrank();
    }

    function testDepositOnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        vm.stopPrank();
    }

    function testDepositZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert("Deposit amount must be greater than 0");
        callOption.deposit{value: 0}();
        vm.stopPrank();
    }

    function testBuyOption() public {
        // 先存入ETH
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 用户购买期权
        vm.startPrank(user1);
        uint256 optionAmount = 2 ether;
        uint256 optionFee = optionAmount * OPTION_PRICE / 1 ether;
        
        usdt.approve(address(callOption), optionFee);
        
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);
        callOption.buyOption(optionAmount);
        
        assertEq(callOption.balanceOf(user1), optionAmount);
        assertEq(usdt.balanceOf(owner), ownerUsdtBefore + optionFee);
        assertEq(usdt.balanceOf(user1), 100000 * 10**18 - optionFee);
        
        vm.stopPrank();
    }
    
    function testExercise() public {
        // 先存入ETH
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 用户购买期权
        vm.startPrank(user1);
        uint256 optionAmount = 2 ether;
        uint256 optionFee = optionAmount * OPTION_PRICE / 1 ether;
        usdt.approve(address(callOption), optionFee);
        callOption.buyOption(optionAmount);
        
        // 用户行权
        uint256 exerciseAmount = 1 ether;
        uint256 usdtRequired = exerciseAmount * STRIKE_PRICE / 1 ether;
        
        usdt.approve(address(callOption), usdtRequired);
        
        uint256 ethBalanceBefore = user1.balance;
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);
        
        vm.expectEmit(true, true, true, true);
        emit Exercised(user1, exerciseAmount, usdtRequired);
        callOption.exercise(exerciseAmount);
        
        assertEq(user1.balance, ethBalanceBefore + exerciseAmount);
        assertEq(callOption.balanceOf(user1), optionAmount - exerciseAmount);
        assertEq(callOption.totalLocked(), DEPOSIT_AMOUNT - exerciseAmount);
        assertEq(usdt.balanceOf(owner), ownerUsdtBefore + usdtRequired);
        
        vm.stopPrank();
    }

    function testBuyOptionInsufficientUSDT() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.startPrank(user1);
        // 转走所有USDT
        usdt.transfer(user2, usdt.balanceOf(user1));
        
        vm.expectRevert("Insufficient USDT balance");
        callOption.buyOption(1 ether);
        vm.stopPrank();
    }
    
    function testExerciseInsufficientTokens() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(user1);
        vm.expectRevert("Insufficient option tokens");
        callOption.exercise(1 ether);
    }

    function testExerciseInsufficientUSDT() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 用户先购买期权
        vm.startPrank(user1);
        uint256 optionAmount = 1 ether;
        uint256 optionFee = optionAmount * OPTION_PRICE / 1 ether;
        usdt.approve(address(callOption), optionFee);
        callOption.buyOption(optionAmount);
        
        // 转走所有USDT，使其无法支付行权费用
        usdt.transfer(user2, usdt.balanceOf(user1));
        
        vm.expectRevert();
        callOption.exercise(optionAmount);
        vm.stopPrank();
    }
    
    function testExerciseInsufficientAllowance() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 用户先购买期权
        vm.startPrank(user1);
        uint256 optionAmount = 1 ether;
        uint256 optionFee = optionAmount * OPTION_PRICE / 1 ether;
        usdt.approve(address(callOption), optionFee);
        callOption.buyOption(optionAmount);
        
        // 用户有期权但没有授权足够的USDT用于行权
        vm.expectRevert("Insufficient USDT allowance");
        callOption.exercise(1 ether);
        vm.stopPrank();
    }

    function testExerciseAfterExpiration() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 用户先购买期权
        vm.startPrank(user1);
        uint256 optionAmount = 1 ether;
        uint256 optionFee = optionAmount * OPTION_PRICE / 1 ether;
        usdt.approve(address(callOption), optionFee);
        callOption.buyOption(optionAmount);
        
        // 时间快进到过期后
        vm.warp(EXPIRATION + 1);
        
        vm.expectRevert("Option has expired");
        callOption.exercise(1 ether);
        vm.stopPrank();
    }

    function testExpire() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 时间快进到过期后
        vm.warp(EXPIRATION + 1);
        
        uint256 ownerETHBefore = owner.balance;
        
        vm.prank(owner);
        callOption.expire();
        
        assertEq(callOption.expired(), true);
        assertEq(callOption.totalLocked(), 0);
        assertEq(address(callOption).balance, 0);
        assertEq(owner.balance, ownerETHBefore + DEPOSIT_AMOUNT);
    }

    function testExpireBeforeExpiration() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(owner);
        vm.expectRevert("Option has not expired yet");
        callOption.expire();
    }

    function testExpireOnlyOwner() public {
        vm.warp(EXPIRATION + 1);
        
        vm.startPrank(user1);
        vm.expectRevert();
        callOption.expire();
        vm.stopPrank();
    }

    function testIntrinsicValue() public {
        uint256 ethPrice1 = 3000 * 10**18; // 低于行权价
        uint256 ethPrice2 = 3500 * 10**18; // 高于行权价
        
        assertEq(callOption.intrinsicValue(ethPrice1), 0);
        assertEq(callOption.intrinsicValue(ethPrice2), 300 * 10**18);
    }

    function testIsInTheMoney() public {
        uint256 ethPrice1 = 3000 * 10**18; // 低于行权价
        uint256 ethPrice2 = 3500 * 10**18; // 高于行权价
        
        assertEq(callOption.isInTheMoney(ethPrice1), false);
        assertEq(callOption.isInTheMoney(ethPrice2), true);
    }

    function testTimeToExpiration() public {
        uint256 currentTime = block.timestamp;
        uint256 timeLeft = callOption.timeToExpiration();
        
        assertEq(timeLeft, EXPIRATION - currentTime);
        
        // 时间快进到过期后
        vm.warp(EXPIRATION + 1);
        assertEq(callOption.timeToExpiration(), 0);
    }

    function testAddLiquidity() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        uint256 ethAmount = 5 ether;
        uint256 totalLockedBefore = callOption.totalLocked();
        
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit LiquidityAdded(ethAmount, totalLockedBefore + ethAmount);
        callOption.addLiquidity{value: ethAmount}();
        
        assertEq(callOption.totalLocked(), totalLockedBefore + ethAmount);
        assertEq(address(callOption).balance, DEPOSIT_AMOUNT + ethAmount);
    }

    function testEmergencyWithdraw() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 时间快进到过期30天后
        vm.warp(EXPIRATION + 31 days);
        
        uint256 ownerETHBefore = owner.balance;
        vm.prank(owner);
        callOption.emergencyWithdraw();
        
        assertEq(owner.balance, ownerETHBefore + DEPOSIT_AMOUNT);
    }

    function testEmergencyWithdrawConditionsNotMet() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(owner);
        vm.expectRevert("Emergency conditions not met");
        callOption.emergencyWithdraw();
    }

    function testCompleteUserFlow() public {
        // 1. 项目方存款
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 2. 用户购买期权
        vm.startPrank(user1);
        uint256 optionAmount = 3 ether;
        uint256 optionFee = optionAmount * OPTION_PRICE / 1 ether;
        usdt.approve(address(callOption), optionFee);
        callOption.buyOption(optionAmount);
        
        // 3. 用户行权
        uint256 usdtRequired = optionAmount * STRIKE_PRICE / 1 ether;
        usdt.approve(address(callOption), usdtRequired);
        callOption.exercise(optionAmount);
        vm.stopPrank();
        
        // 4. 验证用户获得ETH
        assertEq(callOption.balanceOf(user1), 0);
        
        // 5. 时间快进，项目方清算剩余资产
        vm.warp(EXPIRATION + 1);
        vm.prank(owner);
        callOption.expire();
        
        assertEq(callOption.expired(), true);
    }

    // 测试重入攻击保护
    function testReentrancyProtection() public {
        vm.prank(owner);
        callOption.deposit{value: DEPOSIT_AMOUNT}();
        
        // 创建恶意合约
        MaliciousContract malicious = new MaliciousContract(callOption, usdt);
        
        // 给恶意合约USDT用于购买期权和行权
        usdt.transfer(address(malicious), 50000 * 10**18);
        
        // 记录攻击前的余额
        uint256 contractBalanceBefore = address(callOption).balance;
        
        // 执行攻击
        malicious.attack();
        
        // 验证重入攻击被阻止，合约余额应该只减少一次行权的ETH
        uint256 contractBalanceAfter = address(callOption).balance;
        assertEq(contractBalanceAfter, contractBalanceBefore - 1 ether);
    }
}

// 恶意合约用于测试重入攻击
contract MaliciousContract {
    CallOption public callOption;
    MockUSDT public usdt;
    bool public attacking;
    
    constructor(CallOption _callOption, MockUSDT _usdt) {
        callOption = _callOption;
        usdt = _usdt;
    }
    
    function attack() external {
        attacking = true;
        usdt.approve(address(callOption), type(uint256).max);
        // 先购买期权
        callOption.buyOption(1 ether);
        // 然后尝试行权
        callOption.exercise(1 ether);
    }
    
    receive() external payable {
        if (attacking && address(callOption).balance > 0 && callOption.balanceOf(address(this)) > 0) {
            callOption.exercise(1 ether);
        }
    }
}