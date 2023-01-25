import { upgrades } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HARDHAT_NETWORK_NAME } from 'hardhat/plugins'
import { deploy } from 'helpers/deploy-helpers'
import { isInitialized } from 'helpers/oz-contract-helpers'
import { TellerV2 } from 'types/typechain'

import { getTokens } from '~~/config'

const deployFn: DeployFunction = async (hre) => {
  const protocolFee = 5 // 0.05%

  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const tokens = await getTokens(hre)
  const lendingTokens = [tokens.all.DAI, tokens.all.USDC, tokens.all.WETH]
  if ('USDCT' in tokens.all) {
    lendingTokens.push(tokens.all.USDCT)
  }

  const reputationManager = await deploy({
    contract: 'ReputationManager',
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
    hre,
  })

  const trustedForwarder = await deploy({
    contract: 'MetaForwarder',
    skipIfAlreadyDeployed: true,
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [],
        },
      },
    },
    hre,
  })

  const tellerV2Contract = await deploy({
    contract: 'TellerV2',
    args: [trustedForwarder.address],
    mock: hre.network.name === HARDHAT_NETWORK_NAME,
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
    skipIfAlreadyDeployed: true,
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

  // execute the initialize method of reputation manager
  const reputationIsInitialized = await isInitialized(reputationManager.address)
  if (!reputationIsInitialized) {
    await reputationManager.initialize(tellerV2Contract.address)
  }

  const collateralEscrowBeaconImpl = await deploy({
    contract: 'CollateralEscrowV1',
    name: 'CollateralEscrow',
    skipIfAlreadyDeployed: true,
    hre,
  })

  const collateralEscrowBeacon = await deploy({
    contract: 'UpgradeableBeacon',
    name: 'CollateralEscrowBeacon',
    args: [collateralEscrowBeaconImpl.address],
    skipIfAlreadyDeployed: true,
    hre,
  })

  const collateralManager = await deploy({
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
    await tellerV2Contract.initialize(
      protocolFee,
      marketRegistry.address,
      reputationManager.address,
      lenderCommitmentForwarder.address,
      lendingTokens,
      collateralManager.address
    )
  }
}

// tags and deployment
deployFn.tags = ['teller-v2']
deployFn.dependencies = ['market-registry']
export default deployFn
