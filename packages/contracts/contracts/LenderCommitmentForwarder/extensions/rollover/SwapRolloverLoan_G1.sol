// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import "../../../interfaces/ITellerV2.sol";
import "../../../interfaces/IProtocolFee.sol";
import "../../../interfaces/ITellerV2Storage.sol";
import "../../../interfaces/IMarketRegistry.sol";
import "../../../interfaces/ILenderCommitmentForwarder.sol";
import "../../../interfaces/ISmartCommitmentForwarder.sol";
import "../../../interfaces/ISwapRolloverLoan.sol";
import "../../../libraries/NumbersLib.sol";

 
import '../../../libraries/uniswap/periphery/base/PeripheryPayments.sol';
import '../../../libraries/uniswap/periphery/base/PeripheryImmutableState.sol';
import '../../../libraries/uniswap/periphery/libraries/PoolAddress.sol';
import '../../../libraries/uniswap/periphery/libraries/CallbackValidation.sol';
import '../../../libraries/uniswap/periphery/libraries/TransferHelper.sol';
import '../../../libraries/uniswap/periphery/interfaces/ISwapRouter.sol';

import '../../../libraries/uniswap/core/interfaces/IUniswapV3Factory.sol';

import '../../../libraries/uniswap/core/libraries/LowGasSafeMath.sol';

import '../../../libraries/uniswap/core/interfaces/callback/IUniswapV3FlashCallback.sol';
 
 


contract SwapRolloverLoan_G1 is IUniswapV3FlashCallback, PeripheryPayments  {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;


    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

   

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
  
     

    event RolloverLoanComplete(
        address borrower,
        uint256 originalLoanId,
        uint256 newLoanId,
        uint256 fundsRemaining
    );

     event RolloverWithReferral(
        
        uint256 newLoanId,
        address flashToken,

        address rewardRecipient,
        uint256 rewardAmount,
        uint256 atmId
    );

 

    struct AcceptCommitmentArgs {
        uint256 commitmentId;
        address smartCommitmentAddress;  //if this is not address(0), we will use this ! leave empty if not used. 
        uint256 principalAmount;
        uint256 collateralAmount;
        uint256 collateralTokenId;
        address collateralTokenAddress;
        uint16 interestRate;
        uint32 loanDuration;
        bytes32[] merkleProof; //empty array if not used
    }

    struct FlashSwapArgs {

        address token0;
        address token1;
        uint24 fee;
 

        uint256 flashAmount;
        bool borrowToken1; // if false, borrow token 0 
       
        

    } 

       struct RolloverCallbackArgs {
        address lenderCommitmentForwarder;
        uint256 loanId;
        address borrower;
        uint256 borrowerAmount;
        uint256 atmId; 
        address rewardRecipient;
        uint256 rewardAmount;
        bytes acceptCommitmentArgs;
        bytes flashSwapArgs;
    }


    /**
     *
     * @notice Initializes the FlashRolloverLoan with necessary contract addresses.
     *
     * @dev Using a custom OpenZeppelin upgrades tag. Ensure the constructor logic is safe for upgrades.
     *
     * @param _tellerV2 The address of the TellerV2 contract.
     * @param _factory The address of the UniswapV3 Factory contract to help with callback validation.
     * @param _WETH9 The address of the WETH Contract as this is instrumental to core uniswap logic.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2, 
        address _factory,
        address _WETH9
    ) PeripheryImmutableState(_factory, _WETH9)  {
        TELLER_V2 = ITellerV2(_tellerV2);
     
    }
 



    /**
     *
     * @notice Allows the borrower to rollover their existing loan using a flash loan mechanism.
     *         The borrower might also provide an additional amount during the rollover.
     *
     * @dev The function first verifies that the caller is the borrower of the loan.
     *      It then optionally transfers the additional amount specified by the borrower.
     *      A flash loan is then taken from the pool to facilitate the rollover and
     *      a callback is executed for further operations.
     *
     * @param _loanId Identifier of the existing loan to be rolled over.
     
     * @param _borrowerAmount Additional amount that the borrower may want to add during rollover.
     * @param _acceptCommitmentArgs Commitment arguments that might be necessary for internal operations.
     * 
     */
    function rolloverLoanWithFlashSwap(
        address _lenderCommitmentForwarder,
        uint256 _loanId, 

        uint256 _borrowerAmount, //an additional amount borrower may have to add 

        FlashSwapArgs calldata _flashSwapArgs, 

        AcceptCommitmentArgs calldata _acceptCommitmentArgs

    ) external   {
        address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "Must be borrower");


        {
            // Get lending token and balance before
            address lendingToken = TELLER_V2.getLoanLendingToken(_loanId);

          
            if (_borrowerAmount > 0) {
                TransferHelper.safeTransferFrom(lendingToken, borrower, address(this), _borrowerAmount);              
            }
        }

        
        IUniswapV3Pool( 
            getUniswapPoolAddress (
                _flashSwapArgs.token0,
                _flashSwapArgs.token1,
                _flashSwapArgs.fee
            )
        ).flash(  
            address(this),
           _flashSwapArgs.borrowToken1 ? 0 : _flashSwapArgs.flashAmount,            
           _flashSwapArgs.borrowToken1 ?  _flashSwapArgs.flashAmount : 0, 
            abi.encode( 
                RolloverCallbackArgs({
                    lenderCommitmentForwarder : _lenderCommitmentForwarder,
                    loanId: _loanId,
                    borrower: borrower,
                    borrowerAmount: _borrowerAmount, 
                    rewardRecipient: address(0),
                    rewardAmount: 0,
                    atmId: 0, 
                    acceptCommitmentArgs: abi.encode(_acceptCommitmentArgs),

                    flashSwapArgs: abi.encode( _flashSwapArgs) 
                    
                })

            )
        );


        
    }



    function rolloverLoanWithFlashSwapRewards(
        address _lenderCommitmentForwarder,
        uint256 _loanId, 

        uint256 _borrowerAmount, //an additional amount borrower may have to add
        uint256 _rewardAmount,
        address _rewardRecipient,
        uint256 _atmId, //optional, just for analytics 

        FlashSwapArgs calldata _flashSwapArgs, 

        AcceptCommitmentArgs calldata _acceptCommitmentArgs

    ) external   {
        address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "Must be borrower");


        {
            // Get lending token and balance before
            address lendingToken = TELLER_V2.getLoanLendingToken(_loanId);

             require( 
                  _rewardAmount <= _flashSwapArgs.flashAmount / 10 ,
                   "Excessive reward amount" );

            if (_borrowerAmount > 0) {
                TransferHelper.safeTransferFrom(lendingToken, borrower, address(this), _borrowerAmount);              
            }
        } 
       

        IUniswapV3Pool( 
            getUniswapPoolAddress (
                _flashSwapArgs.token0,
                _flashSwapArgs.token1,
                _flashSwapArgs.fee
            )
        ).flash(
            address(this),
           _flashSwapArgs.borrowToken1 ? 0 : _flashSwapArgs.flashAmount,            
           _flashSwapArgs.borrowToken1 ?  _flashSwapArgs.flashAmount : 0, 
            abi.encode( 
                RolloverCallbackArgs({
                    lenderCommitmentForwarder : _lenderCommitmentForwarder,
                    loanId: _loanId,
                    borrower: borrower,
                    borrowerAmount: _borrowerAmount, // need this ? 
                    rewardRecipient: _rewardRecipient,
                    rewardAmount: _rewardAmount,
                    atmId: _atmId, 
                    acceptCommitmentArgs: abi.encode(_acceptCommitmentArgs), 
                    flashSwapArgs: abi.encode( _flashSwapArgs) 
                    
                })

            )
        );


        
    }




    /*
        @dev  _verifyFlashCallback ensures that only the uniswap pool can call this method 
    */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        RolloverCallbackArgs memory _rolloverArgs = abi.decode(data, (RolloverCallbackArgs));
      



        AcceptCommitmentArgs memory acceptCommitmentArgs = abi.decode(
            _rolloverArgs.acceptCommitmentArgs,
            (AcceptCommitmentArgs)
        );

        FlashSwapArgs memory flashSwapArgs = abi.decode(

            _rolloverArgs.flashSwapArgs,
            (FlashSwapArgs)

        );

    
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: flashSwapArgs.token0, token1: flashSwapArgs.token1, fee: flashSwapArgs.fee}); 

        _verifyFlashCallback( factory , poolKey  );
       
         

        address flashToken = flashSwapArgs.borrowToken1 ? flashSwapArgs.token1: flashSwapArgs.token0  ; 
        uint256 flashFee =  flashSwapArgs.borrowToken1 ? fee1: fee0 ;



        uint256 repaymentAmount = _repayLoanFull(
            _rolloverArgs.loanId, 
            flashToken,
            flashSwapArgs.flashAmount
        );

    

        // Accept commitment and receive funds to this contract 
        (uint256 newLoanId, uint256 acceptCommitmentAmount) = _acceptCommitment(
            _rolloverArgs.lenderCommitmentForwarder,
            _rolloverArgs.borrower,
            flashToken,
            acceptCommitmentArgs
        );

       
        uint256 amountOwedToPool = LowGasSafeMath.add(flashSwapArgs.flashAmount, flashFee) ; 
 
        // what is the point of this ?? 
        // TransferHelper.safeApprove(flashToken, address(this), amountOwedToPool);
      
        //  msg.sender is the uniswap pool  
        if (amountOwedToPool > 0) pay(flashToken, address(this), msg.sender, amountOwedToPool);
     
 
        // send any dust to the borrower
         uint256 fundsRemaining = flashSwapArgs.flashAmount + 
              acceptCommitmentAmount +
            _rolloverArgs.borrowerAmount -
            repaymentAmount -
            amountOwedToPool;
 
    
          if (fundsRemaining > 0) {

            if (_rolloverArgs.rewardAmount > 0){ 

                fundsRemaining -= _rolloverArgs.rewardAmount;
                TransferHelper.safeTransfer(flashToken,   _rolloverArgs.rewardRecipient,   _rolloverArgs.rewardAmount) ;

                emit RolloverWithReferral( newLoanId, flashToken, _rolloverArgs.rewardRecipient,   _rolloverArgs.rewardAmount, _rolloverArgs.atmId     ) ;  
                  
            }

           TransferHelper.safeTransfer(flashToken,  _rolloverArgs.borrower,   fundsRemaining) ;
                 
            
        }



        emit RolloverLoanComplete(
            _rolloverArgs.borrower,
            _rolloverArgs.loanId,
            newLoanId,
            fundsRemaining
        );

    


    }


    
    function _verifyFlashCallback( 
        address _factory,
        PoolAddress.PoolKey memory _poolKey 
     ) internal virtual {

        CallbackValidation.verifyCallback(_factory,  _poolKey); //verifies that only uniswap contract can call this fn 

    }


    function getUniswapPoolAddress(  
        address token0,
        address token1,
        uint24 fee
     ) public view virtual returns (address) {

        return IUniswapV3Factory(factory).getPool(token0,token1,fee);

    }


    /**
     *
     *
     * @notice Internal function that repays a loan in full on behalf of this contract.
     *
     * @dev The function first calculates the funds held by the contract before repayment, then approves
     *      the repayment amount to the TellerV2 contract and finally repays the loan in full.
     *
     * @param _bidId Identifier of the loan to be repaid.
     * @param _principalToken The token in which the loan was originated.
     * @param _repayAmount The amount to be repaid.
     *
     * @return repayAmount_ The actual amount that was used for repayment.
     */
    function _repayLoanFull(
        uint256 _bidId,
        address _principalToken,
        uint256 _repayAmount
    ) internal returns (uint256 repayAmount_) {
        uint256 fundsBeforeRepayment = IERC20Upgradeable(_principalToken)
            .balanceOf(address(this));

        IERC20Upgradeable(_principalToken).approve(
            address(TELLER_V2),
            _repayAmount
        );
        TELLER_V2.repayLoanFull(_bidId);

        uint256 fundsAfterRepayment = IERC20Upgradeable(_principalToken)
            .balanceOf(address(this));

        repayAmount_ = fundsBeforeRepayment - fundsAfterRepayment;
    }

    /**
     *
     *
     * @notice Accepts a loan commitment using either a Merkle proof or standard method.
     *
     * @dev The function first checks if a Merkle proof is provided, based on which it calls the relevant
     *      `acceptCommitment` function in the LenderCommitmentForwarder contract.
     *
     * @param borrower The address of the borrower for whom the commitment is being accepted.
     * @param principalToken The token in which the loan is being accepted.
     * @param _commitmentArgs The arguments necessary for accepting the commitment.
     *
     * @return bidId_ Identifier of the accepted loan.
     * @return acceptCommitmentAmount_ The amount received from accepting the commitment.
     */
    function _acceptCommitment(
        address lenderCommitmentForwarder,
        address borrower,
        address principalToken,
        AcceptCommitmentArgs memory _commitmentArgs
    )
        internal
        virtual
        returns (uint256 bidId_, uint256 acceptCommitmentAmount_)
    {
        uint256 fundsBeforeAcceptCommitment = IERC20Upgradeable(principalToken)
            .balanceOf(address(this));



        if (_commitmentArgs.smartCommitmentAddress != address(0)) {

             bytes memory responseData = address(lenderCommitmentForwarder)
                    .functionCall(
                        abi.encodePacked(
                            abi.encodeWithSelector(
                                ISmartCommitmentForwarder
                                    .acceptSmartCommitmentWithRecipient
                                    .selector,
                                _commitmentArgs.smartCommitmentAddress,
                                _commitmentArgs.principalAmount,
                                _commitmentArgs.collateralAmount,
                                _commitmentArgs.collateralTokenId,
                                _commitmentArgs.collateralTokenAddress,
                                address(this),
                                _commitmentArgs.interestRate,
                                _commitmentArgs.loanDuration
                            ),
                            borrower //cant be msg.sender because of the flash flow
                        )
                    );

                (bidId_) = abi.decode(responseData, (uint256));


        }else { 

            bool usingMerkleProof = _commitmentArgs.merkleProof.length > 0;

            if (usingMerkleProof) {
                bytes memory responseData = address(lenderCommitmentForwarder)
                    .functionCall(
                        abi.encodePacked(
                            abi.encodeWithSelector(
                                ILenderCommitmentForwarder
                                    .acceptCommitmentWithRecipientAndProof
                                    .selector,
                                _commitmentArgs.commitmentId,
                                _commitmentArgs.principalAmount,
                                _commitmentArgs.collateralAmount,
                                _commitmentArgs.collateralTokenId,
                                _commitmentArgs.collateralTokenAddress,
                                address(this),
                                _commitmentArgs.interestRate,
                                _commitmentArgs.loanDuration,
                                _commitmentArgs.merkleProof
                            ),
                            borrower //cant be msg.sender because of the flash flow
                        )
                    );

                (bidId_) = abi.decode(responseData, (uint256));
            } else {
                bytes memory responseData = address(lenderCommitmentForwarder)
                    .functionCall(
                        abi.encodePacked(
                            abi.encodeWithSelector(
                                ILenderCommitmentForwarder
                                    .acceptCommitmentWithRecipient
                                    .selector,
                                _commitmentArgs.commitmentId,
                                _commitmentArgs.principalAmount,
                                _commitmentArgs.collateralAmount,
                                _commitmentArgs.collateralTokenId,
                                _commitmentArgs.collateralTokenAddress,
                                address(this),
                                _commitmentArgs.interestRate,
                                _commitmentArgs.loanDuration
                            ),
                            borrower //cant be msg.sender because of the flash flow
                        )
                    );

                (bidId_) = abi.decode(responseData, (uint256));
            }

        }

        uint256 fundsAfterAcceptCommitment = IERC20Upgradeable(principalToken)
            .balanceOf(address(this));
        acceptCommitmentAmount_ =
            fundsAfterAcceptCommitment -
            fundsBeforeAcceptCommitment;
    }

   

    /**
     * @notice Calculates the amount for loan rollover, determining if the borrower owes or receives funds.
    
     */
    function calculateRolloverAmount(
        uint16 marketFeePct,
        uint16 protocolFeePct, 
        uint256 _loanId,      
        uint256 principalAmount,
        uint256 _rewardAmount, 
        uint16 _flashloanFeePct,  // 3000 means 0.3%  in uniswap terms
        uint256 _timestamp
    ) external view returns (uint256 _flashAmount, int256 _borrowerAmount) {
        

        Payment memory repayAmountOwed = TELLER_V2.calculateAmountOwed(
            _loanId,
            _timestamp
        );

        uint256 commitmentPrincipalRequested = principalAmount; // _commitmentArgs.principalAmount;
        uint256 amountToMarketplace = commitmentPrincipalRequested.percent(
            marketFeePct
        );
        uint256 amountToProtocol = commitmentPrincipalRequested.percent(
            protocolFeePct
        );

        uint256 commitmentPrincipalReceived = commitmentPrincipalRequested -
            amountToMarketplace -
            amountToProtocol;

        // by default, we will flash exactly what we need to do relayLoanFull
        uint256 repayFullAmount = repayAmountOwed.principal +
            repayAmountOwed.interest;

        _flashAmount = repayFullAmount;
        uint256 _flashLoanFee = _flashAmount.percent(_flashloanFeePct, 4 );

        _borrowerAmount =
            int256(commitmentPrincipalReceived) -
            int256(repayFullAmount) -
            int256(_flashLoanFee) -
            int256(_rewardAmount);

            
    }


     function getMarketIdForCommitment(
       address _lenderCommitmentForwarder, 
       uint256 _commitmentId
    ) external view returns (uint256) {
        return _getMarketIdForCommitment(_lenderCommitmentForwarder, _commitmentId);  
    }

    function getMarketFeePct(
       uint256 _marketId
    ) external view returns (uint16) {
        return _getMarketFeePct(_marketId);  
    }
   

    /**
     * @notice Retrieves the market ID associated with a given commitment.
     * @param _commitmentId The ID of the commitment for which to fetch the market ID.
     * @return The ID of the market associated with the provided commitment.
     */
    function _getMarketIdForCommitment(address _lenderCommitmentForwarder, uint256 _commitmentId)
        internal
        view
        returns (uint256)
    {
        return ILenderCommitmentForwarder(_lenderCommitmentForwarder).getCommitmentMarketId(_commitmentId);
    }

    /**
     * @notice Fetches the marketplace fee percentage for a given market ID.
     * @param _marketId The ID of the market for which to fetch the fee percentage.
     * @return The marketplace fee percentage for the provided market ID.
     */
    function _getMarketFeePct(uint256 _marketId)
        internal
        view
        returns (uint16)
    {
        address _marketRegistryAddress = ITellerV2Storage(address(TELLER_V2))
            .marketRegistry();

        return
            IMarketRegistry(_marketRegistryAddress).getMarketplaceFee(
                _marketId
            );
    }

  
}
