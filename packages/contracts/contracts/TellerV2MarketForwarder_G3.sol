pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "./interfaces/ITellerV2.sol";

import "./interfaces/IMarketRegistry.sol";
import "./interfaces/ITellerV2MarketForwarder.sol";


import "./TellerV2MarketForwarder_G2.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev Simple helper contract to forward an encoded function call to the TellerV2 contract. See {TellerV2Context}
 */
abstract contract TellerV2MarketForwarder_G3 is
   TellerV2MarketForwarder_G2
{
    

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _protocolAddress, address _marketRegistryAddress) 
    TellerV2MarketForwarder_G2(_protocolAddress,_marketRegistryAddress){
       
    }
 

    /**
     * @notice Accepts a new loan using the TellerV2 lending protocol.
     * @param _bidId The id of the new loan.
     * @param _lender The address of the lender who will provide funds for the new loan.
     */
    function _acceptBidWithInterestCollector(uint256 _bidId, address _lender, address _interestCollector)
        internal
        virtual
        returns (bool)
    {
        // Approve the borrower's loan
        _forwardCall(
            abi.encodeWithSelector(ITellerV2.lenderAcceptBid.selector, _bidId),
            _lender
        );

        ITellerV2(getTellerV2()).setInterestCollector(_interestCollector);

        return true;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
