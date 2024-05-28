import fs from 'fs'

import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { Deployment } from 'hardhat-deploy/dist/types'

task(
  'export:deployments',
  'Export contract deployments for react-app and subgraph packages'
).setAction(async (args, hre) => {
  await publishSubgraph(hre)
})

const publishSubgraph = async (
  hre: HardhatRuntimeEnvironment
): Promise<void> => {
  const deployments = await hre.deployments.all()
  for (const contractName in deployments) {
    const deployment = deployments[contractName]
    await writeSubgraphContract(hre, '../subgraph',contractName, deployment, hre.network.name)
    await writeSubgraphContract(hre, '../subgraph-substreamed',contractName, deployment, hre.network.name)
  
  }
  console.log('✅  Published contracts to the subgraph package.')
}

//const graphDir = '../subgraph'
async function writeSubgraphContract(
  hre: HardhatRuntimeEnvironment,
  graphDir: String,
  contractName: string,
  deployment: Deployment,
  networkName: string
): Promise<boolean> {
  try {
    const folderPath = `${graphDir}/config/`
    if (!fs.existsSync(folderPath)) {
      fs.mkdirSync(folderPath)
    }
    if (!fs.existsSync(`${graphDir}/abis`)) fs.mkdirSync(`${graphDir}/abis`)
    fs.writeFileSync(
      `${graphDir}/abis/${networkName}_${contractName}.json`,
      JSON.stringify(deployment.abi, null, 2)
    )

    return true
  } catch (e) {
    console.log(`Failed to publish ${chalk.red(contractName)} to the subgraph.`)
    console.log(e)
    return false
  }
}
