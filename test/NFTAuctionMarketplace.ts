import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("NFTAuctionMarketplaceV1", function () {
    let nftMarketplace: any;
    let deployer: any;
    let bidder2: any;
    let bidder3: any;

    this.beforeEach(async function () {
        [deployer, bidder2, bidder3] = await ethers.getSigners();
        const deployerAddress = deployer.address;

        // 部署MyNFT合约
        const myNFTFactory = await ethers.getContractFactory("MyNFT");
        const myNFT = await myNFTFactory.deploy();
        await myNFT.waitForDeployment();
        const myNFTAddress = myNFT.target;
        // console.log("MyNFT deployed to:", myNFTAddress);
        // console.log("MyNFT deployed by:", deployerAddress);

        // 铸造一个NFT
        const mintTx = await myNFT.connect(deployer).mint("1", {value : ethers.parseEther("0.00001")});
        await mintTx.wait();
        // console.log("NFT minted with ID: 1");

        // 部署NFTAuctionMarketplaceV1合约
        const nftAuctionMarketplaceV1Factory = await ethers.getContractFactory("NFTAuctionMarketplaceV1")
        const nftAuctionMarketplaceV1 = await nftAuctionMarketplaceV1Factory.deploy()
        await nftAuctionMarketplaceV1.waitForDeployment();
        const nftAuctionMarketplaceV1Address = nftAuctionMarketplaceV1.target;
        // console.log("NFTAuctionMarketplaceV1 deployed to:", nftAuctionMarketplaceV1Address);
        // console.log("NFTAuctionMarketplaceV1 deployed by:", deployerAddress);

        // 部署NFTAuctionMarketplaceProxy合约
        // 准备初始化数据
        const initializeInterface = new ethers.Interface([
            "function initialize(address initialOwner, address _ethUsdPriceFeedAddress)"
        ]);
        const initData = initializeInterface.encodeFunctionData("initialize", [
            deployerAddress,
            "0x694AA1769357215DE4FAC081bf1f309aDC325306",
        ]);
        
        const nftAuctionMarketplaceProxyFactory = await ethers.getContractFactory("AuctionUpgradeableProxy");
        const nftAuctionMarketplaceProxy = await nftAuctionMarketplaceProxyFactory.deploy(nftAuctionMarketplaceV1Address, initData);
        await nftAuctionMarketplaceProxy.waitForDeployment();
        const nftAuctionMarketplaceProxyAddress = nftAuctionMarketplaceProxy.target;
        // console.log("NFTAuctionMarketplaceProxy deployed to:", nftAuctionMarketplaceProxyAddress);
        // console.log("NFTAuctionMarketplaceProxy deployed by:", deployerAddress);

        // MyNFT合约授权NFTAuctionMarketplaceProxy合约可以操作NFT
        const approveTx = await myNFT.connect(deployer).approve(nftAuctionMarketplaceProxyAddress, 1);
        await approveTx.wait();
        // console.log("Approved NFT ID 1 for NFTAuctionMarketplaceProxy");

        // 将逻辑合约的 ABI 绑定到代理合约的地址上
        nftMarketplace = nftAuctionMarketplaceV1Factory.attach(nftAuctionMarketplaceProxyAddress);
        
        // 创建拍卖
        const createAuctionTx = await nftMarketplace.connect(deployer).createAuction(myNFTAddress, 1, ethers.parseEther("0.00001"), 1);
        await createAuctionTx.wait();

        // 验证
        await expect(createAuctionTx).to.emit(nftMarketplace, "AuctionCreated");
        expect(await nftMarketplace.auctionCounter()).to.equals(1);
    });

    it("创建拍卖测试完成", async function () {
        
    });

    it("用户出价测试完成", async function () {
        // 用户2出价
        const placeBidTx1 = await nftMarketplace.connect(bidder2).placeBid(1, {value : ethers.parseEther("0.00002")});
        await placeBidTx1.wait();
        // 验证
        await expect(placeBidTx1).to.emit(nftMarketplace, "BidPlaced");
        expect(placeBidTx1.value).to.equals(ethers.parseEther("0.00002"));

        // 用户3出价
        const placeBidTx2 = await nftMarketplace.connect(bidder3).placeBid(1, {value : ethers.parseEther("0.00003")});
        await placeBidTx2.wait();
        // 验证
        await expect(placeBidTx2).to.emit(nftMarketplace, "BidPlaced");
        expect(placeBidTx2.value).to.equals(ethers.parseEther("0.00003"));
    });

    it("用户退款测试完成", async function () {
        // 用户2出价
        const placeBidTx1 = await nftMarketplace.connect(bidder2).placeBid(1, {value : ethers.parseEther("0.00002")});
        await placeBidTx1.wait();
        // 验证
        await expect(placeBidTx1).to.emit(nftMarketplace, "BidPlaced");
        expect(placeBidTx1.value).to.equals(ethers.parseEther("0.00002"));

        // 用户3出价
        const placeBidTx2 = await nftMarketplace.connect(bidder3).placeBid(1, {value : ethers.parseEther("0.00003")});
        await placeBidTx2.wait();
        // 验证
        await expect(placeBidTx2).to.emit(nftMarketplace, "BidPlaced");
        expect(placeBidTx2.value).to.equals(ethers.parseEther("0.00003"));

        // 验证退款前金额
        expect(await nftMarketplace.pendingReturns(1, bidder2.address)).to.equals(ethers.parseEther("0.00002"));
        // 用户2请求退款
        const refundTx = await nftMarketplace.connect(bidder2).withdrawBid(1);
        await refundTx.wait();
        // 验证退款后金额
        expect(await nftMarketplace.pendingReturns(1, bidder2.address)).to.equals(0);
    });

    it("结束拍卖测试完成", async function () {
        // 用户2出价
        const placeBidTx1 = await nftMarketplace.connect(bidder2).placeBid(1, {value : ethers.parseEther("0.00002")});
        await placeBidTx1.wait();
        // 验证
        await expect(placeBidTx1).to.emit(nftMarketplace, "BidPlaced");
        expect(placeBidTx1.value).to.equals(ethers.parseEther("0.00002"));

        // 用户3出价
        const placeBidTx2 = await nftMarketplace.connect(bidder3).placeBid(1, {value : ethers.parseEther("0.00003")});
        await placeBidTx2.wait();
        // 验证
        await expect(placeBidTx2).to.emit(nftMarketplace, "BidPlaced");
        expect(placeBidTx2.value).to.equals(ethers.parseEther("0.00003"));

        // 等待拍卖结束 - 模拟时间快进 1 小时 1 秒
        await ethers.provider.send("evm_increaseTime", [3601]); // 增加区块链时间
        await ethers.provider.send("evm_mine", []); // 挖一个新块
        
        // 结束拍卖
        const endAuctionTx = await nftMarketplace.connect(deployer).endAuction(1);
        await endAuctionTx.wait();
        // 验证
        await expect(endAuctionTx).to.emit(nftMarketplace, "AuctionEnded");
        expect((await nftMarketplace.auctions(1)).active).to.equals(false);
    });
});