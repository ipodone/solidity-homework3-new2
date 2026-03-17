import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { defineConfig } from "hardhat/config";
import * as dotenv from "dotenv";

dotenv.config();

export default defineConfig({
  plugins: [hardhatToolboxMochaEthersPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: process.env.SEPOLIA_PRIVATE_KEY ? [process.env.SEPOLIA_PRIVATE_KEY] : [],
    },
  },
  // 验证配置 - Hardhat v3 的正确方式
  verify: {
    etherscan: {
      enabled: true,
      apiKey: "blockscout-for-sepolia", // Blockscout 不需要真实 key
    },
    sourcify: {
      enabled: false,
    },
  },
  // 链描述符 - 这是 v3 中替代 customChains 的关键配置！
  chainDescriptors: {
    11155111: {  // Sepolia 的 chainId
      name: "sepolia",
      blockExplorers: {
        etherscan: {
          name: "Blockscout",
          url: "https://eth-sepolia.blockscout.com",
          apiUrl: "https://eth-sepolia.blockscout.com/api",
        },
      },
    },
  },
});
