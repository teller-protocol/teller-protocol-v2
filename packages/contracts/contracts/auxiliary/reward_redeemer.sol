// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/*


The ThirdWeb staking contracts expose 1 claim per 1 staked pool, but users have many pools and a lot of tokens staked, so it's just a lot of buttons for them to click
In order for a user who has ie 10 staked pool tokens, so 10 reward tokens to claim, to only have 1 claim all tx, we'd need an actual solidity function for it. The wallet must be msg.sender for the tx
The solidity function for claim all rewards would take an array of staking contracts and loop those, calling the claimRewards write function on each. It can also take in the amount the user claims for each.
Auto-compound would take both a staking contract and a teller pool input. The function would call both claimRewards from the staking contract + call approve + deposit on the teller pool. It can take in both the amount to claim for each, and amount to deposit.
To combine the two, there could be another function for claimAllAndAutoCompound which does a loop of auto-compound for an array of [staking contracts + teller pools]

*/

import "../interfaces/auxiliary/IStaking20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ILenderCommitmentGroupPool {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
}

/*
	This contract needs to be set as a trusted forwarder as per EIP2771
	during init
*/
contract RewardRedeemer is Initializable, OwnableUpgradeable {

	using AddressUpgradeable for address;

	/**
	 * @notice Initializes the RewardRedeemer contract
	 */
	function initialize() public initializer {
		__Ownable_init();
	}

	// Events
	event RewardsClaimed(address indexed user, address[] stakingContracts);
	event RewardsCompounded(address indexed user, address[] stakingContracts, address[] tellerPools, uint256[] depositedAmounts);

	struct AutoCompoundInputRow {
		address stakingContract;
		address tellerPool;
		address rewardToken;
	}

	/**
	 * @notice Claims rewards from multiple staking contracts in a single transaction
	 * @param stakingContractsArray Array of staking contract addresses to claim rewards from
	 */
	function claim_multi(
		address[] calldata stakingContractsArray
	) external {

		address stakerAddress = msg.sender;

		// Loop through each staking contract and call claimRewards
		for (uint256 i = 0; i < stakingContractsArray.length; i++) {
			address stakingContract = stakingContractsArray[i];

			// Call claimRewards on the staking contract using EIP-2771 forwarding
			// The staking contract must trust this contract as a forwarder
			_forwardCall(
				stakingContract,
				abi.encodeWithSelector(
					IStaking20.claimRewards.selector
				),
				stakerAddress
			);
		}

		emit RewardsClaimed(stakerAddress, stakingContractsArray);
	}

	/**
	 * @notice Claims rewards and automatically compounds them by depositing into Teller pools
	 * @param inputRows Array of compound instructions containing staking contract, pool, and reward token info
	 */
	function compound_multi(
		AutoCompoundInputRow[] calldata inputRows
	) external {

		address stakerAddress = msg.sender;

		address[] memory stakingContracts = new address[](inputRows.length);
		address[] memory tellerPools = new address[](inputRows.length);
		uint256[] memory depositedAmounts = new uint256[](inputRows.length);

		// Loop through each compound instruction
		for (uint256 i = 0; i < inputRows.length; i++) {
			AutoCompoundInputRow calldata row = inputRows[i];

			stakingContracts[i] = row.stakingContract;
			tellerPools[i] = row.tellerPool;

			IERC20Upgradeable rewardToken = IERC20Upgradeable(row.rewardToken);

			// Step 1: Check balance before claiming
			uint256 balanceBefore = rewardToken.balanceOf(stakerAddress);

			// Step 2: Claim rewards from the staking contract
			_forwardCall(
				row.stakingContract,
				abi.encodeWithSelector(
					IStaking20.claimRewards.selector
				),
				stakerAddress
			);

			// Step 3: Check balance after claiming to determine amount received
			uint256 balanceAfter = rewardToken.balanceOf(stakerAddress);
			uint256 claimedAmount = balanceAfter - balanceBefore;
			depositedAmounts[i] = claimedAmount;

			// Only proceed if we actually claimed some rewards
			if (claimedAmount > 0) {
				// Step 4: Transfer reward tokens from user to this contract
				rewardToken.transferFrom(stakerAddress, address(this), claimedAmount);

				// Step 5: Approve the teller pool to spend the reward tokens
				rewardToken.approve(row.tellerPool, claimedAmount);

				// Step 6: Deposit the reward tokens into the teller pool
				ILenderCommitmentGroupPool(row.tellerPool).deposit(
					claimedAmount,
					stakerAddress
				);
			}
		}

		emit RewardsCompounded(stakerAddress, stakingContracts, tellerPools, depositedAmounts);
	}

	/**
	 * @dev Internal function to forward calls using EIP-2771 meta-transaction format
	 * @param target The contract address to call
	 * @param data The encoded function call data
	 * @param msgSender The address that should be treated as the msg.sender
	 */
	function _forwardCall(
		address target,
		bytes memory data,
		address msgSender
	) internal returns (bytes memory) {
		// Append the msgSender address to the calldata for EIP-2771 compatibility
		return target.functionCall(
			abi.encodePacked(data, msgSender)
		);
	}
}
