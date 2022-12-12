// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../LenderManager.sol";

contract ActivateableLenderManager is LenderManager {
    constructor(address _trustedForwarder, address _marketRegistry)
        LenderManager(_trustedForwarder, _marketRegistry)
    {}

    function initializeActiveLoans(
        address _newOwner,
        uint256[] calldata _initialActiveBidIds,
        address[] calldata _initialActiveLenderArray
    ) external initializer {
        __LenderManager_init();
        _transferOwnership(_newOwner);
        _setActiveLoanLenders(_initialActiveBidIds, _initialActiveLenderArray);
    }

    /**
     * @notice Sets the initial list of active loan lenders for TellerV2.
     * @param _initialActiveBidIds Array containing the list of bidIds.
     * @param _initialActiveLenderArray Array of the associated active lender addresses.
     */
    function _setActiveLoanLenders(
        uint256[] calldata _initialActiveBidIds,
        address[] calldata _initialActiveLenderArray
    ) internal onlyInitializing {
        require(
            _initialActiveBidIds.length == _initialActiveLenderArray.length,
            "Array lengths mismatch"
        );
        for (uint i = 0; i < _initialActiveBidIds.length; i++) {
            _loanActiveLender[
                _initialActiveBidIds[i]
            ] = _initialActiveLenderArray[i];
        }
    }
}
