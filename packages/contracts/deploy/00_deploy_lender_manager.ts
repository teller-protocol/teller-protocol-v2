import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { deploy } from 'helpers/deploy-helpers'
import { LenderManager, TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const { implName, init } = await getDeployArgs(hre)

  const trustedForwarder = await hre.contracts.get('MetaForwarder')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderManager = await deploy<LenderManager>({
    name: 'LenderManager',
    contract: implName,
    args: [trustedForwarder.address, marketRegistry.address],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init,
      },
      upgradeIndex: 0,
    },
    skipIfAlreadyDeployed: true,
    hre,
  })
}

interface DeployArgs {
  implName: string
  init: { methodName: string; args: any[] }
}
const getDeployArgs = async (
  hre: HardhatRuntimeEnvironment
): Promise<DeployArgs> => {
  const defaultArgs: DeployArgs = {
    implName: 'LenderManager',
    init: {
      methodName: 'initialize',
      args: [],
    },
  }
  return await hre.contracts.get<TellerV2>('TellerV2').then(
    async (tellerV2) => {
      try {
        if (
          // NOTE: `lenderManager` function does not exist until TellerV2 is upgraded
          (await tellerV2.lenderManager()) === hre.ethers.constants.AddressZero
        )
          throw new Error('LenderManager not migrated')
        return defaultArgs
      } catch (err) {
        // If the above fails, then we are deploying the initial LenderManager and must migrate active loan lenders
        const isPaused = await tellerV2.paused()
        if (!isPaused) await tellerV2.pauseProtocol()

        const { activeLoans, activeLoanLenders } = await hre.run(
          'get-active-loans'
        )
        return {
          implName: 'ActivateableLenderManager',
          init: {
            methodName: 'initializeActiveLoans',
            args: [tellerV2.address, activeLoans, activeLoanLenders],
          },
        }
      }
    },
    () => defaultArgs
  )
}

// tags and deployment
deployFn.tags = ['lender-manager']
deployFn.dependencies = ['meta-forwarder', 'market-registry']
export default deployFn
