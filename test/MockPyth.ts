import { expect } from 'chai';
import { ethers } from 'hardhat';
import { MockPyth } from '../typechain-types';
import { mockGoldPriceID, mockUSDCPriceID } from '../constants';

describe('MockPyth', async function () {
  let mockPythContract: MockPyth;

  before(async () => {
    mockPythContract = await ethers.deployContract('MockPyth');
  });

  it('should return the correct price for mockGold and mockUSDC tokens', async function () {
    const [mockGoldPrice, _mockGoldConf, mockGoldDecimals] =
      await mockPythContract.getPrice(mockGoldPriceID);
    expect(mockGoldPrice).to.eq(10000000);
    expect(mockGoldDecimals).to.eq(-6);

    const [mockUSDCPrice, _mockUSDCConf, mockUSDCDecimals] =
      await mockPythContract.getPrice(mockUSDCPriceID);
    expect(mockUSDCPrice).to.eq(1000000);
    expect(mockUSDCDecimals).to.eq(-6);
  });

  it('should execute updatePriceFeeds without any issues', async function () {
    await mockPythContract.updatePriceFeeds([], {
      value: ethers.parseEther('0.1'),
    });
  });
});
