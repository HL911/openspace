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


contract NFTMarket  is ITokenReceiver,ReentrancyGuard, Ownable, EIP712 {
    // 管理员地址
    address public admin;
    
    // 扩展的ERC20代币合约地址（默认支付代币）
    IExtendedERC20 public paymentToken;
    
    // NFT上架信息结构体
    struct Listing {
        address seller;      // 卖家地址
        address nftContract; // NFT合约地址
        uint256 tokenId;     // NFT的tokenId
        uint256 listingId;   // 上架ID
        uint256 price;       // 价格（以Token为单位）
        address paymentToken; // 指定的支付代币地址
        bool isActive;       // 是否处于活跃状态
        bool whitelistOnly;  // 是否仅限白名单用户购买
    }
    
    // 所有上架的NFT，使用listingId作为唯一标识
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;


    // EIP-712 类型哈希 - 项目方为白名单用户签名授权
    bytes32 private constant PERMIT_BUY_TYPEHASH =
        keccak256(
            "PermitBuy(address buyer,uint256 listingId,uint256 deadline)"
        );

    mapping(address => bool) public whitelist; // 白名单地址映射
    address[] public whitelistArray; // 白名单地址数组，用于遍历

    
    // NFT上架和购买事件
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(uint256 indexed listingId, address indexed buyer, address indexed nftContract);
    
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


    // 上架
    function list(address _nftContract, uint256 _tokenId, uint256 _price, address _paymentToken, bool _whitelistOnly) public {
        // 检查价格大于0
        require(_price > 0, "NFTMarket: price must be greater than zero");
        // 检查nft合约是否有效
        require(_nftContract != address(0), "NFTMarket: nft contract address cannot be zero");
        // 检查支付代币地址是否有效
        require(_paymentToken != address(0), "NFTMarket: payment token address cannot be zero");
        // 检查nft是否已经上架
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].nftContract == _nftContract && 
                listings[i].tokenId == _tokenId && 
                listings[i].isActive) {
                revert("NFTMarket: nft is already listed");
            }
        }
        // 检查调用者是否为NFT的所有者
        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(owner == msg.sender, "NFTMarket: caller is not the owner");
        
        // 检查市场合约是否有权限转移此NFT
        require(
            nftContract.isApprovedForAll(owner, address(this)) || 
            nftContract.getApproved(_tokenId) == address(this),
            "NFTMarket: market is not approved to transfer this NFT"
        );
        // 创建新的上架信息
        uint256 listingId = nextListingId;
        listings[listingId] = Listing({
            seller: owner,
            nftContract: _nftContract,
            tokenId: _tokenId,
            listingId: listingId,
            price: _price,
            paymentToken: _paymentToken,
            isActive: true,
            whitelistOnly: _whitelistOnly
        });
        nextListingId++;
        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);
    }
    
    // 上架NFT（使用默认支付代币，默认非白名单限制）
    function list(address _nftContract, uint256 _tokenId, uint256 _price) public {
        list(_nftContract, _tokenId, _price, address(paymentToken), false);
    }
    
    // 上架NFT（使用默认支付代币，指定白名单模式）
    function list(address _nftContract, uint256 _tokenId, uint256 _price, bool _whitelistOnly) public {
        list(_nftContract, _tokenId, _price, address(paymentToken), _whitelistOnly);
    }
    
    // 管理员方法：修改默认支付代币
    function setDefaultPaymentToken(address _newPaymentToken) public onlyAdmin {
        require(_newPaymentToken != address(0), "NFTMarket: payment token address cannot be zero");
        address oldToken = address(paymentToken);
        paymentToken = IExtendedERC20(_newPaymentToken);
        emit DefaultPaymentTokenChanged(oldToken, _newPaymentToken);
    }
    
    // 管理员方法：转移管理员权限
    function transferAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "NFTMarket: new admin address cannot be zero");
        address oldAdmin = admin;
        admin = _newAdmin;
        emit AdminChanged(oldAdmin, _newAdmin);
    }
    // 取消
    function cancelListing(uint256 _listingId) public {
        Listing storage listing = listings[_listingId];
        require(_listingId < nextListingId, "NFTMarket: listing id does not exist");
        require(listing.isActive, "NFTMarket: listing is not active");
        require(listing.seller == msg.sender, "NFTMarket: caller is not seller");
        listing.isActive = false;
        emit NFTListingCancelled(_listingId, msg.sender, listing.nftContract);
    }
    
    // 查看所有活跃的上架NFT
    function getActiveListings() public view returns (Listing[] memory) {
        // 首先计算活跃listing的数量
        uint256 activeCount = 0;
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].isActive) {
                activeCount++;
            }
        }
        
        // 创建结果数组
        Listing[] memory activeListings = new Listing[](activeCount);
        uint256 currentIndex = 0;
        
        // 填充活跃的listing
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].isActive) {
                activeListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }
        
        return activeListings;
    }
    
    // 查看指定卖家的所有活跃上架NFT
    function getSellerActiveListings(address seller) public view returns (Listing[] memory) {
        // 首先计算该卖家活跃listing的数量
        uint256 activeCount = 0;
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].isActive && listings[i].seller == seller) {
                activeCount++;
            }
        }
        
        // 创建结果数组
        Listing[] memory activeListings = new Listing[](activeCount);
        uint256 currentIndex = 0;
        
        // 填充该卖家活跃的listing
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].isActive && listings[i].seller == seller) {
                activeListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }
        
        return activeListings;
    }
    
    // 获取总的listing数量
    function getTotalListingsCount() public view returns (uint256) {
        return nextListingId;
    }
    
    // 获取活跃listing数量
    function getActiveListingsCount() public view returns (uint256) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].isActive) {
                activeCount++;
            }
        }
        return activeCount;
    }


    // 实现tokensReceived接口，处理通过transferWithCallback接收到的代币
    function tokensReceived(address from, uint256 amount, bytes calldata data) external override returns (bool) {
        // 解析附加数据，获取listingId
        require(data.length == 32, "NFTMarket: invalid data length");
        uint256 listingId = abi.decode(data, (uint256));
        
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[listingId];
        require(listingId < nextListingId, "NFTMarket: listing id does not exist");
        require(listing.isActive, "NFTMarket: listing is not active");
        
        // 检查调用者是否为该listing指定的支付代币合约
        require(msg.sender == listing.paymentToken, "NFTMarket: caller is not the specified payment token for this listing");
        
        // 检查买家是否有足够的代币
        require(amount >= listing.price, "NFTMarket: not enough payment token");
        
        // 将上架信息标记为非活跃
        listing.isActive = false;
        
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);
        
        // 处理代币转账（买家 -> 卖家）
        IERC20 listingPaymentToken = IERC20(listing.paymentToken);
        bool success = listingPaymentToken.transfer(listing.seller, listing.price);
        require(success, "NFTMarket: token transfer to seller failed");
        
        // 如果支付金额大于价格，退还多余部分
        if (amount > listing.price) {
            bool refundSuccess = listingPaymentToken.transfer(from, amount - listing.price);
            require(refundSuccess, "NFTMarket: refund failed");
        }
        
        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, listing.price);
        return true;
    }

    // 添加白名单地址（仅限owner）
    function addWhitelist(address _whitelist) external onlyOwner {
        require(_whitelist != address(0), "Invalid whitelist address");
        require(!whitelist[_whitelist], "Address already whitelisted");
        whitelist[_whitelist] = true;
        whitelistArray.push(_whitelist);
    }

    // 移除白名单地址（仅限owner）
    function removeWhitelist(address _whitelist) external onlyOwner {
        require(whitelist[_whitelist], "Address not whitelisted");
        whitelist[_whitelist] = false;
        
        // 从数组中移除
        for (uint256 i = 0; i < whitelistArray.length; i++) {
            if (whitelistArray[i] == _whitelist) {
                whitelistArray[i] = whitelistArray[whitelistArray.length - 1];
                whitelistArray.pop();
                break;
            }
        }
    }

    // 批量设置白名单地址（仅限owner）
    function setWhitelistBatch(address[] calldata _whitelists) external onlyOwner {
        // 清空现有白名单
        for (uint256 i = 0; i < whitelistArray.length; i++) {
            whitelist[whitelistArray[i]] = false;
        }
        delete whitelistArray;
        
        // 添加新的白名单
        for (uint256 i = 0; i < _whitelists.length; i++) {
            require(_whitelists[i] != address(0), "Invalid whitelist address");
            require(!whitelist[_whitelists[i]], "Duplicate address in batch");
            whitelist[_whitelists[i]] = true;
            whitelistArray.push(_whitelists[i]);
        }
    }

    // 批量添加白名单地址（不清空现有白名单）
    function addWhitelistBatch(address[] calldata _whitelists) external onlyOwner {
        for (uint256 i = 0; i < _whitelists.length; i++) {
            require(_whitelists[i] != address(0), "Invalid whitelist address");
            if (!whitelist[_whitelists[i]]) {
                whitelist[_whitelists[i]] = true;
                whitelistArray.push(_whitelists[i]);
            }
        }
    }

    // 批量移除白名单地址（优化版本）
    function removeWhitelistBatch(address[] calldata _whitelists) external onlyOwner {
        // 先标记所有要移除的地址
        for (uint256 i = 0; i < _whitelists.length; i++) {
            if (whitelist[_whitelists[i]]) {
                whitelist[_whitelists[i]] = false;
            }
        }
        
        // 重建白名单数组，只保留未被移除的地址
        uint256 writeIndex = 0;
        for (uint256 i = 0; i < whitelistArray.length; i++) {
            if (whitelist[whitelistArray[i]]) {
                whitelistArray[writeIndex] = whitelistArray[i];
                writeIndex++;
            }
        }
        
        // 调整数组长度
        while (whitelistArray.length > writeIndex) {
            whitelistArray.pop();
        }
    }

    // 检查地址是否在白名单中
    function isWhitelisted(address _address) external view returns (bool) {
        return whitelist[_address];
    }

    // 获取所有白名单地址
    function getWhitelistAddresses() external view returns (address[] memory) {
        return whitelistArray;
    }
    
    // 普通购买NFT（非白名单限制）
    function buy(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "NFT not listed for sale");
        require(!listing.whitelistOnly, "This listing requires whitelist access - use permitBuy instead");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");
        require(listing.seller != address(0), "Invalid listing");

        address seller = listing.seller;
        address nftContract = listing.nftContract;
        address paymentTokenAddr = listing.paymentToken;
        uint256 tokenId = listing.tokenId;
        uint256 listingPrice = listing.price;
        
        // 下架NFT
        listing.isActive = false;

        // 转移代币支付
        require(
            IERC20(paymentTokenAddr).transferFrom(msg.sender, seller, listingPrice),
            "Token transfer failed"
        );

        // 转移NFT
        IERC721(nftContract).safeTransferFrom(seller, msg.sender, tokenId);

        // 触发购买事件
        emit NFTSold(listingId, msg.sender, seller, nftContract, tokenId, listingPrice);
    }
    
    // 通过项目方签名授权购买NFT（白名单限制）
    function permitBuy(
        uint256 listingId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
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
                listingId,
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer != address(0), "Invalid signature");
        require(signer == owner(), "Signature must be from contract owner");

        address seller = listing.seller;
        address nftContract = listing.nftContract;
        address paymentTokenAddr = listing.paymentToken;
        uint256 tokenId = listing.tokenId;
        uint256 listingPrice = listing.price;
        
        // 下架NFT
        listing.isActive = false;

        // 转移代币支付
        require(
            IERC20(paymentTokenAddr).transferFrom(msg.sender, seller, listingPrice),
            "Token transfer failed"
        );

        // 转移NFT
        IERC721(nftContract).safeTransferFrom(seller, msg.sender, tokenId);

        // 触发购买事件
        emit NFTSold(listingId, msg.sender, seller, nftContract, tokenId, listingPrice);
    }

}
