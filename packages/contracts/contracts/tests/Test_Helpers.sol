pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import { TellerV2 } from "../TellerV2.sol";
import "../mock/WethMock.sol";
import "../interfaces/IMarketRegistry.sol";
import "../interfaces/ITellerV2.sol";
import { Collateral } from "../interfaces/escrow/ICollateralEscrowV1.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PaymentType } from "../libraries/V2Calculations.sol";

contract User {
    TellerV2 public immutable tellerV2;
    WethMock public immutable wethMock;

    constructor(TellerV2 _tellerV2, WethMock _wethMock) {
        tellerV2 = _tellerV2;
        wethMock = _wethMock;
    }

    function depositToWeth(uint256 amount) public {
        wethMock.deposit{ value: amount }();
    }

    function addAllowance(
        address _assetContractAddress,
        address _spender,
        uint256 _amount
    ) public {
        IERC20(_assetContractAddress).approve(_spender, _amount);
    }

    function createMarket(
        address marketRegistry,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        PaymentType _paymentType,
        string calldata _uri
    ) public returns (uint256) {
        return
            IMarketRegistry(marketRegistry).createMarket(
                address(this),
                _paymentCycleDuration,
                _paymentDefaultDuration,
                _bidExpirationTime,
                _feePercent,
                _requireLenderAttestation,
                _requireBorrowerAttestation,
                _paymentType,
                _uri
            );
    }

    function acceptBid(uint256 _bidId) public {
        ITellerV2(tellerV2).lenderAcceptBid(_bidId);
    }

    function submitBid(
        address _lendingToken,
        uint256 _marketplaceId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata _metadataURI,
        address _receiver
    ) public returns (uint256) {
        return
            ITellerV2(tellerV2).submitBid(
                _lendingToken,
                _marketplaceId,
                _principal,
                _duration,
                _APR,
                _metadataURI,
                _receiver
            );
    }

    function submitCollateralBid(
        address _lendingToken,
        uint256 _marketplaceId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata _metadataURI,
        address _receiver,
        Collateral[] calldata _collateralInfo
    ) public returns (uint256) {
        return
            ITellerV2(tellerV2).submitBid(
                _lendingToken,
                _marketplaceId,
                _principal,
                _duration,
                _APR,
                _metadataURI,
                _receiver,
                _collateralInfo
            );
    }

    function repayLoanFull(uint256 _bidId) public {
        return ITellerV2(tellerV2).repayLoanFull(_bidId);
    }

    receive() external payable {}
}
