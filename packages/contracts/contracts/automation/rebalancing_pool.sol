// ERC-4626 

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TellerAutoVault
 * @dev Implementation of a generic DeFi vault following the ERC-4626 standard
 * This contract can be used as a base for creating yield-generating vaults
 */
contract TellerAutoVault is ERC4626, Ownable, ReentrancyGuard {
    // Fee configuration
    uint256 public depositFee; // Fee charged on deposits (in basis points, e.g. 50 = 0.5%)
    uint256 public withdrawalFee; // Fee charged on withdrawals (in basis points)
    uint256 public performanceFee; // Fee charged on yield (in basis points)
    uint256 private constant MAX_FEE = 1000; // Maximum fee: 10%
    uint256 private constant BASIS_POINTS = 10000; // 100% in basis points

    // Strategy configuration
    address public strategy; // Address of the yield-generating strategy
    bool public investmentEnabled; // Flag to enable/disable investment

    // Events
    event DepositFeeUpdated(uint256 newFee);
    event WithdrawalFeeUpdated(uint256 newFee);
    event PerformanceFeeUpdated(uint256 newFee);
    event StrategyUpdated(address newStrategy);
    event InvestmentStatusUpdated(bool enabled);
    event Harvested(uint256 yieldAmount);
    event FeeCollected(uint256 amount);

    /**
     * @dev Constructor
     * @param _asset Address of the underlying asset token
     * @param _name Name of the vault token
     * @param _symbol Symbol of the vault token
     * @param _owner Address of the vault owner
     */
    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC4626(IERC20Metadata(_asset)) ERC20(_name, _symbol) Ownable(_owner) {
        depositFee = 50; // Default 0.5%
        withdrawalFee = 50; // Default 0.5%
        performanceFee = 1000; // Default 10%
        investmentEnabled = true;
    }

    /**
     * @dev Calculate the total assets held by the vault
     * @return Total assets amount
     */
    function totalAssets() public view override returns (uint256) {
        // Assets in the vault plus assets deployed in strategies
        uint256 assetsInVault = IERC20(asset()).balanceOf(address(this));
        
        // If a strategy is set and active, include assets deployed there
        if (strategy != address(0) && investmentEnabled) {
            // This is a simplified approach; in practice, you'd implement
            // a proper interface to query the strategy's balance
            uint256 assetsInStrategy = estimateAssetsInStrategy();
            return assetsInVault + assetsInStrategy;
        }
        
        return assetsInVault;
    }

    /**
     * @dev Estimate assets currently deployed in the strategy
     * @return Estimated assets amount
     */
    function estimateAssetsInStrategy() public view returns (uint256) {
        // In a real implementation, you would query the strategy contract
        // This is a placeholder for demonstration
        if (strategy != address(0)) {
            try IERC20(asset()).balanceOf(strategy) returns (uint256 balance) {
                return balance;
            } catch {
                return 0;
            }
        }
        return 0;
    }

    /**
     * @dev Deposit assets and receive shares
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        // Calculate fee
        uint256 fee = (assets * depositFee) / BASIS_POINTS;
        uint256 assetsAfterFee = assets - fee;
        
        // Calculate shares based on assets after fee
        shares = convertToShares(assetsAfterFee);
        
        // Transfer assets from user
        IERC20(asset()).transferFrom(msg.sender, address(this), assets);
        
        // Mint shares to receiver
        _mint(receiver, shares);
        
        // Collect fee
        if (fee > 0) {
            collectFee(fee);
        }
        
        emit Deposit(msg.sender, receiver, assets, shares);
        
        // If investment is enabled, consider deploying to strategy
        if (investmentEnabled && strategy != address(0)) {
            _deployToStrategy();
        }
        
        return shares;
    }

    /**
     * @dev Withdraw assets by burning shares
     * @param assets Amount of assets to withdraw
     * @param receiver Address receiving the assets
     * @param owner Address that owns the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant returns (uint256 shares) {
        // Check if caller is authorized
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            require(allowed >= shares, "ERC4626: withdraw amount exceeds allowance");
            // Reduce allowance
            _approve(owner, msg.sender, allowed - shares);
        }
        
        // Calculate shares needed for requested assets
        shares = convertToShares(assets);
        
        // Calculate fee
        uint256 fee = (assets * withdrawalFee) / BASIS_POINTS;
        uint256 assetsAfterFee = assets - fee;
        
        // Ensure sufficient liquidity
        uint256 availableLiquidity = IERC20(asset()).balanceOf(address(this));
        
        // If not enough liquidity and strategy is set, withdraw from strategy
        if (availableLiquidity < assets && strategy != address(0)) {
            _withdrawFromStrategy(assets - availableLiquidity);
        }
        
        // Burn shares
        _burn(owner, shares);
        
        // Transfer assets to receiver
        IERC20(asset()).transfer(receiver, assetsAfterFee);
        
        // Collect fee
        if (fee > 0) {
            collectFee(fee);
        }
        
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        
        return shares;
    }

    /**
     * @dev Collect fees to the owner address
     * @param amount Amount of fee to collect
     */
    function collectFee(uint256 amount) internal {
        if (amount > 0) {
            IERC20(asset()).transfer(owner(), amount);
            emit FeeCollected(amount);
        }
    }

    /**
     * @dev Deploy available assets to the strategy
     * Internal function to be called after deposits or during rebalancing
     */
    function _deployToStrategy() internal {
        if (strategy == address(0) || !investmentEnabled) {
            return;
        }
        
        uint256 available = IERC20(asset()).balanceOf(address(this));
        uint256 reserveAmount = (totalAssets() * 10) / 100; // Keep 10% as reserve
        
        if (available > reserveAmount) {
            uint256 investAmount = available - reserveAmount;
            
            // In a real implementation, you would call the strategy contract
            // to deposit funds. This is simplified for demonstration.
            IERC20(asset()).approve(strategy, investAmount);
            // Call strategy's deposit function
            // IStrategy(strategy).deposit(investAmount);
            
            // For simplicity, we're just transferring to the strategy address here
            IERC20(asset()).transfer(strategy, investAmount);
        }
    }

    /**
     * @dev Withdraw assets from strategy
     * @param amount Amount of assets to withdraw
     */
    function _withdrawFromStrategy(uint256 amount) internal {
        if (strategy == address(0)) {
            return;
        }
        
        // In a real implementation, you would call the strategy contract
        // to withdraw funds. This is simplified for demonstration.
        // IStrategy(strategy).withdraw(amount);
        
        // Instead of calling the strategy, we'll just emit an event for demonstration
        emit WithdrawFromStrategy(amount);
    }

    /**
     * @dev Event for strategy withdrawals (for demonstration)
     */
    event WithdrawFromStrategy(uint256 amount);

    /**
     * @dev Harvest yield from the strategy
     * Can only be called by the owner
     */
    function harvest() external onlyOwner {
        if (strategy == address(0)) {
            return;
        }
        
        // In a real implementation, you would call the strategy to realize gains
        // uint256 yieldGenerated = IStrategy(strategy).harvest();
        
        // For demonstration, we'll define a mock yield value
        uint256 yieldGenerated = 0; // Replace with actual yield calculation
        
        // Calculate performance fee
        uint256 fee = (yieldGenerated * performanceFee) / BASIS_POINTS;
        
        // Collect performance fee
        if (fee > 0) {
            collectFee(fee);
        }
        
        emit Harvested(yieldGenerated);
    }

    /**
     * @dev Set deposit fee
     * @param _fee New deposit fee (in basis points)
     */
    function setDepositFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_FEE, "Fee too high");
        depositFee = _fee;
        emit DepositFeeUpdated(_fee);
    }

    /**
     * @dev Set withdrawal fee
     * @param _fee New withdrawal fee (in basis points)
     */
    function setWithdrawalFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_FEE, "Fee too high");
        withdrawalFee = _fee;
        emit WithdrawalFeeUpdated(_fee);
    }

    /**
     * @dev Set performance fee
     * @param _fee New performance fee (in basis points)
     */
    function setPerformanceFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_FEE, "Fee too high");
        performanceFee = _fee;
        emit PerformanceFeeUpdated(_fee);
    }

    /**
     * @dev Set strategy address
     * @param _strategy New strategy address
     */
    function setStrategy(address _strategy) external onlyOwner {
        // If there's an existing strategy, withdraw all funds first
        if (strategy != address(0)) {
            // Call the strategy to withdraw all funds
            // IStrategy(strategy).withdrawAll();
        }
        
        strategy = _strategy;
        emit StrategyUpdated(_strategy);
        
        // If investment is enabled and assets are available, deploy to the new strategy
        if (investmentEnabled && _strategy != address(0)) {
            _deployToStrategy();
        }
    }

    /**
     * @dev Enable or disable investment
     * @param _enabled Whether investment should be enabled
     */
    function setInvestmentEnabled(bool _enabled) external onlyOwner {
        investmentEnabled = _enabled;
        emit InvestmentStatusUpdated(_enabled);
        
        // If enabling investment and strategy is set, deploy available funds
        if (_enabled && strategy != address(0)) {
            _deployToStrategy();
        }
        // If disabling investment and strategy is set, withdraw all funds
        else if (!_enabled && strategy != address(0)) {
            // Withdraw all funds from the strategy
            // IStrategy(strategy).withdrawAll();
        }
    }

    /**
     * @dev Emergency function to pause all operations
     * Only callable by owner
     */
    function emergencyShutdown() external onlyOwner {
        investmentEnabled = false;
        emit InvestmentStatusUpdated(false);
        
        // Withdraw all funds from strategy if one is set
        if (strategy != address(0)) {
            // IStrategy(strategy).withdrawAll();
        }
    }

    /**
     * @dev Preview conversion of assets to shares
     * Overridden to handle fees
     */
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        uint256 fee = (assets * depositFee) / BASIS_POINTS;
        return convertToShares(assets - fee);
    }

    /**
     * @dev Preview conversion of shares to assets
     * Overridden to handle fees
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 fee = (assets * withdrawalFee) / BASIS_POINTS;
        return convertToShares(assets + fee);
    }
}