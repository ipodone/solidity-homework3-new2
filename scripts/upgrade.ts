import { network } from "hardhat";

const { ethers } = await network.connect();

async function main() {
  console.log("Starting upgrade...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // 这是代理地址（从部署脚本获得）
  const PROXY_ADDRESS = process.env.PROXY_ADDRESS || "";

  if (!PROXY_ADDRESS) {
    throw new Error(
      "Please set AUCTION_PROXY_ADDRESS environment variable"
    );
  }

  console.log("Upgrading proxy at:", PROXY_ADDRESS);

  // 部署新的实现合约
  console.log("Deploying new implementation...");
  const NewAuctionFactory = await ethers.getContractFactory("NFTAuctionMarketplaceV2");
  const newImplementation = await NewAuctionFactory.deploy();
  await newImplementation.waitForDeployment();
  const newImplementationAddress = await newImplementation.getAddress();
  console.log("New implementation deployed to:", newImplementationAddress);

  // 连接到代理合约
  const proxyAuction = NewAuctionFactory.attach(PROXY_ADDRESS);

  // 准备初始化数据
    const initializeInterface = new ethers.Interface([
        "function initializeV2(address _feeRecipient)"
    ]);
    const initData = initializeInterface.encodeFunctionData("initializeV2", [
        deployer.address,
    ]);

  // 执行升级
  console.log("Executing upgrade...");
  const tx = await proxyAuction.upgradeToAndCall(
    newImplementationAddress,
    initData,
  );
  await tx.wait();

  console.log("Upgrade completed successfully!");
  console.log("New implementation:", newImplementationAddress);
  console.log("Proxy address:", PROXY_ADDRESS);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
