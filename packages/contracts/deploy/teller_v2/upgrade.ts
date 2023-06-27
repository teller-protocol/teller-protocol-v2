import { DeployFunction } from 'hardhat-deploy/dist/types'
import { TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Proposing upgrade...')

  const trustedForwarder = await hre.contracts.get('MetaForwarder')
  const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')
  const implFactory = await hre.ethers.getContractFactory('TellerV2')

  // *************** EXAMPLE ***************

  // await hre.defender.proposeUpgradeAndCall(tellerV2.address, implFactory, {
  //   title: 'TellerV2 Upgrade',
  //   description: 'Upgrades the TellerV2 implementation contract.',
  //
  //   unsafeAllow: ['constructor', 'state-variable-immutable'],
  //   constructorArgs: [trustedForwarder.address],
  //
  //   callFn: 'initialize',
  //   callArgs: [
  //     '1234',
  //     tellerV2.address,
  //     tellerV2.address,
  //     tellerV2.address,
  //     tellerV2.address,
  //     tellerV2.address,
  //   ],
  // })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'teller-v2:upgrade'
deployFn.tags = ['teller-v2', 'teller-v2:upgrade']
deployFn.dependencies = ['teller-v2:init']
deployFn.skip = async (hre) => {
  return true
}
export default deployFn
