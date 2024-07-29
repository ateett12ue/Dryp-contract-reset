import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-deploy";
import "@openzeppelin/hardhat-upgrades";

dotenv.config();

import "./tasks";

const config: HardhatUserConfig = {
  paths: {
    artifacts: "artifacts",
    cache: "cache",
    deploy: "src/deploy",
    sources: "contracts",
  },
  solidity: {
    compilers: [
    {
      version: "0.8.20",
      settings: {
        optimizer: { enabled: true, runs:200},
        viaIR: true,
      },
    }]
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined
          ? [process.env.PRIVATE_KEY]
          : [""],
      chainId: 11155111,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
    customChains: [],
  },
};

export default config;
