// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../TellerV2.sol";
import "../interfaces/ITellerV2.sol";
import "../interfaces/IProtocolFee.sol";
import "../TellerV2Context.sol";
import { Collateral } from "../interfaces/escrow/ICollateralEscrowV1.sol";
import { LoanDetails, Payment, BidState } from "../TellerV2Storage.sol";

/*
This is only used for sol test so its named specifically to avoid being used for the typescript tests.
*/
contract TellerV2SolMock is ITellerV2, IProtocolFee, TellerV2Storage {
    
    address public collateralManagerMock;
    address public trustedForwarder;
    address public approvedForwarder;

    Bid mockBid;
    
    
    function setMarketRegistry(address _marketRegistry) public {
        marketRegistry = IMarketRegistry_V2(_marketRegistry);
    }

    function getMarketRegistry() external view returns (IMarketRegistry) {
        return marketRegistry;
    }

    function protocolFee() external view returns (uint16) {
        return 100;
    }

    function submitBid(
        address _lendingToken,
        uint256 _marketId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata,
        address _receiver
    ) public returns (uint256 bidId_) {
        bidId_ = bidId;

        Bid storage bid = bids[bidId];
        bid.borrower = msg.sender;
        bid.receiver = _receiver != address(0) ? _receiver : bid.borrower;
        bid.marketplaceId = _marketId;
        bid.loanDetails.lendingToken = IERC20(_lendingToken);
        bid.loanDetails.principal = _principal;
        bid.loanDetails.loanDuration = _duration;
        bid.loanDetails.timestamp = uint32(block.timestamp);

        /*(bid.terms.paymentCycle, bidPaymentCycleType[bidId]) = marketRegistry
            .getPaymentCycle(_marketId);*/

        bid.terms.APR = _APR;

        bidId++;
    }

    function submitBid(
        address _lendingToken,
        uint256 _marketplaceId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata _metadataURI,
        address _receiver,
        Collateral[] calldata _collateralInfo
    ) public returns (uint256 bidId_) {
        submitBid(
            _lendingToken,
            _marketplaceId,
            _principal,
            _duration,
            _APR,
            _metadataURI,
            _receiver
        );
    }

    function repayLoanMinimum(uint256 _bidId) external {}

    function repayLoanFull(uint256 _bidId) external {
        Bid storage bid = bids[_bidId];

        (uint256 owedPrincipal, , uint256 interest) = V2Calculations
            .calculateAmountOwed(
                bids[_bidId],
                block.timestamp,
                _getBidPaymentCycleType(_bidId),
                _getBidPaymentCycleDuration(_bidId)
            );

        uint256 _amount = owedPrincipal + interest;

        IERC20(bid.loanDetails.lendingToken).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    function repayLoan(uint256 _bidId, uint256 _amount) public {
        Bid storage bid = bids[_bidId];

        IERC20(bid.loanDetails.lendingToken).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    /*
     * @notice Calculates the minimum payment amount due for a loan.
     * @param _bidId The id of the loan bid to get the payment amount for.
     */
    function calculateAmountDue(uint256 _bidId, uint256 _timestamp)
        public
        view
        returns (Payment memory due)
    {
        if (bids[_bidId].state != BidState.ACCEPTED) return due;

        (, uint256 duePrincipal, uint256 interest) = V2Calculations
            .calculateAmountOwed(
                bids[_bidId],
                _timestamp,
                _getBidPaymentCycleType(_bidId),
                _getBidPaymentCycleDuration(_bidId)
            );
        due.principal = duePrincipal;
        due.interest = interest;
    }

    function calculateAmountOwed(uint256 _bidId, uint256 _timestamp)
        public
        view
        returns (Payment memory due)
    {
        if (bids[_bidId].state != BidState.ACCEPTED) return due;

        (uint256 owedPrincipal, , uint256 interest) = V2Calculations
            .calculateAmountOwed(
                bids[_bidId],
                _timestamp,
                _getBidPaymentCycleType(_bidId),
                _getBidPaymentCycleDuration(_bidId)
            );
        due.principal = owedPrincipal;
        due.interest = interest;
    }

    function lenderAcceptBid(uint256 _bidId)
        public
        returns (
            uint256 amountToProtocol,
            uint256 amountToMarketplace,
            uint256 amountToBorrower
        )
    {
        Bid storage bid = bids[_bidId];

        bid.lender = msg.sender;

        bid.state = BidState.ACCEPTED;

        //send tokens to caller
        IERC20(bid.loanDetails.lendingToken).transferFrom(
            bid.lender,
            bid.receiver,
            bid.loanDetails.principal
        );
        //for the reciever

        return (0, bid.loanDetails.principal, 0);
    }

    function getBidState(uint256 _bidId)
        public
        view
        virtual
        returns (BidState)
    {
        return bids[_bidId].state;
    }

    function setCollateralManagerSuper(address _collateralManager) public {
        collateralManagerMock = address(_collateralManager);
    }

    function getCollateralManagerForBid(uint256 _bidId)
        public
        view
        override
        returns (ICollateralManager)
    {
      
        return _getCollateralManagerForBid(_bidId);
    }

    function _getCollateralManagerForBid(uint256 _bidId)
        internal
        view
        returns (ICollateralManager)
    {
        
        return ICollateralManager(collateralManagerMock);
    }

    function setMockBid(uint256 _bidId, Bid calldata bid) public {
        bids[_bidId] = bid;
    }

    function setTrustedMarketForwarder(uint256 _marketId, address _forwarder)
        external
    {
        trustedForwarder = _forwarder;
    }

    function approveMarketForwarder(uint256 _marketId, address _forwarder)
        external
    {
        approvedForwarder = _forwarder;
    }

    function getLoanDetails(uint256 _bidId)
        public
        view
        returns (LoanDetails memory)
    {
        return bids[_bidId].loanDetails;
    }

    function getBorrowerActiveLoanIds(address _borrower)
        public
        view
        returns (uint256[] memory)
    {}

    function isLoanDefaulted(uint256 _bidId)
        public
        view
        virtual
        returns (bool)
    {}

    function isLoanLiquidateable(uint256 _bidId)
        public
        view
        virtual
        returns (bool)
    {}

    function isPaymentLate(uint256 _bidId) public view returns (bool) {}

    function getLoanBorrower(uint256 _bidId)
        external
        view
        virtual
        returns (address borrower_)
    {
        borrower_ = bids[_bidId].borrower;
    }

    function getLoanLender(uint256 _bidId)
        external
        view
        virtual
        returns (address lender_)
    {
        lender_ = bids[_bidId].lender;
    }

    function getLoanMarketId(uint256 _bidId)
        external
        view
        returns (uint256 _marketId)
    {
        _marketId = bids[_bidId].marketplaceId;
    }

    function getLoanLendingToken(uint256 _bidId)
        external
        view
        returns (address token_)
    {
        token_ = address(bids[_bidId].loanDetails.lendingToken);
    }

    function getLoanSummary(uint256 _bidId)
        external
        view
        returns (
            address borrower,
            address lender,
            uint256 marketId,
            address principalTokenAddress,
            uint256 principalAmount,
            uint32 acceptedTimestamp,
            uint32 lastRepaidTimestamp,
            BidState bidState
        )
    {
        Bid storage bid = bids[_bidId];

        borrower = bid.borrower;
        lender = bid.lender;
        marketId = bid.marketplaceId;
        principalTokenAddress = address(bid.loanDetails.lendingToken);
        principalAmount = bid.loanDetails.principal;
        acceptedTimestamp = bid.loanDetails.acceptedTimestamp;
        lastRepaidTimestamp = bid.loanDetails.lastRepaidTimestamp;
        bidState = bid.state;
    }

    function setLastRepaidTimestamp(uint256 _bidId, uint32 _timestamp) public {
        bids[_bidId].loanDetails.lastRepaidTimestamp = _timestamp;
    }

    function _getBidPaymentCycleType(uint256 _bidId) internal view returns(PaymentCycleType){
        
        bytes32 bidTermsId = bidMarketTermsId[bidId]; 
        if (bidTermsId != bytes32(0)){

            return marketRegistry.getPaymentCycleType(bidTermsId);
        }

        return bidPaymentCycleType[_bidId];
    }

    function _getBidPaymentCycleDuration(uint256 _bidId) internal view returns(uint32){
      
        bytes32 bidTermsId = bidMarketTermsId[bidId]; 
        if (bidTermsId != bytes32(0)){

            return marketRegistry.getPaymentCycleDuration(bidTermsId);
        }
        
        Bid storage bid = bids[_bidId];

        return bid.terms.paymentCycle ; 
    }
}
