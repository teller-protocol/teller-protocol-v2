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

        address lendingToken = tellerV2.getLoanLendingToken(_bidId);

        IERC20(lendingToken).safeTransferFrom(
        _msgSenderForMarket(bid.marketplaceId),
            address(this),
            _amount
            );

        IERC20(lendingToken).approve(address(tellerV2),_amount);

        tellerV2.repayLoan(_bidId, _amount);
 
        if(_claimCollateral){
               //issue: we may want to allow only the lender to call this but then this breaks 
            collateralManager.withdraw(_bidId);
        }
    }

    function repayLoanFull(uint256 _bidId, bool _claimCollateral)
        external
    {

        address lendingToken = tellerV2.getLoanLendingToken(_bidId);


        (uint256 owedPrincipal, , uint256 interest) = V2Calculations
        .calculateAmountOwed(
            bids[_bidId],
            block.timestamp,
            bidPaymentCycleType[_bidId]
        );

        uint256 paymentAmount = (owedPrincipal + interest);

        IERC20(lendingToken).safeTransferFrom(
        _msgSenderForMarket(bid.marketplaceId),
            address(this),
            paymentAmount
            );

        IERC20(lendingToken).approve(address(tellerV2),paymentAmount);

        tellerV2.repayLoanFull(_bidId);
 
        if(_claimCollateral){

            //issue: we may want to allow only the lender to call this but then this breaks 
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
