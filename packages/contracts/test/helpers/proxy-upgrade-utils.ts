import chai, { expect } from 'chai'
import chaiAsPromised from 'chai-as-promised'
import { getTokens } from 'config'
import { BigNumber, Contract, ContractFactory, Signer, Wallet } from 'ethers'
import hre, { ethers, getNamedSigner } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const OpenZeppelinTransparentProxy = require('../contracts/abi/OpenZeppelinTransparentProxy.abi.json')
const OpenZeppelinTransparentProxyAdmin = require('../contracts/abi/OpenZeppelinTransparentProxyAdmin.abi.json')

export interface ProxyUpgradeInputs {
  contract: string
  existingProxyAddress: string
  proxyAdminAddress: string
  signer: Signer
  args: any
  proxy: {
    proxyContract?: string
    execute?: { init: any; onUpgrade: any }
  }
}

export async function upgradeProxyAdminWithImplementation(
  proxyUpgradeInputs: ProxyUpgradeInputs
): Promise<void> {
  const signer: Signer = proxyUpgradeInputs.signer

  const newImplementation = await deploy({
    contract: proxyUpgradeInputs.contract,
    args: proxyUpgradeInputs.args,
    hre,
  })

  const newImplementationAddress = newImplementation.address

  const proxyAdminContract = new Contract(
    proxyUpgradeInputs.proxyAdminAddress,
    OpenZeppelinTransparentProxyAdmin,
    signer
  )

  const implementationInterface = newImplementation.interface

  if (
    // eslint-disable-next-line  @typescript-eslint/prefer-optional-chain
    proxyUpgradeInputs.proxy.execute &&
    proxyUpgradeInputs.proxy.execute.onUpgrade
  ) {
    const calldata = implementationInterface.encodeFunctionData(
      proxyUpgradeInputs.proxy.execute.onUpgrade.methodName,
      proxyUpgradeInputs.proxy.execute.onUpgrade.args
    )

    const proxyUpgrade = await proxyAdminContract
      .connect(signer)
      .upgradeAndCall(
        proxyUpgradeInputs.existingProxyAddress,
        newImplementationAddress,
        calldata
      )

    return proxyUpgrade
  } else {
    const proxyUpgrade = await proxyAdminContract
      .connect(signer)
      .upgrade(
        proxyUpgradeInputs.existingProxyAddress,
        newImplementationAddress
      )

    return proxyUpgrade
  }
}

export async function upgradeProxyWithImplementation(
  proxyUpgradeInputs: ProxyUpgradeInputs
): Promise<void> {
  const signer: Signer = proxyUpgradeInputs.signer

  const newImplementation = await deploy({
    contract: proxyUpgradeInputs.contract,
    args: proxyUpgradeInputs.args,
    hre,
  })

  const newImplementationAddress = newImplementation.address

  const proxyContract = new Contract(
    proxyUpgradeInputs.existingProxyAddress,
    OpenZeppelinTransparentProxy,
    signer
  )
  const proxyUpgrade = await proxyContract
    .connect(signer)
    .upgradeTo(newImplementationAddress)

  if (proxyUpgradeInputs.proxy.execute) {
    const upgradeMethodName =
      proxyUpgradeInputs.proxy.execute.onUpgrade.methodName
    const upgradeArgs = proxyUpgradeInputs.proxy.execute.onUpgrade.args
    await proxyContract.connect(signer)[upgradeMethodName](upgradeArgs)
  }

  return proxyUpgrade
}
