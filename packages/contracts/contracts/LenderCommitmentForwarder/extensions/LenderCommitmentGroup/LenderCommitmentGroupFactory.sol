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
import "../../../interfaces/ILenderCommitmentForwarder.sol"; 
import "../../../libraries/NumbersLib.sol";
 

import "./LenderCommitmentGroup_Simple.sol";
//import {CreateCommitmentArgs} from "../../interfaces/ILenderCommitmentGroup.sol";

contract LenderCommitmentGroupFactory  {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILenderCommitmentForwarder public immutable LENDER_COMMITMENT_FORWARDER;
 
 

    //fix 
   
   

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
  
   
    /*

        This should deploy a new lender commitment group pool contract.

        It will use create commitment args in order to define the pool contracts parameters such as its primary principal token.  
        Shares will be distributed at a 1:1 ratio of the primary principal token so if 1e18 raw WETH are deposited, the depositor gets 1e18 shares for the group pool.
    */
    function deployLenderCommitmentGroupPool(   
       
        ILenderCommitmentForwarder.Commitment calldata _createCommitmentArgs,

        uint256 initialPrincipalAmount

    ) external returns (address newPoolAddress_) {       

            //these should be upgradeable proxies ??? 
        LenderCommitmentGroup_Simple _newGroupContract = new LenderCommitmentGroup_Simple(
                address(TELLER_V2),
                address(LENDER_COMMITMENT_FORWARDER)
        );

      
        /*
            The max principal should be a very high number! higher than usual
            The expiration time should be far in the future!  farther than usual 
        */
        _newGroupContract.initialize(            
                _createCommitmentArgs
        );


        //it is not absolutely necessary to have this call here but it allows the user to potentially save a tx step so it is nice to have .
        if(initialPrincipalAmount>0){


             //should pull in the creators initial committed principal tokens .

              //send the initial principal tokens to _newgroupcontract here !
              // so it will have them for addPrincipalToCommitmentGroup which will pull them from here 

            IERC20(_createCommitmentArgs.principalTokenAddress).transferFrom( msg.sender, address(this), initialPrincipalAmount  ) ;
            IERC20(_createCommitmentArgs.principalTokenAddress).approve( address(_newGroupContract) , initialPrincipalAmount ) ;


            address sharesRecipient = msg.sender; 

            _newGroupContract.addPrincipalToCommitmentGroup(
                initialPrincipalAmount,
                sharesRecipient
            );

        }

    }

  
}
