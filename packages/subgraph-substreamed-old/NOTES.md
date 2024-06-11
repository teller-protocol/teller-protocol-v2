


### ROI 

commitment rewards 

`RewardTokenAmount` = `allocation.RewardPerPrincipal` * `commitment.MaxLoanAmountFromCommitment`

`MaxRewardAmount` = Min(`RewardTokenAmount`, `allocation.AllocatedRewardTokenAmount`)

 `RewardinPrincipalTokens` = `MaxRewardAmount` * maxPrincipalPerCollateral 

convert into ROI

`ROI` = `RewardPrincipalTokens` / `MaxLoanAmountFromCommitment`   

convert into APY

`APY` = `ROI` * `1 year` / `CommitmentDuration`