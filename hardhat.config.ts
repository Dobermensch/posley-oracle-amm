import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import dotenv from 'dotenv';

dotenv.config();

const walletPrivateKey = process.env.WALLET_PRIVATE_KEY

const accounts = []

if (walletPrivateKey) accounts.push(walletPrivateKey)

const config: HardhatUserConfig = {
  networks: {
    hardhat: {},
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: accounts,
    },
  },
  solidity: '0.8.24',
};

export default config;
