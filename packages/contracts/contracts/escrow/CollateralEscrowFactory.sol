// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./CollateralEscrowV1.sol";

contract CollateralEscrowFactory is OwnableUpgradeable {

    address private _collateralEscrowBeacon;
    mapping(uint256 => address) public _escrows; // bidIds -> collateralEscrow

    /* Events */
    event CollateralEscrowDeployed(uint256 _bidId, address collateralEscrow);

    /**
     * @notice Initializes the escrow factory.
     * @param _collateralEscrowBeacon The address of the escrow implementation.
     */
    function initialize(address _collateralEscrowBeacon) external {
        _collateralEscrowBeacon = _collateralEscrowBeacon;
        __Ownable_init();
    }

    /**
     * @notice Deploys a new collateral escrow.
     * @param _bidId The associated bidId of the collateral escrow.
     */
    function deployCollateralEscrow(uint256 _bidId)
        external
        returns(address)
    {
        BeaconProxy proxy_ = new BeaconProxy(
            _collateralEscrowBeacon,
            abi.encodeWithSelector(CollateralEscrowV1.initialize.selector, _bidId)
        );
        _escrows[_bidId] = address(proxy_);
        emit CollateralEscrowDeployed(_bidId, address(proxy_));
        return address(proxy_);
    }

    /**
     * @notice Gets the address of a deployed escrow.
     * @notice _bidId The bidId to return the escrow for.
     * @return The address of the escrow.
     */
    function getEscrow(uint256 _bidId)
        external
        view
        returns(address)
    {
        return _escrows[_bidId];
    }
}