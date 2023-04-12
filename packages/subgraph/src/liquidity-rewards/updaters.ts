import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { MarketLiquidityRewards } from "../../generated/MarketLiquidityRewards/MarketLiquidityRewards";
import { Bid, RewardAllocation, Token, TokenVolume, User } from "../../generated/schema";
import { loadBidById, loadLoanStatusCount, loadMarketTokenVolume, loadProtocol, loadToken } from "../helpers/loaders";
import { addToArray, removeFromArray } from "../helpers/utils";

import { loadRewardAllocation } from "./loaders";
import { AllocationStatus, allocationStatusToString } from "./utils";
//import { CommitmentStatus, commitmentStatusToString } from "./utils";

enum CollateralTokenType {
  NONE,
  ERC20,
  ERC721,
  ERC1155,
  ERC721_ANY_ID,
  ERC1155_ANY_ID
}


export function updateAllocationStatus(
  allocation: RewardAllocation,
  status: AllocationStatus
): void {
  allocation.status = allocationStatusToString(status);

  switch (status) {
    case AllocationStatus.Active:
   //   addCommitmentToProtocol(commitment);
      break;
    case AllocationStatus.Deleted:
    case AllocationStatus.Drained:
    case AllocationStatus.Expired:
   /*   updateAvailableTokensFromCommitment(
        commitment,
        commitment.committedAmount.neg()
      );
      removeCommitmentToProtocol(commitment);*/

      break;
  }

  allocation.save();
}


 

/**
 * @param {string} allocationId - ID of the commitment
 * @param {Address} allocatorAddress - Address of the allocator
 * @param {string} marketplaceId - ID of the marketplace
 * @param {Address} eventAddress - Address of the emitted event
 * @param {ethereum.Block} eventBlock - Block of the emitted event
 */

export function createRewardAllocation(
  allocationId: string,
  allocatorAddress: Address,
  marketplaceId: string,  
  eventAddress: Address,
  eventBlock: ethereum.Block  
): RewardAllocation {

  const allocation = loadRewardAllocation(allocationId);

  const marketLiquidityRewardsInstance = MarketLiquidityRewards.bind(
    eventAddress
  );
  const allocatedReward = marketLiquidityRewardsInstance.allocatedRewards(
    BigInt.fromString(allocationId)
  );

  allocation.allocatorAddress = allocatedReward.value0;
  allocation.rewardTokenAddress = allocatedReward.value1;
  allocation.rewardToken = loadToken(allocatedReward.value1).id;
  allocation.rewardTokenAmountInitial = allocatedReward.value2;
  allocation.rewardTokenAmountRemaining = allocatedReward.value2;
  allocation.marketplaceId = allocatedReward.value3;
  allocation.requiredPrincipalTokenAddress = allocatedReward.value4;
  allocation.requiredCollateralTokenAddress = allocatedReward.value5;
  allocation.minimumCollateralPerPrincipalAmount = allocatedReward.value6;
  allocation.rewardPerLoanPrincipalAmount = allocatedReward.value7;
  allocation.bidStartTimeMin = allocatedReward.value8;
  allocation.bidStartTimeMax = allocatedReward.value9;
  allocation.allocationStrategy = allocatedReward.value10 == 0 ? "BORROWER" : "LENDER";


  allocation.save()

 
  updateAllocationStatus(allocation, AllocationStatus.Active);

  return allocation;
}



/**
 * @param {string} allocationId - ID of the commitment
 * @param {Address} eventAddress - Address of the emitted event
 * @param {ethereum.Block} eventBlock - Block of the emitted event
 */
export function updateRewardAllocation(
  allocationId: string,
  eventAddress: Address,
  eventBlock: ethereum.Block
): RewardAllocation {
  const allocation = loadRewardAllocation(allocationId);


  /*  struct RewardAllocation {
        address allocator;
        address rewardTokenAddress;
        uint256 rewardTokenAmount;
        uint256 marketId;
        //requirements for loan
        address requiredPrincipalTokenAddress; //0 for any
        address requiredCollateralTokenAddress; //0 for any  -- could be an enumerable set?
        uint256 minimumCollateralPerPrincipalAmount;
        uint256 rewardPerLoanPrincipalAmount;
        uint32 bidStartTimeMin;
        uint32 bidStartTimeMax;
        AllocationStrategy allocationStrategy;
    }

    */

  const marketLiquidityRewardsInstance = MarketLiquidityRewards.bind(
    eventAddress
  );
  const allocatedReward = marketLiquidityRewardsInstance.allocatedRewards(
    BigInt.fromString(allocationId)
  ); 

  allocation.rewardTokenAmountRemaining = allocatedReward.value2;
   
  allocation.minimumCollateralPerPrincipalAmount = allocatedReward.value6;
  allocation.rewardPerLoanPrincipalAmount = allocatedReward.value7;
  allocation.bidStartTimeMin = allocatedReward.value8;
  allocation.bidStartTimeMax = allocatedReward.value9;

  
  allocation.save();
    

 
  updateAllocationStatus(allocation, AllocationStatus.Active);

/*
  const lender = loadLenderByMarketId(lenderAddress, marketId);

  commitment.lender = lender.id;
  commitment.lenderAddress = lender.lenderAddress;
  commitment.marketplace = marketId;
  commitment.marketplaceId = BigInt.fromString(marketId);

  const lenderCommitmentForwarderInstance = LenderCommitmentForwarder.bind(
    eventAddress
  );
  const lenderCommitment = lenderCommitmentForwarderInstance.commitments(
    BigInt.fromString(commitmentId)
  );

  commitment.expirationTimestamp = lenderCommitment.value1;
  commitment.maxDuration = lenderCommitment.value2;
  commitment.minAPY = BigInt.fromI32(lenderCommitment.value3);

  const lendingToken = loadToken(lendingTokenAddress);
  commitment.principalToken = lendingToken.id;
  commitment.principalTokenAddress = lendingTokenAddress;

  if (lenderCommitment.value7 != CollateralTokenType.NONE) {
    let tokenType = TokenType.UNKNOWN;
    let nftId: BigInt | null = null;
    switch (lenderCommitment.value7) {
      case CollateralTokenType.ERC20:
        tokenType = TokenType.ERC20;
        break;
      case CollateralTokenType.ERC721_ANY_ID:
        nftId = lenderCommitment.value5;
      case CollateralTokenType.ERC721:
        tokenType = TokenType.ERC721;
        break;
      case CollateralTokenType.ERC1155_ANY_ID:
        nftId = lenderCommitment.value5;
      case CollateralTokenType.ERC1155:
        tokenType = TokenType.ERC1155;
        break;
    }
    const collateralToken = loadToken(
      lenderCommitment.value4,
      tokenType,
      nftId
    );
    commitment.collateralToken = collateralToken.id;
    commitment.maxPrincipalPerCollateralAmount = lenderCommitment.value6;
  }

  const volume = loadCommitmentTokenVolume(lendingToken.id, commitment);
  commitment.tokenVolume = volume.id;

  commitment.save();

  updateCommitmentStatus(commitment, CommitmentStatus.Active);
  const committedAmountDiff = committedAmount.minus(commitment.committedAmount);
  updateAvailableTokensFromCommitment(commitment, committedAmountDiff);
  */
  return allocation;
}











/*
RUN THIS FUNCTION : 
1. When a bid is accepted or repaid 
2. When an allocation is created or updated 


DESCRIPTION: 
This function will loop through all of the bids (matching market id and principal token) in order to update the protocol entity array 

 

verify that the reward is active and has funds remaining 

*/

export function linkRewardToBids(rewardAllocation:RewardAllocation) {

  const loansForMarket = loadLoanStatusCount('market',rewardAllocation.marketplaceId.toString());

  const rewardableLoans = loansForMarket.accepted
  .concat(loansForMarket.repaid)
  .concat(loansForMarket.late)
  .concat(loansForMarket.dueSoon)
  .concat(loansForMarket.defaulted)
  .concat(loansForMarket.liquidated)
  
  for(let i = 0; i < rewardableLoans.length; i++){

    let bidId = BigInt.fromString(rewardableLoans[i]);
    let bid = loadBidById(bidId);

    //check to see if the bid is eligible for the reward
    /*
    check min and max time stamp for ACCEPTED 



    
    */
    if( //make this a function later
      (bid.lendingTokenAddress == rewardAllocation.requiredPrincipalTokenAddress || rewardAllocation.requiredPrincipalTokenAddress == Address.empty() )
      && bid.collateralTokenAddress == rewardAllocation.requiredCollateralTokenAddress 
      && 
      
      ){



      //create a bid reward entity 
      let bidReward = new BidReward(`${bid.id.toString()}-${rewardAllocation.id.toString()}`);

      ///this only happens if bid is repaid 
      let borrower = User.load(bid.borrowerAddress.toString())!
      borrower.save()

      
      //this happens in more situations 
      let lender = User.load(bid.lenderAddress!.toString())!

      lender.save()
      
    }

    bid.save()


  }

   
}


/*
  when a bid is accepted or repaid ...


  find all of the allocations that are active , see if the bid can be assigned to the allocation 
*/
export function linkBidToRewards(bid:Bid){

  let protocol = loadProtocol();

  let activeRewardIds = protocol.activeRewards; 

  for(let i = 0; i < activeRewardIds.length; i++){

    let allocationRewardId = activeRewardIds[i];

    let rewardAllocation = RewardAllocation.load(allocationRewardId)!;

    if( //make this a function later
    (bid.lendingTokenAddress == rewardAllocation.requiredPrincipalTokenAddress || rewardAllocation.requiredPrincipalTokenAddress == Address.empty() )
    && bid.collateralTokenAddress == rewardAllocation.requiredCollateralTokenAddress 
    && 
    
    ){



      //create a bid reward entity 
      let bidReward = new BidReward(`${bid.id.toString()}-${rewardAllocation.id.toString()}`);

          
      let borrower = User.load(bid.borrowerAddress.toString())!
      //modify the entity so it has an array of bidReward 

      borrower.save()


      let lender = User.load(bid.lenderAddress!.toString())!

      lender.save()




    

    }





  }

}


/* 
function addCommitmentToProtocol(commitment: Commitment): void {
  const protocol = loadProtocol();
  protocol.activeCommitments = addToArray(
    protocol.activeCommitments,
    commitment.id
  );
  protocol.save();
}
function removeCommitmentToProtocol(commitment: Commitment): void {
  const protocol = loadProtocol();
  protocol.activeCommitments = removeFromArray(
    protocol.activeCommitments,
    commitment.id
  );
  protocol.save();
}

export function updateAvailableTokensFromCommitment(
  commitment: Commitment,
  committedAmountDiff: BigInt
): void {
  if (committedAmountDiff.isZero()) {
    return;
  }

  commitment.committedAmount = commitment.committedAmount.plus(
    committedAmountDiff
  );
  commitment.save();

  const tokenVolumes = getTokenVolumesFromCommitment(commitment);
  for (let i = 0; i < tokenVolumes.length; i++) {
    const tokenVolume = tokenVolumes[i];
    tokenVolume.totalAvailable = tokenVolume.totalAvailable.plus(
      committedAmountDiff
    );
    tokenVolume.save();
  }
}

function getTokenVolumesFromCommitment(commitment: Commitment): TokenVolume[] {
  const tokenVolumes = new Array<TokenVolume>();

  const protocolVolume = loadProtocolTokenVolume(commitment.principalToken);
  tokenVolumes.push(protocolVolume);

  const commitmentVolume = loadCommitmentTokenVolume(
    commitment.principalToken,
    commitment
  );
  tokenVolumes.push(commitmentVolume);

  const marketVolume = loadMarketTokenVolume(
    commitment.principalToken,
    commitment.marketplace
  );
  tokenVolumes.push(marketVolume);

  const lenderVolume = loadLenderTokenVolume(
    commitment.principalToken,
    loadLenderByMarketId(commitment.lenderAddress, commitment.marketplace)
  );
  tokenVolumes.push(lenderVolume);

  const collateralTokenId = commitment.collateralToken;
  const collateralToken = Token.load(
    collateralTokenId ? collateralTokenId : ""
  );
  const volumesCount = tokenVolumes.length;
  for (let i = 0; i < volumesCount; i++) {
    const tokenVolume = tokenVolumes[i];
    const collateralVolume = loadCollateralTokenVolume(
      tokenVolume,
      collateralToken
    );
    tokenVolumes.push(collateralVolume);
  }

  return tokenVolumes;
}
*/