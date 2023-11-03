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
 

import "./LenderCommitmentGroup_Smart.sol";
//import {CreateCommitmentArgs} from "../../interfaces/ILenderCommitmentGroup.sol";


import {ILenderCommitmentGroup} from "../../../interfaces/ILenderCommitmentGroup.sol";

contract LenderCommitmentGroupFactory  {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable LENDER_COMMITMENT_FORWARDER;
 
 

    //fix 
   
   

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _lenderCommitmentForwarder
    ) {
        TELLER_V2 = ITellerV2(_tellerV2);
        LENDER_COMMITMENT_FORWARDER =    _lenderCommitmentForwarder;
      
        
    }
  
   
    /*

        This should deploy a new lender commitment group pool contract.

        It will use create commitment args in order to define the pool contracts parameters such as its primary principal token.  
        Shares will be distributed at a 1:1 ratio of the primary principal token so if 1e18 raw WETH are deposited, the depositor gets 1e18 shares for the group pool.
    */
    function deployLenderCommitmentGroupPool(   
       
        ILenderCommitmentForwarder.Commitment calldata _createCommitmentArgs,

        uint256 _initialPrincipalAmount,
        uint16 _liquidityThresholdPercent,
        uint16 _loanToValuePercent


    ) external returns (address newPoolAddress_) {       

            //these should be upgradeable proxies ??? 
        address _newGroupContract = address ( new LenderCommitmentGroup_Smart(
                address(TELLER_V2),
                address(LENDER_COMMITMENT_FORWARDER)
        ) );

      
        /*
            The max principal should be a very high number! higher than usual
            The expiration time should be far in the future!  farther than usual 
        */
        ILenderCommitmentGroup(_newGroupContract).initialize(   
                _createCommitmentArgs.principalTokenAddress,
                _createCommitmentArgs.collateralTokenAddress,
                _createCommitmentArgs.marketId,
                _createCommitmentArgs.maxDuration,
                _createCommitmentArgs.minInterestRate,
                
                _liquidityThresholdPercent,
                _loanToValuePercent
        );


        //it is not absolutely necessary to have this call here but it allows the user to potentially save a tx step so it is nice to have .
        if(_initialPrincipalAmount>0){


             //should pull in the creators initial committed principal tokens .

              //send the initial principal tokens to _newgroupcontract here !
              // so it will have them for addPrincipalToCommitmentGroup which will pull them from here 

            IERC20(_createCommitmentArgs.principalTokenAddress).transferFrom( msg.sender, address(this), _initialPrincipalAmount  ) ;
            IERC20(_createCommitmentArgs.principalTokenAddress).approve( address(_newGroupContract) , _initialPrincipalAmount ) ;


            address sharesRecipient = msg.sender; 

            ILenderCommitmentGroup(_newGroupContract).addPrincipalToCommitmentGroup(
                _initialPrincipalAmount,
                sharesRecipient
            );

        }

    }

  
}
