// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// 定义接收代币回调的接口
interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external returns (bool);
}

// 简单的ERC721接口
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getApproved(uint256 tokenId) external view returns (address);
}

// 扩展的ERC20接口，添加带有回调功能的转账函数
interface IExtendedERC20 is IERC20 {
    function transferWithCallback(address _to, uint256 _value, bytes calldata data) external returns (bool);
    function transferWithCallbackAndData(address _to, uint256 _value, bytes calldata _data) external returns (bool);
}

contract NFTMarketV3 is ITokenReceiver, ReentrancyGuard, Ownable, EIP712 {
    // 管理员地址
    address public admin;
    
    // 扩展的ERC20代币合约地址（默认支付代币）
    IExtendedERC20 public paymentToken;
    
    // 优化的 Listing 结构体 - 移除 listingId 字段（由 key 决定）
    struct Listing {
        address seller;      // 卖家地址
        address nftContract; // NFT合约地址
        address paymentToken; // 指定的支付代币地址
        uint256 tokenId;     // NFT的tokenId
        uint256 price;       // 价格（以Token为单位）
        bool isActive;       // 是否处于活跃状态
        bool whitelistOnly;  // 是否仅限白名单用户购买
    }
    
    // 核心存储：使用 keccak256(nftContract, tokenId) 作为唯一键
    mapping(bytes32 => Listing) public listings;

    // EIP-712 类型哈希 - 项目方为白名单用户签名授权
    bytes32 private constant PERMIT_BUY_TYPEHASH =
        keccak256(
            "PermitBuy(address buyer,bytes32 listingId,uint256 deadline)"
        );

    mapping(address => bool) public whitelist; // 白名单地址映射
    address[] public whitelistArray; // 白名单地址数组，用于遍历

    // NFT上架和购买事件
    event NFTListed(bytes32 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(bytes32 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(bytes32 indexed listingId, address indexed seller, address indexed nftContract);
    
    // 管理员相关事件
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event DefaultPaymentTokenChanged(address indexed oldToken, address indexed newToken);
    
    // 管理员权限修饰符
    modifier onlyAdmin() {
        require(msg.sender == admin, "NFTMarket: caller is not admin");
        _;
    }
    
    // 构造函数，设置支付代币地址
    constructor(address _paymentTokenAddress) 
        Ownable(msg.sender) 
        EIP712("NFTMarket", "1") 
    {
        require(_paymentTokenAddress != address(0), "NFTMarket: payment token address cannot be zero");
        admin = msg.sender; // 设置部署者为管理员
        paymentToken = IExtendedERC20(_paymentTokenAddress);
    }

    // === 核心工具函数 ===
    
    /// @dev 生成唯一的 listing ID
    /// @param nftContract NFT 合约地址
    /// @param tokenId NFT token ID
    /// @return 唯一的 listing ID
    function generateListingId(address nftContract, uint256 tokenId) 
        public pure returns (bytes32) {
        return keccak256(abi.encode(nftContract, tokenId));
    }
    
    /// @dev 检查 NFT 是否已上架
    /// @param nftContract NFT 合约地址
    /// @param tokenId NFT token ID
    /// @return 是否已上架
    function isNFTListed(address nftContract, uint256 tokenId) 
        public view returns (bool) {
        bytes32 listingId = generateListingId(nftContract, tokenId);
        return listings[listingId].isActive;
    }
    
    /// @dev 获取 NFT 的 listinsg 信息
    /// @param nftContract NFT 合约地址
    /// @param tokenId NFT token ID
    /// @return listing 信息
    function getNFTListing(address nftContract, uint256 tokenId) 
        public view returns (Listing memory) {
        bytes32 listingId = generateListingId(nftContract, tokenId);
        return listings[listingId];
    }

    // === 核心功能函数 ===

    /// @dev 上架 NFT - 极致优化版本
    /// @param _nftContract NFT 合约地址
    /// @param _tokenId NFT token ID
    /// @param _price 价格
    /// @param _paymentToken 支付代币地址
    /// @param _whitelistOnly 是否仅限白名单
    function list(
        address _nftContract, 
        uint256 _tokenId, 
        uint256 _price, 
        address _paymentToken, 
        bool _whitelistOnly
    ) public returns (bytes32 listingId) {
        // 基础验证（合并多个 require）
        require(
            _price > 0 && 
            _nftContract != address(0) && 
            _paymentToken != address(0),
            "NFTMarket: invalid parameters"
        );
        
        // 生成唯一 listing ID
        listingId = generateListingId(_nftContract, _tokenId);
        
        // O(1) 检查是否已上架
        require(!listings[listingId].isActive, "NFTMarket: nft already listed");
        
        // 检查调用者是否是nft的拥有者
        require(IERC721(_nftContract).ownerOf(_tokenId) == msg.sender, "NFTMarket: caller is not the owner");
        
        // 检查nft是否已经授权给合约
        require(
            IERC721(_nftContract).isApprovedForAll(msg.sender, address(this)) || 
            IERC721(_nftContract).getApproved(_tokenId) == address(this),
            "NFTMarket: NFT not approved for marketplace"
        );
        
        // 创建 listing
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: _nftContract,
            paymentToken: _paymentToken,
            tokenId: _tokenId,
            price: _price,
            isActive: true,
            whitelistOnly: _whitelistOnly
        });
        
        emit NFTListed(listingId, msg.sender, _nftContract, _tokenId, _price);
        return listingId;
    }
    
    /// @dev 上架NFT（使用默认支付代币，默认非白名单限制）
    function list(address _nftContract, uint256 _tokenId, uint256 _price) 
        public returns (bytes32) {
        return list(_nftContract, _tokenId, _price, address(paymentToken), false);
    }
    
    /// @dev 上架NFT（使用默认支付代币，指定白名单模式）
    function list(address _nftContract, uint256 _tokenId, uint256 _price, bool _whitelistOnly) 
        public returns (bytes32) {
        return list(_nftContract, _tokenId, _price, address(paymentToken), _whitelistOnly);
    }
    
    /// @dev 取消上架
    /// @param listingId listing ID
    function cancelListing(bytes32 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "NFTMarket: listing not active");
        require(listing.seller == msg.sender, "NFTMarket: not the seller");
        
        listing.isActive = false;
        emit NFTListingCancelled(listingId, msg.sender, listing.nftContract);
    }
    
    /// @dev 批量取消上架
    /// @param nftContracts NFT 合约地址数组
    /// @param tokenIds NFT token ID 数组
    function cancelListingBatch(address[] calldata nftContracts, uint256[] calldata tokenIds) external {
        require(nftContracts.length == tokenIds.length, "Array length mismatch");
        
        for (uint256 i = 0; i < nftContracts.length;) {
            bytes32 listingId = generateListingId(nftContracts[i], tokenIds[i]);
            Listing storage listing = listings[listingId];
            
            if (listing.isActive && listing.seller == msg.sender) {
                listing.isActive = false;
                emit NFTListingCancelled(listingId, msg.sender, listing.nftContract);
            }
            
            unchecked {
                ++i;
            }
        }
    }

    // === 购买功能 ===
    
    /// @dev 内部函数：执行购买逻辑
    /// @param listingId listing ID
    function _executePurchase(bytes32 listingId) internal {
        Listing storage listing = listings[listingId];
        
        // 缓存存储变量到内存，减少 SLOAD 操作
        address seller = listing.seller;
        address nftContract = listing.nftContract;
        address paymentTokenAddr = listing.paymentToken;
        uint256 tokenId = listing.tokenId;
        uint256 listingPrice = listing.price;
        
        // 转移代币支付
        require(
            IERC20(paymentTokenAddr).transferFrom(msg.sender, seller, listingPrice),
            "Token transfer failed"
        );

        // 转移NFT
        IERC721(nftContract).safeTransferFrom(seller, msg.sender, tokenId);

        // 所有外部调用完成后再更新状态，避免重入攻击
        listing.isActive = false;

        // 触发购买事件
        emit NFTSold(listingId, msg.sender, seller, nftContract, tokenId, listingPrice);
    }
    
    /// @dev 内部购买函数：处理普通购买逻辑（非白名单限制）
    /// @param listingId listing ID
    function _buy(bytes32 listingId) internal {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "NFT not listed for sale");
        require(!listing.whitelistOnly, "This listing requires whitelist access - use permitBuy instead");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");
        require(listing.seller != address(0), "Invalid listing");

        _executePurchase(listingId);
    }
    
    /// @dev 普通购买NFT（非白名单限制）
    /// @param listingId listing ID
    function buy(bytes32 listingId) external nonReentrant {
        _buy(listingId);
    }
    
    /// @dev 便利函数：通过 NFT 信息购买
    /// @param nftContract NFT 合约地址
    /// @param tokenId NFT token ID
    function buyByNFT(address nftContract, uint256 tokenId) external nonReentrant {
        bytes32 listingId = generateListingId(nftContract, tokenId);
        _buy(listingId);
    }
    
    /// @dev 通过项目方签名授权购买NFT（白名单限制）
    /// @param listingId listing ID
    /// @param deadline 签名截止时间
    /// @param v 签名参数
    /// @param r 签名参数
    /// @param s 签名参数
    function permitBuy(
        bytes32 listingId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");
        
        // 首先检查 listing 是否存在和活跃
        Listing storage listing = listings[listingId];
        require(listing.isActive, "NFT not listed for sale");
        require(listing.whitelistOnly, "This listing doesn't require permit - use buy instead");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");
        require(listing.seller != address(0), "Invalid listing");
        
        // 检查买家是否在白名单中
        require(whitelist[msg.sender], "Buyer not whitelisted");

        // 验证项目方的 EIP-712 签名
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_BUY_TYPEHASH,
                msg.sender, // buyer地址
                listingId,  // 使用 bytes32 listingId
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer != address(0), "Invalid signature");
        address seller = listing.seller;
        require(signer == seller, "Signature must be from NFT owner (seller)");

        // 执行购买逻辑
        _executePurchase(listingId);
    }
    
    /// @dev 便利函数：通过 NFT 信息进行白名单购买
    /// @param nftContract NFT 合约地址
    /// @param tokenId NFT token ID
    /// @param deadline 签名截止时间
    /// @param v 签名参数
    /// @param r 签名参数
    /// @param s 签名参数
    function permitBuyByNFT(
        address nftContract,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant {
        bytes32 listingId = generateListingId(nftContract, tokenId);
        permitBuy(listingId, deadline, v, r, s);
    }

    // === 白名单管理函数 ===
    
    /// @dev 添加白名单地址（仅限owner）
    function addWhitelist(address _whitelist) external onlyOwner {
        require(_whitelist != address(0), "Invalid whitelist address");
        require(!whitelist[_whitelist], "Address already whitelisted");
        whitelist[_whitelist] = true;
        whitelistArray.push(_whitelist);
    }

    /// @dev 移除白名单地址（仅限owner）
    function removeWhitelist(address _whitelist) external onlyOwner {
        require(whitelist[_whitelist], "Address not whitelisted");
        whitelist[_whitelist] = false;
        
        // 从数组中移除（优化版本）
        uint256 length = whitelistArray.length;
        for (uint256 i = 0; i < length;) {
            if (whitelistArray[i] == _whitelist) {
                whitelistArray[i] = whitelistArray[length - 1];
                whitelistArray.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev 批量添加白名单地址
    function addWhitelistBatch(address[] calldata _whitelists) external onlyOwner {
        uint256 length = _whitelists.length;
        require(length > 0, "Empty whitelist array");
        
        for (uint256 i = 0; i < length;) {
            address addr = _whitelists[i];
            require(addr != address(0), "Invalid whitelist address");
            
            if (!whitelist[addr]) {
                whitelist[addr] = true;
                whitelistArray.push(addr);
            }
            
            unchecked {
                ++i;
            }
        }
    }

    /// @dev 批量移除白名单地址
    function removeWhitelistBatch(address[] calldata _whitelists) external onlyOwner {
        uint256 removeLength = _whitelists.length;
        require(removeLength > 0, "Empty remove array");
        
        // 先标记所有要移除的地址
        for (uint256 i = 0; i < removeLength;) {
            address addr = _whitelists[i];
            if (whitelist[addr]) {
                whitelist[addr] = false;
            }
            unchecked {
                ++i;
            }
        }
        
        // 重建白名单数组
        uint256 arrayLength = whitelistArray.length;
        uint256 writeIndex = 0;
        
        for (uint256 i = 0; i < arrayLength;) {
            address addr = whitelistArray[i];
            if (whitelist[addr]) {
                whitelistArray[writeIndex] = addr;
                unchecked {
                    ++writeIndex;
                }
            }
            unchecked {
                ++i;
            }
        }
        
        // 调整数组长度
        while (whitelistArray.length > writeIndex) {
            whitelistArray.pop();
        }
    }

    /// @dev 检查地址是否在白名单中
    function isWhitelisted(address _address) external view returns (bool) {
        return whitelist[_address];
    }

    /// @dev 获取所有白名单地址
    function getWhitelistAddresses() external view returns (address[] memory) {
        return whitelistArray;
    }

    // === 管理员函数 ===
    
    /// @dev 更改管理员
    function changeAdmin(address _newAdmin) public onlyOwner {
        require(_newAdmin != address(0), "NFTMarket: new admin address cannot be zero");
        address oldAdmin = admin;
        admin = _newAdmin;
        emit AdminChanged(oldAdmin, _newAdmin);
    }

    /// @dev 设置默认支付代币
    function setDefaultPaymentToken(address _newPaymentToken) public onlyAdmin {
        require(_newPaymentToken != address(0), "NFTMarket: payment token address cannot be zero");
        address oldToken = address(paymentToken);
        paymentToken = IExtendedERC20(_newPaymentToken);
        emit DefaultPaymentTokenChanged(oldToken, _newPaymentToken);
    }

    // === 回调函数 ===
    
    /// @dev 实现代币接收回调
    function tokensReceived(address from, uint256 amount, bytes calldata data) external override returns (bool) {
        // 解析附加数据，获取listingId
        require(data.length == 32, "NFTMarket: invalid data length");
        bytes32 listingId = abi.decode(data, (bytes32));
        
        Listing storage listing = listings[listingId];
        require(listing.isActive, "NFT not listed for sale");
        require(listing.price == amount, "NFTMarket: incorrect payment amount");
        require(msg.sender == listing.paymentToken, "NFTMarket: invalid payment token");

        // 转移NFT给买家
        IERC721(listing.nftContract).safeTransferFrom(listing.seller, from, listing.tokenId);
        
        // 下架NFT
        listing.isActive = false;

        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, listing.price);
        return true;
    }
    
    // === 批量查询函数 ===
    
    /// @dev 批量检查 NFT 是否已上架
    /// @param nftContracts NFT 合约地址数组
    /// @param tokenIds NFT token ID 数组
    /// @return 是否已上架的布尔数组
    function batchIsNFTListed(address[] calldata nftContracts, uint256[] calldata tokenIds) 
        external view returns (bool[] memory) {
        require(nftContracts.length == tokenIds.length, "Array length mismatch");
        
        bool[] memory results = new bool[](nftContracts.length);
        for (uint256 i = 0; i < nftContracts.length;) {
            results[i] = isNFTListed(nftContracts[i], tokenIds[i]);
            unchecked {
                ++i;
            }
        }
        return results;
    }
    
    /// @dev 批量获取 NFT listing 信息
    /// @param nftContracts NFT 合约地址数组
    /// @param tokenIds NFT token ID 数组
    /// @return listing 信息数组
    function batchGetNFTListing(address[] calldata nftContracts, uint256[] calldata tokenIds) 
        external view returns (Listing[] memory) {
        require(nftContracts.length == tokenIds.length, "Array length mismatch");
        
        Listing[] memory results = new Listing[](nftContracts.length);
        for (uint256 i = 0; i < nftContracts.length;) {
            results[i] = getNFTListing(nftContracts[i], tokenIds[i]);
            unchecked {
                ++i;
            }
        }
        return results;
    }
}
