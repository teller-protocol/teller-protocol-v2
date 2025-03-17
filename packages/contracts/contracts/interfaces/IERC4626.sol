pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

 
interface IERC4626 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emitted when assets are deposited into the vault.
     * @param caller The caller who deposited the assets.
     * @param owner The owner who will receive the shares.
     * @param assets The amount of assets deposited.
     * @param shares The amount of shares minted.
     */
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    /**
     * @dev Emitted when shares are withdrawn from the vault.
     * @param caller The caller who withdrew the assets.
     * @param receiver The receiver of the assets.
     * @param owner The owner whose shares were burned.
     * @param assets The amount of assets withdrawn.
     * @param shares The amount of shares burned.
     */
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the address of the underlying token used for the vault.
     * @return The address of the underlying asset token.
     */
    function asset() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Deposits assets into the vault and mints shares to the receiver.
     * @param assets The amount of assets to deposit.
     * @param receiver The address that will receive the shares.
     * @return shares The amount of shares minted.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev Mints shares to the receiver by depositing exactly amount of assets.
     * @param shares The amount of shares to mint.
     * @param receiver The address that will receive the shares.
     * @return assets The amount of assets deposited.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev Withdraws assets from the vault to the receiver by burning shares from owner.
     * @param assets The amount of assets to withdraw.
     * @param receiver The address that will receive the assets.
     * @param owner The address whose shares will be burned.
     * @return shares The amount of shares burned.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @dev Burns shares from owner and sends exactly assets to receiver.
     * @param shares The amount of shares to burn.
     * @param receiver The address that will receive the assets.
     * @param owner The address whose shares will be burned.
     * @return assets The amount of assets sent to the receiver.
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the total amount of assets managed by the vault.
     * @return The total amount of assets.
     */
    function totalAssets() external view returns (uint256);

    /**
     * @dev Calculates the amount of shares that would be minted for a given amount of assets.
     * @param assets The amount of assets to deposit.
     * @return shares The amount of shares that would be minted.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Calculates the amount of assets that would be withdrawn for a given amount of shares.
     * @param shares The amount of shares to burn.
     * @return assets The amount of assets that would be withdrawn.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Calculates the maximum amount of assets that can be deposited for a specific receiver.
     * @param receiver The address of the receiver.
     * @return maxAssets The maximum amount of assets that can be deposited.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @dev Simulates the effects of a deposit at the current block, given current on-chain conditions.
     * @param assets The amount of assets to deposit.
     * @return shares The amount of shares that would be minted.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Calculates the maximum amount of shares that can be minted for a specific receiver.
     * @param receiver The address of the receiver.
     * @return maxShares The maximum amount of shares that can be minted.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @dev Simulates the effects of a mint at the current block, given current on-chain conditions.
     * @param shares The amount of shares to mint.
     * @return assets The amount of assets that would be deposited.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Calculates the maximum amount of assets that can be withdrawn by a specific owner.
     * @param owner The address of the owner.
     * @return maxAssets The maximum amount of assets that can be withdrawn.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @dev Simulates the effects of a withdrawal at the current block, given current on-chain conditions.
     * @param assets The amount of assets to withdraw.
     * @return shares The amount of shares that would be burned.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Calculates the maximum amount of shares that can be redeemed by a specific owner.
     * @param owner The address of the owner.
     * @return maxShares The maximum amount of shares that can be redeemed.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Simulates the effects of a redemption at the current block, given current on-chain conditions.
     * @param shares The amount of shares to redeem.
     * @return assets The amount of assets that would be withdrawn.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
}