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

import '../../../libraries/uniswap/core/interfaces/callback/IUniswapV3SwapCallback.sol';
 
 

 /*

    A one-tx strategy to borrow funds and then immediately swap them using uniswap 


    TODO:  
    1. add multihop support 
    2. add a helper fn to calculate:  how much out per how much in 




    To estimate minAmountOut, use  

        Uniswap IQuoter .quoteExactInput ( bytes path, amountIn ) 
                  function quoteExactInput(
                            bytes path,
                            uint256 amountIn
                          ) external returns (uint256 amountOut)


 */


contract BorrowSwap_G2    {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;


    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

   

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    ISwapRouter public immutable UNISWAP_SWAP_ROUTER; 
     

    event BorrowSwapComplete(
        address borrower,
        uint256 loanId,
        address token0 ,

        uint256 amountIn,
        uint256 amountOut  

    );


 
    // we take out a new loan with these args 
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

    struct SwapArgs {

        TokenSwapPath[] swapPaths ; //used to build the bytes path 
        
        uint160 amountOutMinimum;    
        uint160 deadline;     

    } 
 

    /**
     * @param _tellerV2 The address of the TellerV2 contract.
     * @param _factory The address of the UniswapV3 Factory contract to help with callback validation.
     * @param _WETH9 The address of the WETH Contract as this is instrumental to core uniswap logic.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2, 
      
        address _swapRouter 
    )  {
        TELLER_V2 = ITellerV2(_tellerV2);
        UNISWAP_SWAP_ROUTER = ISwapRouter( _swapRouter );
    }
 
 

    /**
    
     */
    function borrowSwap(
        address _lenderCommitmentForwarder,
       
        address _principalToken ,
        uint256 _additionalInputAmount, //an additional amount  
       
        SwapArgs  calldata _swapArgs, 
        AcceptCommitmentArgs calldata _acceptCommitmentArgs

    ) external   {
        
        address borrower = msg.sender ;
 
    
        if (_additionalInputAmount > 0) {
            TransferHelper.safeTransferFrom(_principalToken, borrower, address(this), _additionalInputAmount);              
        }
 
      
        // Accept commitment, lock up collateral, receive funds to this contract -- the principal 
        (uint256 newLoanId, uint256 acceptCommitmentAmount) = _acceptCommitment(
             _lenderCommitmentForwarder,
            borrower,
            _principalToken,  
            _acceptCommitmentArgs
        );
 

        uint256 totalInputAmount = acceptCommitmentAmount + _additionalInputAmount ;

 

        // Approve the router to spend DAI.
        TransferHelper.safeApprove( _principalToken , address(UNISWAP_SWAP_ROUTER),  totalInputAmount);

        // Multiple pool swaps are encoded through bytes called a `path`. A path is a sequence of token addresses and poolFees that define the pools used in the swaps.
        // The format for pool encoding is (tokenIn, fee, tokenOut/tokenIn, fee, tokenOut) where tokenIn/tokenOut parameter is the shared token across the pools.
        // Since we are swapping DAI to USDC and then USDC to WETH9 the path encoding is (DAI, 0.3%, USDC, 0.3%, WETH9).
        ISwapRouter.ExactInputParams memory swapParams =
            ISwapRouter.ExactInputParams({
                path:  generateSwapPath( _principalToken, _swapArgs.swapPaths  ) ,//path: abi.encodePacked(DAI, poolFee, USDC, poolFee, WETH9),
                recipient: address(  borrower  ) ,
                deadline: _swapArgs.deadline,
                amountIn:  totalInputAmount ,
                amountOutMinimum:  _swapArgs.amountOutMinimum    //can be 0 for testing -- get from IQuoter 
            });

        // Executes the swap.
        uint256 swapAmountOut = UNISWAP_SWAP_ROUTER.exactInput( swapParams );


        emit BorrowSwapComplete(
            borrower, 
            newLoanId,
            
            _principalToken ,
            totalInputAmount ,
            swapAmountOut   
        );

    
    }



 


 struct TokenSwapPath {
    uint24 poolFee ;
    address tokenOut ;
 }

function generateSwapPath(
    address inputToken, 
    TokenSwapPath[] calldata swapPaths
) public view returns (bytes memory)  {

    if (swapPaths.length == 1 ){
        return  abi.encodePacked(inputToken, swapPaths[0].poolFee, swapPaths[0].tokenOut )  ;
    }else if (swapPaths.length == 2 ){
        return  abi.encodePacked(inputToken, swapPaths[0].poolFee, swapPaths[0].tokenOut, swapPaths[1].poolFee, swapPaths[1].tokenOut )  ;
    }else {

        revert("invalid swap path length");
    }

}
 
 
 
/*
    function getUniswapPoolAddress(  
        address token0,
        address token1,
        uint24 fee
     ) public view virtual returns (address) {

        return IUniswapV3Factory(factory).getPool(token0,token1,fee);

    }
*/

    
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
