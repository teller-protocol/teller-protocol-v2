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
import "../../../interfaces/IFlashRolloverLoan.sol";
import "../../../libraries/NumbersLib.sol";
 
import "./LenderCommitmentGroupShares.sol";

import { ILenderCommitmentGroup} from "../../../interfaces/ILenderCommitmentGroup.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
 

contract LenderCommitmentGroup is 
ILenderCommitmentGroup ,
Initializable
{
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILenderCommitmentForwarder public immutable LENDER_COMMITMENT_FORWARDER;
    
    bool private _initialized;
    IERC20 public principalToken;
    LenderCommitmentGroupShares public sharesToken;

    //this is all of the principal tokens that have been committed to this contract minus all that have been withdrawn.  This includes the tokens in this contract and lended out in active loans by this contract. 
    uint256 totalPrincipalTokensOutstandingForGroup;


    /*
 IDEA: In a mapping , i can keep track of how much principal tokens outstanding were given to this contract by each lender 
 Then, a function would allow a lender to 'decrease' the amount of tokens that are earmarked as being able to be lended out by their amount.
 That way, it allows a lender to disable their committed funds from being used for FUTURE loans, thereby allowing them to prep for a withdraw of those funds. 

 Er maybe this is done based on their shares !! ooo . keep track of amount of shares allowing fund use and amount of shares not allowing it . 
 or even smarter, this could be done based on your ratio of shares.
 
so if you own 20% of the shares, you can disable 20% of the funds from being used for future loans
 
you enforce that the contract cant give out more loans unless that new loan would NOT cause the contract to have less than 20% liquid
  */


    modifier onlyInitialized{

        require(_initialized,"Contract must be initialized");
        _;

    } 
  
            //maybe make this an initializer instead !? 
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _lenderCommitmentForwarder     
    ) {
        TELLER_V2 = ITellerV2(_tellerV2);
        LENDER_COMMITMENT_FORWARDER = ILenderCommitmentForwarder(
            _lenderCommitmentForwarder
        );

        
    }
    
    // must send initial principal tokens into this contract just before this is called
    function initialize( 
         ILenderCommitmentForwarder.Commitment calldata _createCommitmentArgs

    ) // initializer  ADD ME 
    external {

        _initialized = true;

        principalToken = IERC20(_createCommitmentArgs.principalTokenAddress);

        _createInitialCommitment(_createCommitmentArgs);

        _deploySharesToken();


    }
 

    function _createInitialCommitment(
        ILenderCommitmentForwarder.Commitment calldata _createCommitmentArgs
    ) internal returns (uint256 newCommitmentId) {


        address[] memory initialBorrowersList = new address[](0);

            //need to make the args calldata !?
        LENDER_COMMITMENT_FORWARDER.createCommitment(
            _createCommitmentArgs,
            initialBorrowersList
        );
 
    }

    function _deploySharesToken() internal {


       // uint256 principalTokenDecimals = principalToken.decimals();

        sharesToken =  new LenderCommitmentGroupShares(
            "Shares",
            "SHR",
            18   //may want this to equal the decimals of principal token !? 
        );

    }
    /*
    must be initialized for this to work ! 
    */
    function addPrincipalToCommitmentGroup(
        uint256 _amount,
        address _sharesRecipient
    ) external 
        onlyInitialized
    {

        //transfers the primary principal token from msg.sender into this contract escrow 
        //gives 
        principalToken.transferFrom(msg.sender, address(this), _amount );

        //approve more tokens to the LCF ! 
        principalToken.approve( address(LENDER_COMMITMENT_FORWARDER), totalPrincipalTokensOutstandingForGroup + _amount );


        //mint shares equal to _amount and give them to the shares recipient !!! 
        sharesToken.mint( _sharesRecipient,_amount);

        totalPrincipalTokensOutstandingForGroup += _amount;

    }

   /*
    must be initialized for this to work ! 
    */
    function burnSharesToWithdrawEarnings(
        uint256 _amountSharesTokens,
        address _recipient
    ) external 
    onlyInitialized
    {   

        //figure out the ratio of shares tokens that this is 
        uint256 sharesTotalSupplyBeforeBurn = sharesToken.totalSupply();

        //this DOES reduce total supply! This is necessary for correct math. 
        sharesToken.burn( msg.sender, _amountSharesTokens );


        /*  
        The fraction of shares that was just burned has 
        a numerator of _amount and 
        a denominator of sharesTotalSupplyBeforeBurn !
        */

        /*
            In this flow, lenders who withdraw first are able to claim the liquid tokens first 
            while the illiquid assets remain withdrawable by the remaining lenders at a later time. 

        */
        uint256 principalTokenAmountToWithdraw = totalPrincipalTokensOutstandingForGroup * _amountSharesTokens / sharesTotalSupplyBeforeBurn;

        totalPrincipalTokensOutstandingForGroup -= principalTokenAmountToWithdraw;

        sharesToken.transfer( _recipient, principalTokenAmountToWithdraw );

        
  
    }


}
