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
//import "../../../interfaces/ILenderCommitmentForwarder.sol";
import "../../../libraries/NumbersLib.sol";

import {LenderCommitmentGroup_Smart} from  "./LenderCommitmentGroup_Smart.sol";
//import {CreateCommitmentArgs} from "../../interfaces/ILenderCommitmentGroup.sol";

import { ILenderCommitmentGroup } from "../../../interfaces/ILenderCommitmentGroup.sol";

contract LenderCommitmentGroupFactory {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable SMART_COMMITMENT_FORWARDER;
    address public immutable UNISWAP_V3_FACTORY;

    mapping(address => uint256) public deployedLenderGroupContracts;

    event DeployedLenderGroupContract(address indexed groupContract);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _smartCommitmentForwarder,
        address _uniswapV3Factory
    ) {
        TELLER_V2 = ITellerV2(_tellerV2);
        SMART_COMMITMENT_FORWARDER = _smartCommitmentForwarder;
        UNISWAP_V3_FACTORY = _uniswapV3Factory;
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
        uint16 _loanToValuePercent,
        uint24 _uniswapPoolFee,
        uint32 _twapInterval
    ) external returns (address newGroupContract_) {
        //these should be upgradeable proxies ???
        newGroupContract_ = address(
            new LenderCommitmentGroup_Smart(
                address(TELLER_V2),
                address(SMART_COMMITMENT_FORWARDER),
                address(UNISWAP_V3_FACTORY)
            )
        );

        deployedLenderGroupContracts[newGroupContract_] = block.number; //consider changing this ?
        emit DeployedLenderGroupContract(newGroupContract_);

        /*
            The max principal should be a very high number! higher than usual
            The expiration time should be far in the future!  farther than usual 
        */
        ILenderCommitmentGroup(newGroupContract_).initialize(
            _principalTokenAddress,
            _collateralTokenAddress,
            _marketId,
            _maxLoanDuration,
            _interestRateLowerBound,
            _interestRateUpperBound,
            _liquidityThresholdPercent,
            _loanToValuePercent,
            _uniswapPoolFee,
            _twapInterval
        );

        //it is not absolutely necessary to have this call here but it allows the user to potentially save a tx step so it is nice to have .
        if (_initialPrincipalAmount > 0) {
            //should pull in the creators initial committed principal tokens .

            //send the initial principal tokens to _newgroupcontract here !
            // so it will have them for addPrincipalToCommitmentGroup which will pull them from here

            IERC20(_principalTokenAddress).transferFrom(
                msg.sender,
                address(this),
                _initialPrincipalAmount
            );
            IERC20(_principalTokenAddress).approve(
                address(newGroupContract_),
                _initialPrincipalAmount
            );

            address sharesRecipient = msg.sender;

           

            uint256 sharesAmount_ = ILenderCommitmentGroup(newGroupContract_)
                .addPrincipalToCommitmentGroup(
                    _initialPrincipalAmount,
                    sharesRecipient,
                    0 //_minShares
                );
        }
    }
}
