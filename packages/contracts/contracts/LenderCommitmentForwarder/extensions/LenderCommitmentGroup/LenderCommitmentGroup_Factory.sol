// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; 

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import "../../../interfaces/ITellerV2.sol";
import "../../../interfaces/IProtocolFee.sol";
import "../../../interfaces/ITellerV2Storage.sol";
import "../../../libraries/NumbersLib.sol";


import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
 
import { ILenderCommitmentGroup } from "../../../interfaces/ILenderCommitmentGroup.sol";

contract LenderCommitmentGroupFactory is OwnableUpgradeable {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

 
    address public lenderGroupBeaconImplementation;


    mapping(address => uint256) public deployedLenderGroupContracts;

    event DeployedLenderGroupContract(address indexed groupContract);

 

     function initialize(address _lenderGroupBeacon )
        external
        initializer
    {
        lenderGroupBeaconImplementation = _lenderGroupBeacon; 
        __Ownable_init_unchained();
    }


    /*
        This should deploy a new lender commitment group pool contract.
        It will use create commitment args in order to define the pool contracts parameters such as its primary principal token.  
        Shares will be distributed at a 1:1 ratio of the primary principal token so if 1e18 raw WETH are deposited, the depositor gets 1e18 shares for the group pool.
    */
    function deployLenderCommitmentGroupPool(
        uint256 _initialPrincipalAmount,
        address _principalTokenAddress,
        address _collateralTokenAddress,
        uint256 _marketId,
        uint32 _maxLoanDuration,
        uint16 _interestRateLowerBound,
        uint16 _interestRateUpperBound,
        uint16 _liquidityThresholdPercent,
        uint16 _collateralRatio,
        uint24 _uniswapPoolFee,
        uint32 _twapInterval
    ) external returns (address newGroupContract_) {
         

      
        BeaconProxy newGroupContract_ = new BeaconProxy(
                lenderGroupBeaconImplementation,
                abi.encodeWithSelector(
                    ILenderCommitmentGroup.initialize.selector,    //this initializes 
                    _principalTokenAddress,
                    _collateralTokenAddress,
                    _marketId,
                    _maxLoanDuration,
                    _interestRateLowerBound,
                    _interestRateUpperBound,
                    _liquidityThresholdPercent,
                    _collateralRatio,
                    _uniswapPoolFee,
                    _twapInterval
                )
            );

        deployedLenderGroupContracts[address(newGroupContract_)] = block.number; //consider changing this ?
        emit DeployedLenderGroupContract(address(newGroupContract_));



        //transfer ownership to msg.sender 
        OwnableUpgradeable(address(newGroupContract_))
            .transferOwnership(msg.sender);
 

        //it is not absolutely necessary to have this call here but it allows the user to potentially save a tx step so it is nice to have .
         if (_initialPrincipalAmount > 0) {
            //should pull in the creators initial committed principal tokens .

            //send the initial principal tokens to _newgroupcontract here !
            // so it will have them for addPrincipalToCommitmentGroup which will pull them from here

            _initializeCommitmentGroup(
                address(newGroupContract_),
                _initialPrincipalAmount,
                _principalTokenAddress 
                
            );

            
        } 
    }



    function _initializeCommitmentGroup(
        address _newGroupContract,
        uint256 _initialPrincipalAmount,
        address _principalTokenAddress
    ) internal {


        IERC20(_principalTokenAddress).transferFrom(
                msg.sender,
                address(this),
                _initialPrincipalAmount
            );
            IERC20(_principalTokenAddress).approve(
                _newGroupContract,
                _initialPrincipalAmount
            );

            address sharesRecipient = msg.sender; 

            uint256 sharesAmount_ = ILenderCommitmentGroup(address(_newGroupContract))
                .addPrincipalToCommitmentGroup(
                    _initialPrincipalAmount,
                    sharesRecipient,
                    0 //_minShares
                );


    }

}
