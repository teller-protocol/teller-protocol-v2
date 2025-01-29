// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract LenderPoolPauseableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pool pause is triggered by `account`.
     */
    event PoolPaused(address account);
    event PoolUnpaused(address account);

    /**
     * @dev Emitted when borrowing is paused/unpaused.
     */
    event BorrowingPaused(address account);
    event BorrowingUnpaused(address account);

    /**
     * @dev Emitted when staking is paused/unpaused.
     */
    event StakingPaused(address account);
    event StakingUnpaused(address account);

    /**
     * @dev Emitted when liquidation is paused/unpaused.
     */
    event LiquidationPaused(address account);
    event LiquidationUnpaused(address account);

 
    /*
    In Solidity, bool values consume 1 byte in storage, even though they technically only need a single bit. 
    Solidity packs multiple bool values into a single 32-byte (256-bit) storage slot whenever possible.
    */

    bool private _poolPaused;

    bool private _borrowingPaused;

    bool private _stakingPaused;

    bool private _liquidationPaused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _poolPaused = false;
        _borrowingPaused = false;
        _stakingPaused = false;
        _liquidationPaused = false;
    }

    

     // ========================== POOL PAUSE ==========================
    
    modifier whenPoolNotPaused() {
        _requirePoolNotPaused();
        _;
    }

    modifier whenPoolPaused() {
        _requirePoolPaused();
        _;
    }

    function poolPaused() public view virtual returns (bool) {
        return _poolPaused;
    }

    function _requirePoolNotPaused() internal view virtual {
        require(!_poolPaused, "Pausable: Pool is paused");
    }

    function _requirePoolPaused() internal view virtual {
        require(_poolPaused, "Pausable: Pool is not paused");
    }

    function _pausePool() internal virtual whenPoolNotPaused {
        _poolPaused = true;
        emit PoolPaused(_msgSender());
    }

    function _unpausePool() internal virtual whenPoolPaused {
        _poolPaused = false;
        emit PoolUnpaused(_msgSender());
    }

    // ========================== BORROWING PAUSE ==========================

    modifier whenBorrowingNotPaused() {
        _requireBorrowingNotPaused();
        _;
    }

    modifier whenBorrowingPaused() {
        _requireBorrowingPaused();
        _;
    }

    function borrowingPaused() public view virtual returns (bool) {
        return _borrowingPaused;
    }

    function _requireBorrowingNotPaused() internal view virtual {
        require(!_borrowingPaused, "Pausable: Borrowing is paused");
    }

    function _requireBorrowingPaused() internal view virtual {
        require(_borrowingPaused, "Pausable: Borrowing is not paused");
    }

    function _pauseBorrowing() internal virtual whenBorrowingNotPaused {
        _borrowingPaused = true;
        emit BorrowingPaused(_msgSender());
    }

    function _unpauseBorrowing() internal virtual whenBorrowingPaused {
        _borrowingPaused = false;
        emit BorrowingUnpaused(_msgSender());
    }

    // ========================== STAKING PAUSE ==========================

    modifier whenStakingNotPaused() {
        _requireStakingNotPaused();
        _;
    }

    modifier whenStakingPaused() {
        _requireStakingPaused();
        _;
    }

    function stakingPaused() public view virtual returns (bool) {
        return _stakingPaused;
    }

    function _requireStakingNotPaused() internal view virtual {
        require(!_stakingPaused, "Pausable: Staking is paused");
    }

    function _requireStakingPaused() internal view virtual {
        require(_stakingPaused, "Pausable: Staking is not paused");
    }

    function _pauseStaking() internal virtual whenStakingNotPaused {
        _stakingPaused = true;
        emit StakingPaused(_msgSender());
    }

    function _unpauseStaking() internal virtual whenStakingPaused {
        _stakingPaused = false;
        emit StakingUnpaused(_msgSender());
    }

    // ========================== LIQUIDATION PAUSE ==========================

    modifier whenLiquidationNotPaused() {
        _requireLiquidationNotPaused();
        _;
    }

    modifier whenLiquidationPaused() {
        _requireLiquidationPaused();
        _;
    }

    function liquidationPaused() public view virtual returns (bool) {
        return _liquidationPaused;
    }

    function _requireLiquidationNotPaused() internal view virtual {
        require(!_liquidationPaused, "Pausable: Liquidation is paused");
    }

    function _requireLiquidationPaused() internal view virtual {
        require(_liquidationPaused, "Pausable: Liquidation is not paused");
    }

    function _pauseLiquidation() internal virtual whenLiquidationNotPaused {
        _liquidationPaused = true;
        emit LiquidationPaused(_msgSender());
    }

    function _unpauseLiquidation() internal virtual whenLiquidationPaused {
        _liquidationPaused = false;
        emit LiquidationUnpaused(_msgSender());
    }



    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
