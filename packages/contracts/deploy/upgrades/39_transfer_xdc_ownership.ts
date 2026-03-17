import { DeployFunction } from 'hardhat-deploy/dist/types'
import { logTxLink } from 'helpers/logTxLink'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('XDC: Transferring ownership of contracts to Safe Multisig')
  hre.log('')

  const { deployer, protocolOwnerSafe } = await hre.getNamedAccounts()

  const contractNames = [
    'SmartCommitmentForwarder',
    'LenderCommitmentGroupFactory_V2',
    'CollateralManager',
  ]

  for (const contractName of contractNames) {
    const contract = await hre.contracts.get(contractName)
    const currentOwner = await contract.owner()

    if (deployer === currentOwner) {
      hre.log(`  Transferring ${contractName} ownership...`)
      const tx = await contract.transferOwnership(protocolOwnerSafe)
      await tx.wait(1)

      hre.log(
        `  ✅  ${contractName} ownership transferred to Safe Multisig (${protocolOwnerSafe})`
      )
      await logTxLink(hre, tx.hash)
    } else if (protocolOwnerSafe === currentOwner) {
      hre.log(
        `  ✅  ${contractName} ownership is already set to the Safe Multisig`
      )
    } else {
      hre.log(
        `  ⚠️  ${contractName} is owned by ${currentOwner} (not deployer). Skipping.`
      )
    }
  }

  hre.log('')
  hre.log('done.')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'xdc:transfer-ownership-to-safe'
deployFn.tags = ['xdc', 'xdc:transfer-ownership-to-safe']
deployFn.dependencies = [
  'smart-commitment-forwarder:deploy',
  'lender-commitment-group-factory-v2:deploy',
  'collateral:manager:deploy',
]

deployFn.skip = async (hre) => {
  return !hre.network.live || hre.network.name !== 'xdc'
}
export default deployFn
