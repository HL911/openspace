// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 1. 定义一个游戏角色接口
interface ICharacter {
    // 获取角色信息
    function getName() external view returns (string memory);
    function getLevel() external view returns (uint256);
    function getAttack() external view returns (uint256);
    
    // 角色行为
    function levelUp() external;
    function attack() external view returns (uint256);
}

// 2. 实现战士角色
contract Warrior is ICharacter {
    string public name;
    uint256 public level;
    uint256 public attackPower;
    
    constructor(string memory _name) {
        name = _name;
        level = 1;
        attackPower = 10;
    }
    
    function getName() external view override returns (string memory) {
        return string(abi.encodePacked("Warrior ", name));
    }
    
    function getLevel() external view override returns (uint256) {
        return level;
    }
    
    function getAttack() external view override returns (uint256) {
        return attackPower;
    }
    
    function levelUp() external override {
        level += 1;
        attackPower += 5;
    }
    
    function attack() external view override returns (uint256) {
        return attackPower;
    }
}

// 3. 实现法师角色
contract Mage is ICharacter {
    string public name;
    uint256 public level;
    uint256 public magicPower;
    
    constructor(string memory _name) {
        name = _name;
        level = 1;
        magicPower = 15;
    }
    
    function getName() external view override returns (string memory) {
        return string(abi.encodePacked("Mage ", name));
    }
    
    function getLevel() external view override returns (uint256) {
        return level;
    }
    
    function getAttack() external view override returns (uint256) {
        return magicPower;
    }
    
    function levelUp() external override {
        level += 1;
        magicPower += 8;
    }
    
    function attack() external view override returns (uint256) {
        return magicPower * 2; // 法师攻击力是魔法力的2倍
    }
}

// 4. 游戏管理合约，使用接口作为参数
contract GameManager {
    event CharacterTrained(address character, string name, uint256 newLevel);
    event BattleResult(address attacker, uint256 damage, string result);
    
    // 训练角色（接受任何实现了ICharacter接口的合约地址）
    function trainCharacter(ICharacter character) external {
        // 获取训练前信息
        string memory name = character.getName();
        
        // 升级角色
        character.levelUp();
        
        // 获取训练后信息
        uint256 newLevel = character.getLevel();
        
        emit CharacterTrained(address(character), name, newLevel);
    }
    
    // 角色对战（接受两个实现了ICharacter接口的合约地址）
    function battle(ICharacter attacker, ICharacter defender) external {
        uint256 attackPower = attacker.attack();
        uint256 defensePower = defender.getAttack() / 2;
        
        if (attackPower > defensePower) {
            emit BattleResult(
                address(attacker),
                attackPower - defensePower,
                "Attacker wins!"
            );
        } else {
            emit BattleResult(
                address(attacker),
                0,
                "Defender wins!"
            );
        }
    }
    
    // 获取角色信息（展示如何使用接口类型作为参数）
    function getCharacterInfo(ICharacter character) external view returns (
        string memory name,
        uint256 level,
        uint256 attack
    ) {
        name = character.getName();
        level = character.getLevel();
        attack = character.getAttack();
    }
}

// 5. 使用示例
contract GameExample {
    // 创建角色
    function createCharacters() public returns (address, address) {
        // 创建一个战士和一个法师
        Warrior warrior = new Warrior("Conan");
        Mage mage = new Mage("Gandalf");
        return (address(warrior), address(mage));
    }
    
    // 进行游戏
    function playGame() public {
        // 1. 创建游戏管理器和角色
        GameManager game = new GameManager();
        (address warriorAddr, address mageAddr) = createCharacters();
        
        // 2. 将地址转换为接口类型
        ICharacter warrior = ICharacter(warriorAddr);
        ICharacter mage = ICharacter(mageAddr);
        
        // 3. 训练角色
        game.trainCharacter(warrior);
        game.trainCharacter(mage);
        game.trainCharacter(mage); // 法师升级两次
        
        // 4. 进行对战
        game.battle(warrior, mage);
    }
}