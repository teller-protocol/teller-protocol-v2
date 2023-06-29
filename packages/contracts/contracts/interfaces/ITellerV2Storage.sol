import { Bid } from "../TellerV2Storage.sol";

interface ITellerV2Storage {

 function bids(uint256 _bidId)
        external 
        view 
        returns (Bid memory);

 function collateralManager() external view returns (address);

 
}