import { DeployFunction } from 'hardhat-deploy/dist/types'


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Lender Pools V3: Proposing upgrade...')

  const lenderCommitmentGroupV3Beacon = await hre.contracts.get('LenderCommitmentGroupBeaconV3')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )
  const tellerV2Address = await tellerV2.getAddress()
  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

  await hre.upgrades.proposeBatchTimelock({
    title: 'Lender Pools V3: Re-enable setMaxPrincipalPerCollateralAmount',
    description: `
# Lender Pools V3

* Re-adds setMaxPrincipalPerCollateralAmount so pool owners can set a manual cap on the principal-per-collateral price ratio.
* When set (nonzero), the pool uses the lesser of the oracle price and the manual cap — protecting lenders from inflated oracle values.
* When zero (default), pricing uses the oracle only (no behavior change for existing pools).
`,
    _steps: [
      {
        beacon: lenderCommitmentGroupV3Beacon,
        implFactory: await hre.ethers.getContractFactory('LenderCommitmentGroup_Pool_V3'),

        opts: {
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
          ],
          constructorArgs: [
            tellerV2Address,
            smartCommitmentForwarderAddress,
          ],
        },
      },
    ],
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-group-beacon-v3:upgrade-max-principal'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-group-beacon-v3',
  'lender-commitment-group-beacon-v3:upgrade-max-principal',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy',
  'lender-commitment-group-beacon-v3:deploy',
]
deployFn.skip = async (hre) => {
  return hre.network.name !== 'apechain'
}
export default deployFn
