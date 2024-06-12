import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { ethers } from 'hardhat';

export default buildModule('MockUSDC', (m) => {
  const USDCDecimals = 6;

  const mockUSDCContract = m.contract('MockUSDC', [
    ethers.parseUnits('1000', USDCDecimals),
  ]);

  return { mockUSDCContract };
});
