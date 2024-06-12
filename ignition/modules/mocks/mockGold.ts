import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { ethers } from 'hardhat';

export default buildModule('MockGold', (m) => {
  const mockGoldContract = m.contract('MockGold', [ethers.parseEther('100')]);

  return { mockGoldContract };
});
