
# Fullstack web3 developer take home test
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

## hardhat commands

```shell

npx  hardhat  help

npx  hardhat  test

REPORT_GAS=true  npx  hardhat  test

npx  hardhat  node

npx  hardhat  ignition  deploy  ./ignition/modules/Lock.ts

```