import { assert, createMockedFunction, clearStore, test, newMockEvent, newMockCall, countEntities } from "matchstick-as/assembly/index"
import { Address, BigInt, Bytes, ethereum, store, Value } from "@graphprotocol/graph-ts"

// Import generated
import { Bid } from "../generated/schema"
import { TellerV2, SubmittedBid, SubmitBidCall } from "../generated/TellerV2/TellerV2"

// Import event mockers
import {createCancelledBidEvent, createSubmittedBidEvent} from "./utils";

// Import event handlers from mapping to be tested
import {handleCancelledBids, handleSubmittedBid, handleSubmittedBids} from "../src/mapping"

// Coverage
// export { handleSubmittedBid }

test('Can call handleSubmittedBid mapping with mocked event', () => {
    // Initialize
    let bid = new Bid('1')
    bid.save()

    assert.entityCount('Bid', 1)
    assert.fieldEquals('Bid', '1', 'id', '1')

    // Mock data
    const bidId = 0xbeef
    const borrower = '0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7'
    const metadataURI = Bytes.fromHexString('ipfs://bafybeibnsoufr2renqzsh347nrx54wcubt5lgkeivez63xvivplfwhtpym/metadata.json')

    // Call mapping
    let submittedBidEvent = createSubmittedBidEvent(
        bidId,
        borrower,
        metadataURI
    )

    handleSubmittedBids([submittedBidEvent])

    // Assertions
    assert.entityCount('Bid', 2)
    assert.fieldEquals('Bid', '0xbeef', 'borrower',  borrower)
    assert.fieldEquals('Bid', '0xbeef', 'status',  'Submitted')
    assert.fieldEquals('Bid', '0xbeef', 'metadataURI', metadataURI.toHexString())

})

test('Can call handleCancelledBid mapping with mocked event', () => {
    const bidId = 0xbeef
    // Call cancelledBidEvent mapping
    let cancelledBidEvent = createCancelledBidEvent(bidId)

    handleCancelledBids([cancelledBidEvent])

    // Assertions
    assert.entityCount('Bid', 2)
    assert.fieldEquals('Bid', '0xbeef', 'status', 'Cancelled')

    // Clear storage for next test
    clearStore()
})

