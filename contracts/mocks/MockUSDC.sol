// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
  constructor(uint256 initialSupply) ERC20("USDC", "USDC") {
    _mint(msg.sender, initialSupply);
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }

  // for testing purpose
  function mint() public {
    _mint(msg.sender, 1000 * 10 ** decimals());
  }
}