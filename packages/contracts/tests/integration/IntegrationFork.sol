pragma solidity <0.9.0;
pragma abicoder v2;
 
import "../util/FoundryTest.sol"; 
import { IMarketRegistry } from "../../contracts/interfaces/IMarketRegistry.sol";
import { ITellerV2 } from "../../contracts/interfaces/ITellerV2.sol";

import { ILenderCommitmentForwarder } from "../../contracts/interfaces/ILenderCommitmentForwarder.sol";


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract IntegrationForkSetup is Test {
    ITellerV2 internal tellerV2;
    IMarketRegistry internal marketRegistry;
    ILenderCommitmentForwarder internal commitmentForwarder;
    

    uint256 internal marketId;
    // principal => collateral => commitmentId
    mapping(address => mapping(address => uint256)) internal commitmentsIds;

    function setUp() public virtual override {
        // NOTE: must fork the network before calling super.setUp()
        uint256 mainnetFork = vm.createSelectFork("mainnet");

        super.setUp();

        _setupTellerProtocol();


    //deploy other contract here 
      
        _setupLender();
        _setupBorrower();
    }

    function _setupTellerProtocol() private {
        tellerV2 = ITellerV2(
            address(0x00182FdB0B880eE24D428e3Cc39383717677C37e)
        );
        vm.label(address(tellerV2), "tellerV2");

        marketRegistry = tellerV2.marketRegistry();
        vm.label(address(marketRegistry), "marketRegistry");

        commitmentForwarder = ILenderCommitmentForwarder(
            address(0x5098102507Da3F71677C5d9e170f91779Fe888F4)
        );
        vm.label(address(commitmentForwarder), "commitmentForwarder");

        marketId = marketRegistry.createMarket(
            address(this), // owner
            30 days, // payment cycle duration
            5 days, // payment default duration
            365 days, // bid expiration
            500, // fee percent
            false, // lender attestation
            false, // borrower attestation
            IMarketRegistry.PaymentType.EMI, // payment type
            IMarketRegistry.PaymentCycleType.Seconds, // payment cycle type
            "" // metadata
        );
        tellerV2.setTrustedMarketForwarder(
            marketId,
            address(commitmentForwarder)
        );
    }

    function _setupLender() private {
        vm.startPrank(lender);
        tellerV2.approveMarketForwarder(marketId, address(commitmentForwarder));

        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20(tokens[i]).approve(address(tellerV2), type(uint256).max);

            for (uint256 j = 0; j < tokens.length; j++) {
                address lendingToken = address(tokens[i]);
                address collateralToken = address(tokens[j]);
                _createCommitment(
                    lendingToken,
                    collateralToken,
                    ILenderCommitmentForwarder.CommitmentCollateralType.ERC20,
                    0
                );
            }
        }
        vm.stopPrank();
    }

    function _createCommitment(
        address lendingToken,
        address collateralToken,
        ILenderCommitmentForwarder.CommitmentCollateralType collateralTokenType,
        uint256 collateralTokenId
    ) internal {
        uint256 commitmentId = commitmentForwarder.createCommitment(
            ILenderCommitmentForwarder.Commitment({
                maxPrincipal: 100 ether,
                expiration: uint32(block.timestamp + 365 days),
                maxDuration: uint32(365 days),
                minInterestRate: 0,
                collateralTokenAddress: collateralToken,
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: 1_000_000 **
                    (ERC20(lendingToken).decimals() * 2),
                collateralTokenType: collateralTokenType,
                lender: lender,
                marketId: marketId,
                principalTokenAddress: lendingToken
            }),
            new address[](0)
        );
        commitmentsIds[lendingToken][collateralToken] = commitmentId;
    }

    function _setupBorrower() private {
        vm.startPrank(borrower);
        tellerV2.approveMarketForwarder(marketId, address(commitmentForwarder));
        

        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20(tokens[i]).approve(address(tellerV2), type(uint256).max);
            ERC20(tokens[i]).approve(
                address(tellerV2.collateralManager()),
                type(uint256).max
            );
        }
        vm.stopPrank();
    }
}