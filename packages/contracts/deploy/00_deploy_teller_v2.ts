import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HARDHAT_NETWORK_NAME } from 'hardhat/plugins'
import { deploy } from 'helpers/deploy-helpers'
import { isInitialized } from 'helpers/oz-contract-helpers'
import {
  CollateralManager,
  ReputationManager,
  TellerV2,
  UpgradeableBeacon,
} from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const protocolFee = 5 // 0.05%

  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const trustedForwarder = await hre.contracts.get('MetaForwarder')

  const tellerV2Contract = await deploy<TellerV2>({
    contract: 'TellerV2',
    args: [trustedForwarder.address],
    // mock: hre.network.name === HARDHAT_NETWORK_NAME,
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
    skipIfAlreadyDeployed: false,
    hre,
  })

  /*  
     Need to initialize the LenderCommitmentForwarder after TellerV2 has been deployed because it is a MarketForwarder
  */
  const lenderCommitmentForwarder = await deploy({
    contract: 'LenderCommitmentForwarder',
    args: [tellerV2Contract.address, marketRegistry.address],
    skipIfAlreadyDeployed: true,
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
    hre,
  })

  const reputationManager = await hre.contracts.get<ReputationManager>(
    'ReputationManager'
  )
  // Execute the initialize method of reputation manager
  const reputationIsInitialized = await isInitialized(reputationManager.address)
  if (!reputationIsInitialized) {
    const { wait } = await reputationManager.initialize(
      tellerV2Contract.address
    )
    await wait(1)
  }

  const collateralEscrowBeaconImpl = await deploy({
    contract: 'CollateralEscrowV1',
    name: 'CollateralEscrow',
    skipIfAlreadyDeployed: true,
    hre,
  })

  const collateralEscrowBeacon = await deploy<UpgradeableBeacon>({
    contract: 'UpgradeableBeacon',
    name: 'CollateralEscrowBeacon',
    args: [collateralEscrowBeaconImpl.address],
    skipIfAlreadyDeployed: true,
    hre,
  })
  const currentEscrowBeaconImpl = await collateralEscrowBeacon.implementation()
  if (
    collateralEscrowBeaconImpl.deployResult.newlyDeployed &&
    currentEscrowBeaconImpl !== collateralEscrowBeaconImpl.address
  ) {
    hre.log(
      `Upgrading CollateralEscrow beacon to ${collateralEscrowBeaconImpl.address}... `,
      { indent: 2, star: true, nl: false }
    )
    await collateralEscrowBeacon.upgradeTo(collateralEscrowBeaconImpl.address)
    hre.log(`done`)
  }

  const collateralManager = await deploy<CollateralManager>({
    contract: 'CollateralManager',
    args: [],
    skipIfAlreadyDeployed: false,
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [collateralEscrowBeacon.address, tellerV2Contract.address],
        },
      },
    },
    hre,
  })

  const tellerV2IsInitialized = await isInitialized(tellerV2Contract.address)
  if (!tellerV2IsInitialized) {
    const lenderManager = await hre.contracts.get('LenderManager')
    const { wait } = await tellerV2Contract.initialize(
      protocolFee,
      marketRegistry.address,
      reputationManager.address,
      lenderCommitmentForwarder.address,
      collateralManager.address,
      lenderManager.address
    )
    await wait(1)
  }
}

// tags and deployment
deployFn.tags = ['teller-v2']
deployFn.dependencies = [
  'meta-forwarder',
  'reputation-manager',
  'market-registry',
  'lender-manager',
]
export default deployFn
