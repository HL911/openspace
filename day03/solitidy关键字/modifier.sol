// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    // 合约所有者
    address public owner;
    // 维护员地址
    mapping(address => bool) public maintainers;
    // 维护费
    uint256 public maintenanceFee = 0.01 ether;
    // 最后维护时间
    uint256 public lastMaintenance;
    // 维护间隔（秒）
    uint256 public constant MAINTENANCE_INTERVAL = 30 days;

    // 构造函数，设置合约部署者为所有者
    constructor() {
        owner = msg.sender;
        _grantMaintainer(owner);
        lastMaintenance = block.timestamp;
    }

    // 修饰器：仅允许合约所有者调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _; // 继续执行函数体
    }

    // 修饰器：仅允许维护员调用
    modifier onlyMaintainer() {
        require(maintainers[msg.sender], "Only maintainer can call this function");
        _;
    }

    // 修饰器：检查维护状态
    modifier maintenanceRequired() {
        require(block.timestamp >= lastMaintenance + MAINTENANCE_INTERVAL, "Maintenance not yet required");
        _;
    }

    // 修饰器：带参数
    modifier costs(uint256 price) {
        require(msg.value >= price, "Insufficient payment");
        _;
        // 返还多余的资金
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    // 添加维护员（仅所有者）
    function grantMaintainer(address _maintainer) public onlyOwner {
        _grantMaintainer(_maintainer);
    }

    // 内部函数：添加维护员
    function _grantMaintainer(address _maintainer) internal {
        maintainers[_maintainer] = true;
    }

    // 移除维护员（仅所有者）
    function revokeMaintainer(address _maintainer) public onlyOwner {
        require(_maintainer != owner, "Cannot revoke owner's maintainer status");
        maintainers[_maintainer] = false;
    }

    // 执行维护（仅维护员）
    function performMaintenance() public onlyMaintainer maintenanceRequired {
        lastMaintenance = block.timestamp;
        // 执行维护逻辑...
    }

    // 支付维护费并成为维护员
    function becomeMaintainer() public payable costs(maintenanceFee) {
        _grantMaintainer(msg.sender);
        // 费用保留在合约中
    }

    // 提取合约余额（仅所有者）
    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // 修改维护费（仅所有者）
    function setMaintenanceFee(uint256 _fee) public onlyOwner {
        maintenanceFee = _fee;
    }
}

// 使用示例
contract MaintainedService is AccessControl {
    // 服务状态
    bool public isActive = true;
    
    // 修饰器：检查服务是否激活
    modifier whenActive() {
        require(isActive, "Service is not active");
        _;
    }
    
    // 切换服务状态（仅维护员）
    function toggleService() public onlyMaintainer {
        isActive = !isActive;
    }
    
    // 使用服务（需要支付费用）
    function useService() public payable whenActive costs(0.001 ether) {
        // 使用服务的逻辑...
    }
    
    // 紧急停止（仅所有者）
    function emergencyStop() public onlyOwner {
        isActive = false;
    }
}