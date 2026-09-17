import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const lenderCommitmentForwarder = await hre.deployProxy(
    'LenderCommitmentForwarder',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        await tellerV2.getAddress(),
        await marketRegistry.getAddress(),
      ],
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:deploy',
]
deployFn.dependencies = ['teller-v2:deploy', 'market-registry:deploy']

// LenderCommitmentForwarder is what a lending offer is written against: an
// offer is a commitment on this contract, so a chain without it can create
// pools and markets and still refuse every offer. Robinhood hit exactly that —
// contracts, markets and sixteen pools live, and "Lending offers need Teller's
// commitment forwarder, and it is not deployed on Robinhood Chain".
//
// Note this list is narrower than the set of chains that actually carry the
// contract: Base, Arbitrum, Polygon and others were deployed before it was
// added, so their artifacts exist while their names are absent here. Adding a
// name is what lets a *new* chain get one.
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    !['sepolia', 'katana', 'hyperevm', 'robinhood'].includes(hre.network.name)
  )
}

export default deployFn
