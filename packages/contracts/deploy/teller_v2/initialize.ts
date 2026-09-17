import { getGlobalCommitmentForwarderName } from '../../config/global-commitment-forwarder'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { logTxLink } from 'helpers/logTxLink'
import { TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Initializing...', { nl: false })

  const protocolFee = 5 // 0.05%

  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const reputationManager = await hre.contracts.get('ReputationManager')
  // This writes TellerV2's global forwarder slot, which has no setter and is
  // only ever written here. Whichever forwarder lands in it is trusted on every
  // market forever - including markets whose own single slot is already spent
  // on the SmartCommitmentForwarder for pools.
  //
  // This used to fall back to Alpha whenever LenderCommitmentForwarder was
  // absent. A silent catch is the wrong shape for a permanent decision: on
  // Robinhood the forwarder was merely missing from a deploy allowlist, and the
  // fallback quietly made Alpha global for good. Fail instead, and let a chain
  // that genuinely wants Alpha say so in the overrides.
  const forwarderName = getGlobalCommitmentForwarderName(hre.network)
  let lenderCommitmentForwarder
  try {
    lenderCommitmentForwarder = await hre.contracts.get(forwarderName)
  } catch {
    throw new Error(
      `TellerV2.initialize needs ${forwarderName} for the global forwarder ` +
        `slot on ${hre.network.name}, and it is not deployed.\n` +
        `The slot is permanent - there is no setter - so this will not be ` +
        `fixable after the fact. Deploy ${forwarderName} first, or record an ` +
        `explicit choice in config/global-commitment-forwarder.ts.`
    )
  }
  const collateralManager = await hre.contracts.get('CollateralManager')
  const lenderManager = await hre.contracts.get('LenderManager')
  const escrowVault = await hre.contracts.get('EscrowVault')

  const protocolPausingManager = await hre.contracts.get('ProtocolPausingManager')

  const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')
  const tx = await tellerV2.initialize(
    protocolFee,
    marketRegistry,
    reputationManager,
    lenderCommitmentForwarder,
    collateralManager,
    lenderManager,
    escrowVault,
    protocolPausingManager
  )
  await tx.wait(1) // wait one block

  hre.log('done.')
  await logTxLink(hre, tx.hash)
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'teller-v2:init'
deployFn.tags = ['teller-v2', 'teller-v2:init']
deployFn.dependencies = [
  'teller-v2:deploy',
  'market-registry:deploy',
  'reputation-manager:deploy',
  'lender-commitment-forwarder:deploy',
  'collateral:manager:deploy',
  'lender-manager:deploy',
  'escrow-vault:deploy',
  'protocol-pausing-manager:deploy'
]
export default deployFn
