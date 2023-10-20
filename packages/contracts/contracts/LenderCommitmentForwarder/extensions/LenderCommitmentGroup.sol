// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import "../../interfaces/ITellerV2.sol";
import "../../interfaces/IProtocolFee.sol";
import "../../interfaces/ITellerV2Storage.sol";
import "../../interfaces/IMarketRegistry.sol";
import "../../interfaces/ILenderCommitmentForwarder.sol";
import "../../interfaces/IFlashRolloverLoan.sol";
import "../../libraries/NumbersLib.sol";
 
import { ILenderCommitmentGroup} from "../../interfaces/ILenderCommitmentGroup.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/*




*/


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
    address public principalToken;


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

        principalToken = _createCommitmentArgs.principalTokenAddress;

        _createInitialCommitment(_createCommitmentArgs);


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
        IERC20(principalToken).transferFrom(msg.sender, address(this), _amount );


        //mint shares equal to _amount and give them to the shares recipient !!! 


    }

   /*
    must be initialized for this to work ! 
    */
    function burnSharesToWithdrawEarnings(
        uint256 _amount,
        address _recipient
    ) external 
    onlyInitialized
    {



    }


}
