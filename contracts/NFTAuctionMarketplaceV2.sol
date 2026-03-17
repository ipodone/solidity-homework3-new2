// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./NFTAuctionMarketplaceV1.sol";

/**
 * @title NFTAuctionMarketplaceV2
 * @dev NFT拍卖市场合约V2升级版本
 * 新增功能：
 * - 平台费用机制
 */
contract NFTAuctionMarketplaceV2  is NFTAuctionMarketplaceV1 {

    // ============ 新增状态变量 ============

    // 平台手续费（基点，10000 = 100%）
    uint256 public platformFee = 250; // 2.5%
    
    // 手续费接收地址
    address public feeRecipient;

    // ============ 初始化函数 ============

    /**
     * @dev 初始化V2功能
     * @param _feeRecipient 手续费接收地址
     */
    function initializeV2(address _feeRecipient) public onlyOwner {
       require(_feeRecipient != address(0), "Invalid address");
        feeRecipient = _feeRecipient;
    }

    // ============ 重写的结束拍卖函数 ============

    /**
     * @dev 结束拍卖（V2版本，支持平台费用）
     * @param auctionId 拍卖ID
     * @notice 任何人都可以在拍卖结束后调用此函数进行结算
     */
    function endAuction(uint256 auctionId) external override nonReentrant() {
        Auction storage auction = auctions[auctionId];
        
        require(auction.active, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction not ended");
        
        auction.active = false;
        
        if (auction.highestBidder != address(0)) {            
            // 有人出价，进行结算
            uint256 fee = (auction.highestBid * platformFee) / 10000;

            uint256 sellerAmount = auction.highestBid - fee;

            // 转移NFT
            IERC721(auction.nftContract).safeTransferFrom(
                auction.seller,
                auction.highestBidder,
                auction.tokenId
            );
            
            // 资金分配         
            (bool successSeller, ) = auction.seller.call{value: sellerAmount}("");
            require(successSeller, "Transfer to seller failed");

            (bool successFee, ) = feeRecipient.call{value: fee}("");
            require(successFee, "Transfer fee failed");
            
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

    // ============ 管理函数 ============

    /**
     * @dev 设置平台手续费
     * @param newFee 新的手续费（基点）
     * @notice 只有手续费接收地址可以调用
     */
    function setPlatformFee(uint256 newFee) external {
        require(msg.sender == feeRecipient, "Not fee recipient");
        require(newFee <= 1000, "Fee too high"); // 最大10%
        platformFee = newFee;
    }
    
    /**
     * @dev 更新手续费接收地址
     * @param newRecipient 新的接收地址
     * @notice 只有当前手续费接收地址可以调用
     */
    function updateFeeRecipient(address newRecipient) external {
        require(msg.sender == feeRecipient, "Not fee recipient");
        require(newRecipient != address(0), "Invalid address");
        feeRecipient = newRecipient;
    }
}