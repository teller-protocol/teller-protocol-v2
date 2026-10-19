// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title RomeEvmWrappedToken
 * @notice A plain EVM-native ERC20 that wraps another ERC20 1:1.
 *
 * On Rome, ERC20s that wrap SPL tokens keep balances in Solana token
 * accounts, so every transfer of them adds Solana accounts to the
 * transaction. This wrapper keeps balances in ordinary EVM storage, which
 * keeps lending transactions within Rome's per-transaction account limit.
 *
 * `depositFor(account, amount)` pulls `amount` of the underlying token from
 * the caller and mints the same amount to `account`; `withdrawTo(account,
 * amount)` burns the caller's wrapped tokens and sends the underlying to
 * `account`.
 *
 * Decimals match the underlying token and are read once at construction, so
 * a `decimals()` call never reaches the underlying token.
 */
contract RomeEvmWrappedToken is ERC20Wrapper {
    uint8 private immutable _decimals;

    /**
     * @param underlyingToken The token being wrapped.
     * @param name_ ERC20 name.
     * @param symbol_ ERC20 symbol.
     */
    constructor(
        IERC20 underlyingToken,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC20Wrapper(underlyingToken) {
        _decimals = IERC20Metadata(address(underlyingToken)).decimals();
    }

    /// @inheritdoc ERC20Wrapper
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
