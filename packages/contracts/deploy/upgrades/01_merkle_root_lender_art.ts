import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )

  const lenderManager = await hre.contracts.get('LenderManager')
  const lenderManagerArt = await hre.contracts.get('LenderManagerArt')

  await hre.defender.proposeBatchTimelock(
    'Merkle Root + Lender Art Upgrade',
    ` 
 
# LenderCommitmentForwarder

* Adds two new collateral types, ERC721_MERKLE_PROOF and ERC1155_MERKLE_PROOF.
* Add a new function acceptCommitmentWithProof which is explicitly used with these new types.
* Merkle proofs can be used to create commitments for a set of tokenIds for an ERC721 or ERC1155 collection.

# Lender Manager 

* Updates the tokenURI function so it returns an svg image rendering with loan summary data.

`,
    [
      {
        proxy: lenderCommitmentForwarder.address,
        implFactory: await hre.ethers.getContractFactory(
          'LenderCommitmentForwarder'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [tellerV2.address, marketRegistry.address]
        }
      },
      {
        proxy: lenderManager.address,
        implFactory: await hre.ethers.getContractFactory('LenderManager', {
          libraries: {
            LenderManagerArt: lenderManagerArt.address
          }
        }),
        opts: {
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking'
          ],
          constructorArgs: [marketRegistry.address]
        }
      }
    ]
  )

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'merkle-root-lender-art:upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-manager',
  'merkle-root-lender-art:upgrade'
]
deployFn.dependencies = [
  'market-registry:deploy',
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy',
  'market-registry:deploy',
  'lender-manager:deploy'
]
deployFn.skip = async (hre) => {
  return false
}
export default deployFn
