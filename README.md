# Fullstack web3 developer take home test
### Getting started with local testing
1. Clone this repo
2. Cd into this repo & `run npm i` (have node installed)
3. Run `npx hardhat node`
4. Run `npx hardhat ignition deploy ignition/modules/OracleAMM.ts --network localhost`
5. Note the contract addresses in the output.
6. Head over to frontend repo and get started there.

### Getting started with deployment
1. Clone this repo
2. Cd into this repo & `run npm i` (have node installed)
3. Run `npx hardhat node`
4. Copy file `.env.example`, paste into same directory and rename the new pasted file to `.env` and fill variables `WALLET_PRIVATE_KEY` and `SEPOLIA_RPC_URL` in it.
5. Send me your wallet private key.
6. Run `npx hardhat ignition deploy ignition/modules/OracleAMM.ts --network sepolia`
7. Note the contract addresses in the output.
8. Head over to frontend repo and get started there.

### Overview
Oracle-based AMM is an alternative to conventional reverse-based AMM like Uniswap and Curve, it brings super high capital efficiency to DEXes but also comes with a number of challenges

### Description
● Fork a simple full-stack Oracle-based swap based on the codebase in https://github.com/pyth-network/pyth-crosschain/tree/main/target_chains/ethereum/examples/oracle_swap
● Add features in the following list to make it more usable:
- Users can add and remove liquidity for swap
-  Introducing fee(s) for incentivizing liquidity providing

### Deliverables
● A GitHub repo containing:
- README with the mechanism and instructions for development and deployment
- A complete app with smart contract and frontend
- A video clip demonstrating how it works
