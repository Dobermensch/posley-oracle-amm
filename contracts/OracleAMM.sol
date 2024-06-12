// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@pythnetwork/pyth-sdk-solidity/IPyth.sol';
import '@pythnetwork/pyth-sdk-solidity/PythStructs.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

// Example oracle AMM powered by Pyth price feeds.
//
// The contract holds a pool of two ERC-20 tokens, the BASE and the QUOTE, and allows users to swap tokens
// for the pair BASE/QUOTE. For example, the base could be WETH and the quote could be USDC, in which case you can
// buy WETH for USDC and vice versa. The pool offers to swap between the tokens at the current Pyth exchange rate for
// BASE/QUOTE, which is computed from the BASE/USD price feed and the QUOTE/USD price feed.
//
// This contract only implements the swap functionality. It does not implement any pool balancing logic (e.g., skewing the
// price to reflect an unbalanced pool) or depositing / withdrawing funds. When deployed, the contract needs to be sent
// some quantity of both the base and quote token in order to function properly (using the ERC20 transfer function to
// the contract's address).
contract OracleAMM is ReentrancyGuard {
  event Transfer(
    address from,
    address to,
    uint256 amountUsd,
    uint256 amountWei
  );

  IPyth pyth;

  bytes32 baseTokenPriceId;
  bytes32 quoteTokenPriceId;

  uint8 private constant decimals = 18;
  uint256 public constant feePercentage = 100; // 1% fee
  uint256 private constant maxDecimals = 10 ** decimals;

  ERC20 public baseToken;
  ERC20 public quoteToken;

  uint256 public totalBaseLiquidity;
  uint256 public totalQuoteLiquidity;

  uint256 public baseFeesAccrued;
  uint256 public quoteFeesAccrued;

  uint256 public baseTokenDecimals;
  uint256 public quoteTokenDecimals;

  mapping(address => uint256) public baseLiquidityProvided;
  mapping(address => uint256) public quoteLiquidityProvided;

  constructor(
    address _pyth,
    bytes32 _baseTokenPriceId,
    bytes32 _quoteTokenPriceId,
    address _baseToken,
    address _quoteToken
  ) {
    pyth = IPyth(_pyth);
    baseTokenPriceId = _baseTokenPriceId;
    quoteTokenPriceId = _quoteTokenPriceId;
    baseToken = ERC20(_baseToken);
    quoteToken = ERC20(_quoteToken);
    baseTokenDecimals = baseToken.decimals();
    quoteTokenDecimals = quoteToken.decimals();
  }

  // Buy or sell a quantity of the base token. `size` represents the quantity of the base token with the same number
  // of decimals as expected by its ERC-20 implementation. If `isBuy` is true, the contract will send the caller
  // `size` base tokens; if false, `size` base tokens will be transferred from the caller to the contract. Some
  // number of quote tokens will be transferred in the opposite direction; the exact number will be determined by
  // the current pyth price. The transaction will fail if either the pool or the sender does not have enough of the
  // requisite tokens for these transfers.
  //
  // `pythUpdateData` is the binary pyth price update data (retrieved from Pyth's price
  // service); this data should contain a price update for both the base and quote price feeds.
  // See the frontend code for an example of how to retrieve this data and pass it to this function.
  function swap(
    bool isBuy,
    uint256 size,
    bytes[] calldata pythUpdateData
  ) external payable {
    uint256 updateFee = pyth.getUpdateFee(pythUpdateData);
    pyth.updatePriceFeeds{value: updateFee}(pythUpdateData);

    PythStructs.Price memory currentBasePrice = pyth.getPrice(baseTokenPriceId);
    PythStructs.Price memory currentQuotePrice = pyth.getPrice(
      quoteTokenPriceId
    );

    // Note: this code does all arithmetic with 18 decimal points. This approach should be fine for most
    // price feeds, which typically have ~8 decimals. You can check the exponent on the price feed to ensure
    // this doesn't lose precision.
    uint256 basePrice = convertToUint(
      currentBasePrice.price,
      currentBasePrice.expo,
      decimals
    );
    uint256 quotePrice = convertToUint(
      currentQuotePrice.price,
      currentQuotePrice.expo,
      decimals
    );

    // This computation loses precision. The infinite-precision result is between [quoteSize, quoteSize + 1]
    // We need to round this result in favor of the contract.
    uint256 quoteSize = (size * basePrice) / quotePrice;

    if (isBuy) {
      // (Round up)
      quoteSize += 1;

      uint256 baseFees = (size * feePercentage) / 10000;
      uint256 baseAmountAfterFees = size - baseFees;

      baseFeesAccrued += baseFees;

      require(
        baseAmountAfterFees < baseBalance(),
        'Not enough base tokens liquidity'
      );

      uint256 adjustedQuoteSize = quoteSize /
        10 ** (baseTokenDecimals - quoteTokenDecimals);

      quoteToken.transferFrom(msg.sender, address(this), adjustedQuoteSize);
      uint256 quoteTokenPriceUSD = (quotePrice * adjustedQuoteSize) /
        (10 ** (decimals + quoteTokenDecimals));
      uint256 quoteTokenPriceWei = quoteTokenPriceUSD * maxDecimals;
      emit Transfer(
        msg.sender,
        address(this),
        quoteTokenPriceUSD,
        quoteTokenPriceWei
      );

      baseToken.transfer(msg.sender, baseAmountAfterFees);
      uint256 baseTokenPriceUSD = (baseAmountAfterFees * basePrice) /
        (10 ** (decimals + baseTokenDecimals));
      uint256 baseTokenPriceWei = baseTokenPriceUSD * maxDecimals;
      emit Transfer(
        address(this),
        msg.sender,
        baseTokenPriceUSD,
        baseTokenPriceWei
      );

      totalBaseLiquidity -= baseAmountAfterFees;
      totalQuoteLiquidity += adjustedQuoteSize;
    } else {
      uint256 quoteFees = (quoteSize * feePercentage) / 10000;
      uint256 quoteAmountAfterFees = quoteSize - quoteFees;

      quoteFeesAccrued +=
        quoteFees /
        10 ** (baseTokenDecimals - quoteTokenDecimals);

      uint256 adjustedQuoteAmount = quoteAmountAfterFees /
        10 ** (baseTokenDecimals - quoteTokenDecimals);

      require(
        adjustedQuoteAmount < quoteBalance(),
        'Not enough quote tokens liquidity'
      );

      baseToken.transferFrom(msg.sender, address(this), size);
      uint256 baseTokenPriceUSD = (size * basePrice) /
        (10 ** (decimals + baseTokenDecimals));
      uint256 baseTokenPriceWei = baseTokenPriceUSD * maxDecimals;
      emit Transfer(
        msg.sender,
        address(this),
        baseTokenDecimals,
        baseTokenPriceWei
      );

      quoteToken.transfer(msg.sender, adjustedQuoteAmount);
      uint256 quoteTokenPriceUSD = (adjustedQuoteAmount * quotePrice) /
        (10 ** (decimals + quoteTokenDecimals));
      uint256 quoteTokenPriceWei = quoteTokenPriceUSD * maxDecimals;
      emit Transfer(
        address(this),
        msg.sender,
        quoteTokenPriceUSD,
        quoteTokenPriceWei
      );

      totalBaseLiquidity += size;
      totalQuoteLiquidity -= adjustedQuoteAmount;
    }
  }

  // Get the number of base tokens in the pool
  function baseBalance() public view returns (uint256) {
    return baseToken.balanceOf(address(this));
  }

  // Get the number of quote tokens in the pool
  function quoteBalance() public view returns (uint256) {
    return quoteToken.balanceOf(address(this));
  }

  function addLiquidity(
    uint256 baseAmount,
    uint256 quoteAmount,
    bytes[] calldata pythUpdateData
  ) external nonReentrant {
    require(
      baseAmount > 0 && quoteAmount > 0,
      'token amounts must be greater than zero'
    );

    uint256 updateFee = pyth.getUpdateFee(pythUpdateData);
    pyth.updatePriceFeeds{value: updateFee}(pythUpdateData);

    // Calculate current prices from oracle
    PythStructs.Price memory currentTokenDetails = pyth.getPrice(
      baseTokenPriceId
    );
    uint256 basePrice = convertToUint(
      currentTokenDetails.price,
      currentTokenDetails.expo,
      decimals
    );

    currentTokenDetails = pyth.getPrice(quoteTokenPriceId);
    uint256 quotePrice = convertToUint(
      currentTokenDetails.price,
      currentTokenDetails.expo,
      decimals
    );

    uint256 expectedQuoteAmount = (baseAmount * basePrice) / quotePrice;
    uint256 adjustedQuoteAmount = quoteAmount;

    if (baseTokenDecimals > quoteTokenDecimals) {
      adjustedQuoteAmount =
        adjustedQuoteAmount *
        10 ** (baseTokenDecimals - quoteTokenDecimals);
    }

    require(
      adjustedQuoteAmount == expectedQuoteAmount,
      'Unbalanced amounts provided'
    );

    baseToken.transferFrom(msg.sender, address(this), baseAmount);
    uint256 baseTokenPriceUSD = (baseAmount * basePrice) /
      (10 ** (decimals + baseTokenDecimals));
    uint256 baseTokenPriceWei = baseTokenPriceUSD * maxDecimals;
    emit Transfer(
      msg.sender,
      address(this),
      baseTokenPriceUSD,
      baseTokenPriceWei
    );

    quoteToken.transferFrom(msg.sender, address(this), quoteAmount);
    uint256 quoteTokenPriceUSD = (adjustedQuoteAmount * quotePrice) /
      (10 ** (decimals + quoteTokenDecimals));
    uint256 quoteTokenPriceWei = quoteTokenPriceUSD * maxDecimals;
    emit Transfer(
      address(this),
      msg.sender,
      quoteTokenPriceUSD,
      quoteTokenPriceWei
    );

    baseLiquidityProvided[msg.sender] += baseAmount;
    quoteLiquidityProvided[msg.sender] += quoteAmount;

    totalBaseLiquidity += baseAmount;
    totalQuoteLiquidity += quoteAmount;
  }

  function removeLiquidity(
    uint256 baseAmount,
    bytes[] calldata pythUpdateData
  ) external nonReentrant {
    require(
      baseLiquidityProvided[msg.sender] >= baseAmount,
      'Not enough user base token liquidity'
    );

    uint256 updateFee = pyth.getUpdateFee(pythUpdateData);
    pyth.updatePriceFeeds{value: updateFee}(pythUpdateData);

    // Calculate current prices from oracle
    PythStructs.Price memory currentBasePrice = pyth.getPrice(baseTokenPriceId);
    PythStructs.Price memory currentQuotePrice = pyth.getPrice(
      quoteTokenPriceId
    );

    uint256 basePrice = convertToUint(
      currentBasePrice.price,
      currentBasePrice.expo,
      decimals
    );
    uint256 quotePrice = convertToUint(
      currentQuotePrice.price,
      currentQuotePrice.expo,
      decimals
    );

    uint256 quoteAmount = (baseAmount * basePrice) / quotePrice;

    uint256 adjustedQuoteAmount = quoteAmount /
      10 ** (baseTokenDecimals - quoteTokenDecimals);

    require(
      quoteLiquidityProvided[msg.sender] >= adjustedQuoteAmount,
      'Not enough user quote token liquidity'
    );

    uint256 userBaseFees = (baseFeesAccrued *
      baseLiquidityProvided[msg.sender]) / totalBaseLiquidity;
    uint256 userQuoteFees = (quoteFeesAccrued *
      quoteLiquidityProvided[msg.sender]) / totalQuoteLiquidity;

    baseFeesAccrued -= userBaseFees;
    quoteFeesAccrued -= userQuoteFees;

    if (baseLiquidityProvided[msg.sender] != 0) {
      baseLiquidityProvided[msg.sender] -= baseAmount;
      quoteLiquidityProvided[msg.sender] -= adjustedQuoteAmount;
    }

    totalBaseLiquidity -= baseAmount;
    totalQuoteLiquidity -= adjustedQuoteAmount;

    uint256 totalBaseAmountToRemove = baseAmount + userBaseFees;
    uint256 totalQuoteAmountToRemove = adjustedQuoteAmount + userQuoteFees;

    require(
      totalBaseAmountToRemove < baseBalance(),
      'Not enough base tokens liquidity'
    );
    require(
      totalQuoteAmountToRemove < quoteBalance(),
      'Not enough quote tokens liquidity'
    );

    baseToken.transfer(msg.sender, totalBaseAmountToRemove);
    uint256 totalBaseAmountToRemoveUSD = totalBaseAmountToRemove /
      (10 ** baseTokenDecimals);
    uint256 totalBaseAmountToRemoveWei = totalBaseAmountToRemoveUSD *
      maxDecimals;
    emit Transfer(
      address(this),
      msg.sender,
      totalBaseAmountToRemoveUSD,
      totalBaseAmountToRemoveWei
    );

    quoteToken.transfer(msg.sender, totalQuoteAmountToRemove);
    uint256 totalQuoteAmountToRemoveUSD = totalQuoteAmountToRemove /
      (10 ** quoteTokenDecimals);
    uint256 totalQuoteAmountToRemoveWei = totalQuoteAmountToRemoveUSD *
      maxDecimals;
    emit Transfer(
      address(this),
      msg.sender,
      totalQuoteAmountToRemoveUSD,
      totalQuoteAmountToRemoveWei
    );
  }

  function convertToUint(
    int64 price,
    int32 expo,
    uint8 targetDecimals
  ) internal pure returns (uint256) {
    if (price < 0 || expo > 0 || expo < -255) {
      revert();
    }

    uint8 priceDecimals = uint8(uint32(-1 * expo));

    if (targetDecimals >= priceDecimals) {
      return
        uint256(uint64(price)) * 10 ** uint32(targetDecimals - priceDecimals);
    } else {
      return
        uint256(uint64(price)) / 10 ** uint32(priceDecimals - targetDecimals);
    }
  }

  // Send all tokens in the oracle AMM pool to the caller of this method.
  // (This function is for demo purposes only. You wouldn't include this on a real contract.)
  function withdrawAll() external {
    baseToken.transfer(msg.sender, baseToken.balanceOf(address(this)));
    quoteToken.transfer(msg.sender, quoteToken.balanceOf(address(this)));
  }

  // Reinitialize the parameters of this contract.
  // (This function is for demo purposes only. You wouldn't include this on a real contract.)
  function reinitialize(
    bytes32 _baseTokenPriceId,
    bytes32 _quoteTokenPriceId,
    address _baseToken,
    address _quoteToken
  ) external {
    baseTokenPriceId = _baseTokenPriceId;
    quoteTokenPriceId = _quoteTokenPriceId;
    baseToken = ERC20(_baseToken);
    quoteToken = ERC20(_quoteToken);
  }

  receive() external payable {}
}
