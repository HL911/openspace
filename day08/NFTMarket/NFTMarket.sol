// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// 导入IERC20接口，用于与ERC20代币交互
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

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
    function transferWithCallback(address _to, uint256 _value) external returns (bool);
    function transferWithCallbackAndData(address _to, uint256 _value, bytes calldata _data) external returns (bool);
}


contract NFTMarket  is ITokenReceiver{
    // 扩展的ERC20代币合约地址
    IExtendedERC20 public paymentToken;
    
    // NFT上架信息结构体
    struct Listing {
        address seller;      // 卖家地址
        address nftContract; // NFT合约地址
        uint256 tokenId;     // NFT的tokenId
        uint256 price;       // 价格（以Token为单位）
        bool isActive;       // 是否处于活跃状态
    }
    
    // 所有上架的NFT，使用listingId作为唯一标识
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;


    
    // NFT上架和购买事件
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(uint256 indexed listingId);
    
    // 构造函数，设置支付代币地址
    constructor(address _paymentTokenAddress) {
        require(_paymentTokenAddress != address(0), "NFTMarket: payment token address cannot be zero");
        paymentToken = IExtendedERC20(_paymentTokenAddress);
    }


    // 上架
    function list(address _nftContract, uint256 _tokenId, uint256 _price) public {
        // 检查价格大于0
        require(_price > 0, "NFTMarket: price must be greater than zero");
        // 检查nft合约是否有效
        require(_nftContract != address(0), "NFTMarket: nft contract address cannot be zero");
        // 检查nft是否已经上架
        require(listings[_tokenId].isActive == true, "NFTMarket: nft is already listed");
        // 检查调用者是否为NFT的所有者或已获得授权
        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender || 
            nftContract.isApprovedForAll(owner, msg.sender) || 
            nftContract.getApproved(_tokenId) == msg.sender,
            "NFTMarket: caller is not owner nor approved"
        );
        // 创建新的上架信息
        uint256 listingId = nextListingId;
        listings[listingId] = Listing({
            seller: owner,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        });
        nextListingId++;
        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);
    }
    // 取消
    function cancelListing(uint256 _listingId) public {
        Listing storage listing = listings[_listingId];
        require(_listingId < nextListingId, "NFTMarket: listing id does not exist");
        require(listing.isActive, "NFTMarket: listing is not active");
        require(listing.seller == msg.sender, "NFTMarket: caller is not seller");
        listing.isActive = false;
        emit NFTListingCancelled(_listingId);
    }
    // 购买
    function buy(uint256 _listingId) public {
        Listing storage listing = listings[_listingId];
        // 检查listingId是否有效
        require(_listingId < nextListingId, "NFTMarket: listing id does not exist");
        // 检查listing是否处于活跃状态
        require(listing.isActive, "NFTMarket: listing is not active");
        // 检查买家是否有足够的代币
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "NFTMarket: not enough payment token");
        //将上架信息标记为非活跃
        listing.isActive = false;
        // 处理代币转账（买家 -> 卖家）
        paymentToken.transferFrom(msg.sender, listing.seller, listing.price);
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);
        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }


    // 实现tokensReceived接口，处理通过transferWithCallback接收到的代币
    function tokensReceived(address from, uint256 amount, bytes calldata data) external override returns (bool) {
        // 检查调用者是否为代币合约
        require(msg.sender == address(paymentToken), "NFTMarket: caller is not payment token");
        // 解析附加数据，获取listingId
        require(data.length == 32, "NFTMarket: invalid data length");
        uint256 listingId = abi.decode(data, (uint256));
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        // 检查买家是否有足够的代币
        require(amount >= listing.price, "NFTMarket: not enough payment token");
        // 将上架信息标记为非活跃
        listing.isActive = false;
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);
        // 处理代币转账（买家 -> 卖家）
        bool success = paymentToken.transfer(listing.seller, amount);
        require(success, "NFTMarket: token transfer to seller failed");
        emit NFTSold(listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
        return true;
    }


}
