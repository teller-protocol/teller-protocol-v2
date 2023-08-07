



pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import { TellerV2 } from "../../contracts/TellerV2.sol";

/*import "../contracts/mock/WethMock.sol";
import "../contracts/interfaces/IMarketRegistry.sol";
import "../contracts/interfaces/ITellerV2.sol";
import "../contracts/interfaces/ITellerV2Context.sol";
import { Collateral } from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PaymentType } from "../contracts/libraries/V2Calculations.sol";
*/
library IntegrationTestHelpers {



function deployIntegrationSuite() public returns (address tellerV2_){

    address trustedForwarder = address(0);
    TellerV2 tellerV2 = new TellerV2(trustedForwarder);

        uint16 _protocolFee = 10;
        address _marketRegistry,
        address _reputationManager,
        address _lenderCommitmentForwarder,
        address _collateralManager,
        address _lenderManager,
        address _escrowVault

    tellerV2.initialize(

         _protocolFee,
         _marketRegistry,
         _reputationManager,
         _lenderCommitmentForwarder,
         _collateralManager,
         _lenderManager,
         _escrowVault
    );

}

}