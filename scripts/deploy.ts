import { network } from "hardhat";

const { ethers } = await network.connect();

async function main() {
    console.log("Starting deployment...");

    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    // 部署MyNFT合约
    console.log("\n1. Deploying MyNFT...");
    const myNFTFactory = await ethers.getContractFactory("MyNFT");
    const myNFT = await myNFTFactory.deploy();
    await myNFT.waitForDeployment();
    const myNFTAddress = await myNFT.getAddress();
    console.log("MyNFT deployed to:", myNFTAddress);

    // 部署NFTAuctionMarketplaceV1合约
    console.log("\n2. Deploying NFTAuctionMarketplaceV1...");
    const nftAuctionMarketplaceV1Factory = await ethers.getContractFactory("NFTAuctionMarketplaceV1")
    const nftAuctionMarketplaceV1 = await nftAuctionMarketplaceV1Factory.deploy()
    await nftAuctionMarketplaceV1.waitForDeployment();
    const nftAuctionMarketplaceV1Address = await nftAuctionMarketplaceV1.getAddress();
    console.log("NFTAuctionMarketplaceV1 deployed to:", nftAuctionMarketplaceV1Address);

    // 部署NFTAuctionMarketplaceProxy合约
    console.log("\n3. Deploying ERC1967Proxy...");
    const ERC1967ProxyFactory = await ethers.getContractFactory("AuctionUpgradeableProxy");

    // 准备初始化数据
    const initializeInterface = new ethers.Interface([
        "function initialize(address initialOwner, address _ethUsdPriceFeedAddress)"
    ]);
    const initData = initializeInterface.encodeFunctionData("initialize", [
        deployer.address,
        "0x694AA1769357215DE4FAC081bf1f309aDC325306",
    ]);

    const nftAuctionMarketplaceProxy = await ERC1967ProxyFactory.deploy(nftAuctionMarketplaceV1Address, initData);
    await nftAuctionMarketplaceProxy.waitForDeployment();
    const nftAuctionMarketplaceProxyAddress = await nftAuctionMarketplaceProxy.getAddress();
    console.log("ERC1967Proxy deployed to:", nftAuctionMarketplaceProxyAddress);

    console.log("Finished deployment.");

    console.log("\n=== Deployment Summary ===");
    console.log("MyNFT Contract:", myNFTAddress);
    console.log("NFTAuctionMarketplaceV1 Implementation:", nftAuctionMarketplaceV1Address);
    console.log("ERC1967Proxy Proxy:", nftAuctionMarketplaceProxyAddress);
    console.log("Deployer Address:", deployer.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
