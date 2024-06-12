import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { ethers } from 'hardhat';

import { mockGoldPriceID, mockUSDCPriceID } from '../../constants';
import mockGoldModule from './mocks/mockGold';
import mockUSDCModule from './mocks/mockUSDC';
import mockPythModule from './mocks/mockPyth';

export default buildModule('OracleAMM', (m) => {
  const { mockGoldContract } = m.useModule(mockGoldModule);
  const { mockUSDCContract } = m.useModule(mockUSDCModule);
  const { mockPythContract } = m.useModule(mockPythModule);

  const oracleAMMContract = m.contract('OracleAMM', [
    mockPythContract,
    mockGoldPriceID,
    mockUSDCPriceID,
    mockGoldContract,
    mockUSDCContract,
  ]);

  m.send('SendingEth', oracleAMMContract, ethers.parseEther('1'));

  return { oracleAMMContract };
});
