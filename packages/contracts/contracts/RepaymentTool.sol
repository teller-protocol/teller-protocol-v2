// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Interfaces
import "./interfaces/ICollateralManager.sol";
import "./interfaces/ITellerV2.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/*

Provides functions to allow for loan repayment and collateral withdraw in the same transaction

*/

contract RepaymentTool is Initializable {
    
    ITellerV2 public tellerV2;
    ICollateralManager public collateralManager;
  

    /**
     * @notice Initializes the proxy.
     */
    function initialize(address _tellerV2, address _collateralManager) external initializer {
        tellerV2 = ITellerV2(_tellerV2);
        collateralManager = ICollateralManager(_collateralManager);
    }

    function repayLoan(uint256 _bidId, uint256 _amount, bool _claimCollateral)
        external
    {

        tellerV2.repayLoan(_bidId, _amount);
 
        if(_claimCollateral){
            collateralManager.withdraw(_bidId);
        }
    }

    function repayLoanFull(uint256 _bidId, bool _claimCollateral)
        external
    {

        tellerV2.repayLoanFull(_bidId);
 
        if(_claimCollateral){
            collateralManager.withdraw(_bidId);
        }
    }

    function repayLoanMinumum(uint256 _bidId, bool _claimCollateral)
       external
    {

        tellerV2.repayLoanMinimum(_bidId);
 
        if(_claimCollateral){
            collateralManager.withdraw(_bidId);
        }
    }

    function liquidateLoanFull(uint256 _bidId, bool _claimCollateral)
       external 
    {
        tellerV2.liquidateLoanFull(_bidId);

        address liquidator = msg.sender; //_msgSenderForMarket(bid.marketplaceId);

        if(_claimCollateral){
            collateralManager.liquidateCollateral(_bidId, liquidator);
        }
    }

 
}
