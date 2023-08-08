import { Collateral } from "./escrow/ICollateralEscrowV1.sol";

interface ITellerV2MarketForwarder {
    struct CreateLoanArgs {
        uint256 marketId;
        address lendingToken;
        uint256 principal;
        uint32 duration;
        uint16 interestRate;
        string metadataURI;
        address recipient;
        Collateral[] collateral;
    }
}
