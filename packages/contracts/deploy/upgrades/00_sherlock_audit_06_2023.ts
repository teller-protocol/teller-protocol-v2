import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Proposing upgrade...')

  const trustedForwarder = await hre.contracts.get('MetaForwarder')
  const v2Calculations = await hre.contracts.get('V2Calculations')
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const escrowVault = await hre.contracts.get('EscrowVault')
  const collateralManager = await hre.contracts.get('CollateralManager')
  const collateralEscrowBeacon = await hre.contracts.get(
    'CollateralEscrowBeacon'
  )
  const lenderManager = await hre.contracts.get('LenderManager')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )

  await hre.defender.proposeBatchUpgrade(
    'Sherlock Audit Upgrade',
    `
# MarketRegistry

* Adds a new \`isMarketOpen\` function to check if a market is open.

# TellerV2

* Reinitializes the TellerV2 contract to set the EscrowVault address.
* Uses the flipped logic from MarketRegistry to check if a market open.
* When a loan is accepted, if a transfer amount is 0 for any of the receivers, it will be skipped.
* When claiming a loan NFT, the lender address is updated before minting the NFT to prevent a reentrancy attack and updates the loan's lender address to a magic constant.
* Additional repay loan functions were added to skip withdrawing collateral.
* Adds function for lender to close a defaulted loan which will transfer the collateral to the lender and change the state of the loan to \`CLOSED\`.
* When liquidating a loan, the state is updated to \`LIQUIDATED\` before transferring the loan payment to prevent a reentrancy attack.
* When making a loan payment and fails to transfer the payment from the sender to the lender, the funds are pulled from the sender and sent to the \`EscrowVault\` for the lender to claim at a later point.
* Fixed logic for calculating if a loan is defaulted and can be liquidated.
* Fixes a bug in \`getLoanSummary\` to return actual lender address instead of magic constant.

# CollateralManager

* Checks if the bid exists when committing collateral.
* Splits the \`withdraw\` function into separate functions for the borrower and lender.

# CollateralEscrowV1

* Fixes bug where the amount passed into the \`withdraw\` function was not being used.

# LenderManager

* Uses \`_safeMint\` instead of \`_mint\` to prevent reentrancy attacks.

# LenderCommitmentForwarder

* Requires that only the commitment lender is allowed to call the \`updateCommitment\` function.
* Removed \`updateCommitmentBorrowers\` function in favor of \`addCommitmentBorrowers\` and \`removeCommitmentBorrowers\` functions.
* Add checks to ensure the maximum amount allocated to a commitment is not exceeded.
`,
    [
      {
        proxy: marketRegistry.address,
        implFactory: await hre.ethers.getContractFactory('MarketRegistry'),
      },
      {
        proxy: tellerV2.address,
        implFactory: await hre.ethers.getContractFactory('TellerV2', {
          libraries: {
            V2Calculations: v2Calculations.address,
          },
        }),

        opts: {
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking',
          ],
          constructorArgs: [trustedForwarder.address],

          call: {
            fn: 'setEscrowVault',
            args: [escrowVault.address],
          },
        },
      },
      {
        proxy: collateralManager.address,
        implFactory: await hre.ethers.getContractFactory('CollateralManager'),
      },
      {
        beacon: collateralEscrowBeacon.address,
        implFactory: await hre.ethers.getContractFactory('CollateralEscrowV1'),
      },
      {
        proxy: lenderManager.address,
        implFactory: await hre.ethers.getContractFactory('LenderManager'),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [marketRegistry.address],
        },
      },
      {
        proxy: lenderCommitmentForwarder.address,
        implFactory: await hre.ethers.getContractFactory(
          'LenderCommitmentForwarder'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [tellerV2.address, marketRegistry.address],
        },
      },
    ]
  )

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'sherlock-audit:upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'sherlock-audit',
  'sherlock-audit:upgrade',
]
deployFn.dependencies = [
  'market-registry:deploy',
  'teller-v2:v2-calculations',
  'teller-v2:init',
  'escrow-vault:deploy',
]
deployFn.skip = async (hre) => {
  return false

  // const marketRegistry = await hre.contracts.get<MarketRegistry>(
  //   'MarketRegistry'
  // )
  // try {
  //   await marketRegistry.isMarketOpen(0)
  //   return false
  // } catch (e) {
  //   return true
  // }
}
export default deployFn
