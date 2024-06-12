import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

export default buildModule('MockPyth', (m) => {
  const mockPythContract = m.contract('MockPyth', []);

  return { mockPythContract };
});
