// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title NFTAuctionMarketplaceV1
 * @dev NFT拍卖市场合约V1，支持ERC721标准的NFT拍卖功能
 * @notice 继承自OpenZeppelin的Initializable、OwnableUpgradeable和UUPSUpgradeable，实现可升级合约模式
 * 功能：
 * - 创建拍卖
 * - 支持用户出价
 * - 支持撤回资金
 * - 支持结束拍卖并结算
 * - 获取实时ETH/USD价格（通过Chainlink）
 * - UUPS升级机制
 */
contract NFTAuctionMarketplaceV1  is ReentrancyGuard, Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // ============ 状态变量 ============

    // Chainlink预言机：获取ETH/USD价格
    AggregatorV3Interface public ethUsdPriceFeed;

    /**
     * @dev 拍卖结构体
     */
    struct Auction {
        address seller;           // 卖家地址
        address nftContract;      // NFT合约地址
        uint256 tokenId;          // Token ID
        uint256 startPrice;       // 起拍价
        uint256 highestBid;       // 当前最高出价
        address highestBidder;    // 当前最高出价者
        uint256 endTime;          // 拍卖结束时间
        bool active;              // 是否激活
    }

    // 拍卖映射
    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;

    // 待退款映射（用于拍卖）
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    
    // ============ 事件 ============

    /**
     * @dev 拍卖创建事件
     */
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endTime
    );

    /**
     * @dev 出价事件
     */
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );
    
    /**
     * @dev 拍卖结束事件
     */
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalPrice
    );

    // ============ 修饰符 ============

    // ============ 初始化函数 ============
    /**
     * @notice 初始化合约
     * @param initialOwner 初始owner地址
     * @param _ethUsdPriceFeedAddress Chainlink预言机：获取ETH/USD价格地址
     */
    function initialize(address initialOwner, address _ethUsdPriceFeedAddress) 
        public 
        initializer 
    {
        require(_ethUsdPriceFeedAddress != address(0), "Invalid price feed address");
        
        __Ownable_init(initialOwner);

        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddress);

    }

    // ============ 拍卖管理函数 ============   
    
    /**
     * @dev 创建拍卖
     * @param nftContract NFT合约地址
     * @param tokenId Token ID
     * @param startPrice 起拍价（wei）
     * @param durationHours 拍卖时长（小时）
     * @return auctionId 拍卖ID
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 durationHours
    ) external returns (uint256) {
        require(startPrice > 0, "Start price must be greater than 0");
        require(durationHours >= 1, "Duration must be at least 1 hour");
        require(nftContract != address(0), "Invalid NFT contract");
        
        IERC721 nft = IERC721(nftContract);
        
        // 验证所有权
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        
        // 验证授权
        require(
            nft.getApproved(tokenId) == address(this) ||
            nft.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );
        
        // 创建拍卖
        auctionCounter++;
        auctions[auctionCounter] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            startPrice: startPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + (durationHours * 1 minutes), // 方便测试，使用分钟代替小时
            active: true
        });
        
        emit AuctionCreated(
            auctionCounter,
            msg.sender,
            nftContract,
            tokenId,
            startPrice,
            auctions[auctionCounter].endTime
        );
        
        return auctionCounter;
    }

    /**
     * @dev 出价
     * @param auctionId 拍卖ID
     * @notice 需要支付足够的ETH，出价必须高于当前最高出价的5%
     */
    function placeBid(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];
        
        require(auction.active, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.sender != auction.seller, "Seller cannot bid");
        
        // 计算最低出价（ETH单位比较）
        uint256 minBid;
        if (auction.highestBid == 0) {
            minBid = auction.startPrice;
        } else {
            minBid = auction.highestBid + (auction.highestBid * 5 / 100); // 5% increment
        }
        require(msg.value >= minBid, "Bid too low");

        // 计算最低出价（美元单位比较）- 暂注释
        // uint256 usdMinBid;
        // if (auction.highestBid == 0) {
        //     usdMinBid = convertETHtoUSD(auction.startPrice);
        // } else {
        //     uint256 usdHighestBid = convertETHtoUSD(auction.highestBid);
        //     usdMinBid = usdHighestBid + (usdHighestBid * 5 / 100); // 5% increment
        // }
        // require(convertETHtoUSD(msg.value) >= usdMinBid, "Bid too low");
        
        // 如果有之前的出价者，记录他们的待退款金额
        if (auction.highestBidder != address(0)) {
            pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }
        
        // 更新最高出价
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;
        
        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    /**
     * @dev 提取出价退款
     * @param auctionId 拍卖ID
     * @notice 被超越的出价者可以提取他们的资金
     */
    function withdrawBid(uint256 auctionId) external {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        require(amount > 0, "No pending return");
        
        pendingReturns[auctionId][msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev 结束拍卖
     * @param auctionId 拍卖ID
     * @notice 任何人都可以在拍卖结束后调用此函数进行结算
     */
    function endAuction(uint256 auctionId) external virtual nonReentrant() {
        Auction storage auction = auctions[auctionId];
        
        require(auction.active, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction not ended");
        
        auction.active = false;
        
        if (auction.highestBidder != address(0)) {            
            // 转移NFT
            IERC721(auction.nftContract).safeTransferFrom(
                auction.seller,
                auction.highestBidder,
                auction.tokenId
            );
            
            // 资金分配         
            (bool successSeller, ) = auction.seller.call{value: auction.highestBid}("");
            require(successSeller, "Transfer to seller failed");
            
            emit AuctionEnded(
                auctionId,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            // 没有人出价，拍卖流拍
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }

    // ============ Chainlink预言机：获取最新ETH/USD价格函数 ============

    /**
     * @dev 获取当前 ETH/USD 价格
     * @return 最新价格（8位小数，例如 2000.00000000 表示 2000美元）
     */
    function getLatestPrice() public view returns (int256) {
        (
            /*uint80 roundID*/,
            int256 price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = ethUsdPriceFeed.latestRoundData();
        return price;
    }
    
    /**
     * @dev 将 ETH 数量转换为等值美元（单位：centiUSD，1美元 = 100）
     * @param ethAmount ETH 数量（wei为单位）
     * @return 等值的美元价值（centiUSD为单位）
     */
    function convertETHtoUSD(uint256 ethAmount) public view returns (uint256) {
        int256 latestPrice = getLatestPrice();
        require(latestPrice > 0, "Invalid price");
        
        // 价格有8位小数，ETH有18位小数
        // 结果需要转换为 centiUSD（2位小数）
        // 公式: (ethAmount * price) / 10^(8+18-2) = 以centiUSD为单位的值
        
        // 安全计算，防止溢出
        uint256 ethInWei = ethAmount;
        uint256 price = uint256(latestPrice);
        
        // 计算: ethInWei * price / 10^24 得到以centiUSD为单位的值
        // 10^24 = 10^(8+18-2)
        return (ethInWei * price) / 1e24;
    }

    // ============ 查询函数 ============
    
    // ============ 紧急提取ETH函数 ============

    /**
     * @dev 紧急提取ETH
     */
    function emergencyWithdrawETH() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    // ============ UUPS升级授权 ============
    
    /**
     * @dev 授权升级函数，只有owner可以升级
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}