// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract MockPyth {
  uint private updateFee;
  struct Price {
    // Price
    int64 price;
    // Confidence interval around the price
    uint64 conf;
    // Price exponent
    int32 expo;
    // Unix timestamp describing when the price was published
    uint publishTime;
  }

  uint256 public receivedAmount;

  bytes32 private mockGoldPriceFeedId = 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;

  constructor() {
    updateFee = 0.00000001 ether;
  }

  function getUpdateFee(bytes[] calldata pythUpdateData) public view returns (uint256) {
    return updateFee;
  }

  function updatePriceFeeds(bytes[] calldata _pythUpdateData) public payable {
    receivedAmount += msg.value;
  }

  function getPrice(bytes32 priceFeedId) public view returns (Price memory) {
    if (priceFeedId == mockGoldPriceFeedId) {
      return Price (
        10000000,
        90,
        -6,
        block.timestamp
      );
    }
    return Price (
      1000000,
      90,
      -6,
      block.timestamp
    );
  }
}