import {Address, ethereum, BigInt, ByteArray, Bytes} from "@graphprotocol/graph-ts"
import { newMockEvent } from "matchstick-as/assembly/index"

// Import event type
import {
    AcceptedBid,
    CancelledBid, LoanRepaid,
    LoanRepayment,
    SubmittedBid,
    SubmittedBid__Params
} from "../generated/TellerV2/TellerV2"

/**
 * Function to mock an emitted event for a Submitted Bid to the protocol.
 * @param bidId The id of the submitted bid.
 * @param borrower Wallet address of the bid submitter.
 * @param receiver Wallet address of the receiver of the loan.
 * @param metaDataURI URI for the associated data submitted for the bid.
 */
export function createSubmittedBidEvent (
    bidId: i32,
    borrower: string,
    metaDataURI: Bytes,
): SubmittedBid  {
    let mockEvent = changetype<SubmittedBid>(newMockEvent())
    let submittedBidEvent = new SubmittedBid(
        mockEvent.address,
        mockEvent.logIndex,
        mockEvent.transactionLogIndex,
        mockEvent.logType,
        mockEvent.block,
        mockEvent.transaction,
        mockEvent.parameters
    )
    // Mock event data
    let bidIdParam = new ethereum.EventParam('bidId', ethereum.Value.fromI32(bidId))
    let borrowerParam = new ethereum.EventParam('borrower', ethereum.Value.fromAddress(Address.fromString(borrower)))
    let metadataURIParam = new ethereum.EventParam('metaDataURI', ethereum.Value.fromBytes(metaDataURI))

    submittedBidEvent.parameters.push(bidIdParam)
    submittedBidEvent.parameters.push(borrowerParam)
    submittedBidEvent.parameters.push(metadataURIParam)
    // Return mocked event
    return submittedBidEvent
}

/**
 * Function to mock an emitted event for an Accepted Bid to the protocol.
 * @param bidId The id of the submitted bid.
 * @param lender Wallet address of the bid lender.
 */
export function createAcceptedBidEvent (
    bidId: i32,
    lender: string,
): AcceptedBid  {
    let mockEvent = changetype<AcceptedBid>(newMockEvent())
    let accepteddBidEvent = new AcceptedBid(
        mockEvent.address,
        mockEvent.logIndex,
        mockEvent.transactionLogIndex,
        mockEvent.logType,
        mockEvent.block,
        mockEvent.transaction,
        mockEvent.parameters
    )
    // Mock event data
    let bidIdParam = new ethereum.EventParam('bidId', ethereum.Value.fromI32(bidId))
    let lenderParam = new ethereum.EventParam('borrower', ethereum.Value.fromAddress(Address.fromString(borrower)))

    accepteddBidEvent.parameters.push(bidIdParam)
    accepteddBidEvent.parameters.push(lenderParam)
    // Return mocked event
    return accepteddBidEvent
}

/**
 * Function to mock an emitted event for a Cancelled Bid to the protocol.
 * @param bidId The id of the submitted bid.
 */
export function createCancelledBidEvent (
    bidId: i32,
): CancelledBid  {
    let mockEvent = changetype<CancelledBid>(newMockEvent())
    let cancelledBidEvent = new CancelledBid(
        mockEvent.address,
        mockEvent.logIndex,
        mockEvent.transactionLogIndex,
        mockEvent.logType,
        mockEvent.block,
        mockEvent.transaction,
        mockEvent.parameters
    )
    // Mock event data
    let bidIdParam = new ethereum.EventParam('bidId', ethereum.Value.fromI32(bidId))

    cancelledBidEvent.parameters.push(bidIdParam)
    // Return mocked event
    return cancelledBidEvent
}

/**
 * Function to mock an emitted event for a Loan Repayment to the protocol.
 * @param bidId The id of the repaid loan/bid.
 */
export function createLoanRepaymentEvent (
    bidId: i32,
): LoanRepayment  {
    let mockEvent = changetype<LoanRepayment>(newMockEvent())
    let loanRepaymentEvent = new LoanRepayment(
        mockEvent.address,
        mockEvent.logIndex,
        mockEvent.transactionLogIndex,
        mockEvent.logType,
        mockEvent.block,
        mockEvent.transaction,
        mockEvent.parameters
    )
    // Mock event data
    let bidIdParam = new ethereum.EventParam('bidId', ethereum.Value.fromI32(bidId))

    loanRepaymentEvent.parameters.push(bidIdParam)
    // Return mocked event
    return loanRepaymentEvent
}

/**
 * Function to mock an emitted event for a Loan Repaid to the protocol.
 * @param bidId The id of the repaid loan/bid.
 */
export function createLoanRepaidEvent (
    bidId: i32,
): LoanRepaid  {
    let mockEvent = changetype<LoanRepaid>(newMockEvent())
    let loanRepaidEvent = new LoanRepaid(
        mockEvent.address,
        mockEvent.logIndex,
        mockEvent.transactionLogIndex,
        mockEvent.logType,
        mockEvent.block,
        mockEvent.transaction,
        mockEvent.parameters
    )
    // Mock event data
    let bidIdParam = new ethereum.EventParam('bidId', ethereum.Value.fromI32(bidId))

    loanRepaidEvent.parameters.push(bidIdParam)
    // Return mocked event
    return loanRepaidEvent
}