
pragma solidity >=0.8.0 <0.9.0;

/*


The ThirdWeb staking contracts expose 1 claim per 1 staked pool, but users have many pools and a lot of tokens staked, so it’s just a lot of buttons for them to click
In order for a user who has ie 10 staked pool tokens, so 10 reward tokens to claim, to only have 1 claim all tx, we’d need an actual solidity function for it. The wallet must be msg.sender for the tx
The solidity function for claim all rewards would take an array of staking contracts and loop those, calling the claimRewards write function on each. It can also take in the amount the user claims for each.
Auto-compound would take both a staking contract and a teller pool input. The function would call both claimRewards from the staking contract + call approve + deposit on the teller pool. It can take in both the amount to claim for each, and amount to deposit.
To combine the two, there could be another function for claimAllAndAutoCompound which does a loop of auto-compound for an array of [staking contracts + teller pools]

*/


/*
		This contract needs to be set as a trusted forwarder as per EIP2771 
		likely with GrantRole 
*/
contract RewardRedeemer {



	struct AutoCompoundInputRow {

		address stakingContract,

		address tellerPool, 
 
		
	}




	function claim_multi( 

		address[] stakingContractsArray 

	  ) external  {


		address stakerAddress =  msg.sender; 

		// loop through each staking contrat and call claimRewards 


		for ( x  in  stakingContractsArray ) {


			//need to call this in such a way that the last 20 bytes is the  stakerAddress
			  
		          _forwardCall(
		            abi.encodeWithSelector(
		                IStaking20.claimRewards.selector 
		            ),
		            stakerAddress
		        );


		}




	} 







	function compound_multi( AutoCompoundInputRow[] inputRow  ) external {





	}



	  function _forwardCall(bytes memory _data, address _msgSender)
        internal
        returns (bytes memory)
    {
        return
            address(_tellerV2).functionCall(
                abi.encodePacked(_data, _msgSender)
            );
    }





}