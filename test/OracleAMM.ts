import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { MockGold, MockPyth, MockUSDC, OracleAMM } from '../typechain-types';
import { mockGoldPriceID, mockUSDCPriceID, USDCDecimals } from '../constants';

describe('OracleAMM', function () {
  let amm: OracleAMM;
  let mockGoldContract: MockGold;
  let mockPythContract: MockPyth;
  let mockUSDCContract: MockUSDC;
  let newUser: HardhatEthersSigner;
  let owner: HardhatEthersSigner;

  async function deployContractsFixture() {
    mockGoldContract = await ethers.deployContract('MockGold', [
      ethers.parseEther('150'),
    ]);
    mockUSDCContract = await ethers.deployContract('MockUSDC', [
      ethers.parseUnits('1500', USDCDecimals),
    ]);
    mockPythContract = await ethers.deployContract('MockPyth');
    amm = await ethers.deployContract('OracleAMM', [
      mockPythContract.target,
      mockGoldPriceID,
      mockUSDCPriceID,
      mockGoldContract.target,
      mockUSDCContract.target,
    ]);

    [owner, newUser] = await ethers.getSigners();

    const tx = await owner.sendTransaction({
      to: amm.target,
      value: ethers.parseEther('1'),
    });
    await tx.wait();

    await mockGoldContract.approve(owner.address, ethers.MaxUint256);
    await mockUSDCContract.approve(owner.address, ethers.MaxUint256);

    await mockGoldContract.approve(amm.target, ethers.MaxUint256);
    await mockUSDCContract.approve(amm.target, ethers.MaxUint256);

    await mockGoldContract
      .connect(newUser)
      .approve(amm.target, ethers.MaxUint256);
    await mockUSDCContract
      .connect(newUser)
      .approve(amm.target, ethers.MaxUint256);

    await mockGoldContract.transferFrom(
      owner.address,
      newUser.address,
      ethers.parseEther('50')
    );
    await mockUSDCContract.transferFrom(
      owner.address,
      newUser.address,
      ethers.parseUnits('500', USDCDecimals)
    );
  }

  before(async () => {
    await loadFixture(deployContractsFixture);
  });

  it('should check owner balance of deployed mock tokens is correct', async function () {
    const ownerGoldBalance = await mockGoldContract.balanceOf(owner.address);
    const ownerUSDCBalance = await mockUSDCContract.balanceOf(owner.address);

    expect(ownerGoldBalance).to.eq(ethers.parseEther('100'));
    expect(ownerUSDCBalance).to.eq(ethers.parseUnits('1000', USDCDecimals));
  });

  it('should check newUser balance of deployed mock tokens is correct', async function () {
    const newUserGoldBalance = await mockGoldContract.balanceOf(
      newUser.address
    );
    const newUserUSDCBalance = await mockUSDCContract.balanceOf(
      newUser.address
    );

    expect(newUserGoldBalance).to.eq(ethers.parseEther('50'));
    expect(newUserUSDCBalance).to.eq(ethers.parseUnits('500', USDCDecimals));
  });

  it('Should add liquidity to the pool', async function () {
    const GoldAmt = '100.0';
    const USDCAmt = '1000.0';

    await amm.addLiquidity(
      ethers.parseEther(GoldAmt),
      ethers.parseUnits(USDCAmt, USDCDecimals),
      []
    );

    const ammGoldBalance = await mockGoldContract.balanceOf(amm.target);
    const ammUSDCBalance = await mockUSDCContract.balanceOf(amm.target);

    expect(ethers.formatEther(ammGoldBalance)).to.eq(GoldAmt);
    expect(ethers.formatUnits(ammUSDCBalance, USDCDecimals)).to.eq(USDCAmt);

    expect(await mockGoldContract.balanceOf(owner.address)).to.eq(0);
    expect(await mockUSDCContract.balanceOf(owner.address)).to.eq(0);
  });

  it('Should swap tokens and accrue fees', async function () {
    await amm.connect(newUser).swap(true, ethers.parseEther('10'), [])

    let newUserGoldBalance = await mockGoldContract.balanceOf(newUser.address);
    let newUserUSDCBalance = await mockUSDCContract.balanceOf(newUser.address);

    expect(newUserGoldBalance).to.eq(ethers.parseEther('59.9'));
    expect(newUserUSDCBalance).to.eq(ethers.parseUnits('400', USDCDecimals));

    expect(await amm.baseFeesAccrued()).to.eq(ethers.parseEther('0.1'));
    expect(await amm.quoteFeesAccrued()).to.eq(0);

    await amm.connect(newUser).swap(false, ethers.parseEther('10'), []);

    newUserGoldBalance = await mockGoldContract.balanceOf(newUser.address);
    newUserUSDCBalance = await mockUSDCContract.balanceOf(newUser.address);

    expect(newUserGoldBalance).to.eq(ethers.parseEther('49.9'));
    expect(newUserUSDCBalance).to.eq(ethers.parseUnits('499', USDCDecimals));

    expect(await amm.baseFeesAccrued()).to.eq(ethers.parseEther('0.1'));
    expect(await amm.quoteFeesAccrued()).to.eq(
      ethers.parseUnits('1', USDCDecimals)
    );
  });

  it('should remove liquidity with any fees user accrued', async function () {
    await amm.connect(owner).removeLiquidity(ethers.parseEther('100'), []);

    const ownerGoldBalance = await mockGoldContract.balanceOf(owner.address);
    const ownerUSDCBalance = await mockUSDCContract.balanceOf(owner.address);

    expect(ownerGoldBalance).to.eq(100099900099900099900n);
    expect(ownerUSDCBalance).to.eq(1000999000n);
  });
});
