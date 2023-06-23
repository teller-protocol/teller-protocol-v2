import '@nomiclabs/hardhat-ethers'
import { ProposalResponse } from '@openzeppelin/defender-admin-client'
import { HardhatDefender as OZHD } from '@openzeppelin/hardhat-defender'
import {
  getAdminClient,
  getNetwork,
} from '@openzeppelin/hardhat-defender/dist/utils'
import {
  DeployBeaconOptions,
  DeployProxyOptions,
} from '@openzeppelin/hardhat-upgrades/dist/utils'
import { PrepareUpgradeOptions } from '@openzeppelin/hardhat-upgrades/src/utils/options'
import * as ozUpgrades from '@openzeppelin/upgrades-core'
import * as tdly from '@teller-protocol/hardhat-tenderly'
import chalk from 'chalk'
import {
  BigNumber,
  BigNumberish,
  Contract,
  ContractFactory,
  Signer,
} from 'ethers'
import { ERC20 } from 'generated/typechain'
import 'hardhat-deploy'
import { extendEnvironment } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import moment from 'moment'

import { getTokens } from '../config'

import { formatMsg, FormatMsgConfig } from './formatMsg'

interface DeployProxyInitArgs {
  initArgs?: any[]
}
interface DeployCustomName {
  customName?: string
}

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    deployProxy: (
      contractName: string,
      opts?: DeployProxyOptions & DeployProxyInitArgs & DeployCustomName
    ) => Promise<Contract>
    deployBeacon: (
      contractName: string,
      opts?: DeployBeaconOptions & DeployCustomName
    ) => Promise<Contract>
    contracts: ContractsExtension
    tokens: TokensExtension
    evm: EVM
    getNamedSigner: (name: string) => Promise<Signer>
    toBN: (amount: BigNumberish, decimals?: BigNumberish) => BigNumber
    fromBN: (amount: BigNumberish, decimals?: BigNumberish) => BigNumber
    log: (msg: string, config?: LogConfig) => void
  }

  interface HardhatDefender extends OZHD {
    proposeUpgradeAndCall: (
      proxyAddress: string,
      implFactory: ContractFactory,
      opts: PrepareUpgradeOptions & {
        title: string
        description: string
        callFn: string
        callArgs: any[]
      }
    ) => Promise<ProposalResponse>
  }
}

interface LogConfig extends FormatMsgConfig {
  disable?: boolean
  error?: boolean
}

interface ContractsExtension {
  get: <C extends Contract>(
    name: string,
    config?: ContractsGetConfig
  ) => Promise<C>

  proxy: {
    /**
     * Returns the implementation version of a proxy contract.
     *
     * ** Warning **
     *  This function checks storage slot 0 of the proxy contract. If the
     *  proxy contract uses a different storage slot for the implementation version
     *  this function will return an incorrect value.
     *
     * @param proxy
     */
    initializedVersion: (proxy: string | Contract) => Promise<number>
  }
}

interface TokensExtension {
  get: (name: string) => Promise<ERC20>
}

interface AdvanceTimeOptions {
  /**
   * When set to `true`, it ensures that a block is not mined for seconds/block
   * internal.
   *
   * In order for the timestamp to take effect a block must be mined. This means
   * that if a view function is called, it will not know about the time update.
   * Use the `mine` option to mine a block after updating the timestamp if used
   * in conjunction with a view function on the next call.
   */
  withoutBlocks?: boolean

  /**
   * Ensures that a block is mined after advancing the next blocks timestamp.
   *
   * This option should be used in conjunction with the `withoutBlocks` option
   * when calling a view function to run any necessary checks.
   */
  mine?: boolean
}

interface EVM {
  /**
   * This sets the timestamp of the next block that executes
   * @param timestamp {moment.Moment} The Moment object that represents a timestamp.
   */
  setNextBlockTimestamp: (timestamp: moment.Moment) => Promise<void>

  /**
   * This increases the next block's timestamp by the specified amount of seconds.
   * @param seconds {BigNumberish | moment.Duration} Amount of seconds to increase the next block's timestamp by.
   */
  advanceTime: (
    seconds: BigNumberish | moment.Duration,
    option?: AdvanceTimeOptions
  ) => Promise<void>

  /**
   * Will mine the specified number of blocks locally. This is helpful when functionality
   * requires a certain number of blocks to be processed for values to change.
   * @param blocks {number} Amount of blocks to mine.
   * @param secsPerBlock {number} Determines how many seconds to increase time by for
   *  each block that is mined. Default is 15.
   */
  advanceBlocks: (blocks?: number, secsPerBlock?: number) => Promise<void>

  /**
   * Mines a new block.
   */
  mine: () => Promise<void>

  /**
   * Creates a snapshot of the blockchain in its current state. It then returns a function
   * that can be used to revert back to the state at which the snapshot was taken.
   */
  snapshot: () => Promise<() => Promise<void>>

  /**
   * This allows for functionality to executed within the scope of the specified number
   * of additional blocks to be mined. Once the supplied function to be called within
   * the scope is executed, the blockchain is reverted back to the state it started at.
   * @param blocks {number} The number of blocks that should be mined.
   * @param fn {function} A function that should be executed once blocks have been mined.
   */
  withBlockScope: <T>(blocks: number, fn: () => T) => Promise<T>

  /**
   * Impersonates a supplied address. This allows for the execution of transactions
   * with the `from` field to be the supplied address. This allows for the context
   * of `msg.sender` in a transaction to also be the supplied address.
   *
   * Once you have completed the action of impersonating an address, you may wish to
   * stop impersonating it. To do this, a `stop` function is also returned for
   * convenience. This may also be achieved by calling `evm.stopImpersonating`.
   *
   * To do this:
   *  1. Impersonate an address.
   *  2. Execute a transaction on a contract by connecting the returned signer.
   *    Ex:
   *      const impersonation = await evm.impersonate(0x123)
   *      await contract.connect(impersonation.signer).functionToCall()
   * @param address {string} An address to start impersonating.
   * @return {Promise<ImpersonateReturn>}
   */
  impersonate: (address: string) => Promise<ImpersonateReturn>

  /**
   * It stops the ability to impersonate an address on the local blockchain.
   * @param address {string} An address to stop impersonating.
   */
  stopImpersonating: (address: string) => Promise<void>
}

interface ImpersonateReturn {
  signer: Signer
  stop: () => Promise<void>
}

interface ContractsGetConfig {
  from?: string | Signer
  at?: string
}

extendEnvironment((hre) => {
  const { deployments, ethers, network } = hre

  if (!network.live) tdly.setup({ automaticVerifications: true })

  hre.deployProxy = async (contractName, { initArgs, ...opts } = {}) => {
    return await ozDefenderDeploy(hre, 'proxy', contractName, initArgs, opts)
  }

  hre.deployBeacon = async (contractName, opts) => {
    return await ozDefenderDeploy(hre, 'beacon', contractName, opts)
  }

  hre.contracts = {
    async get<C extends Contract>(
      name: string,
      config?: ContractsGetConfig
    ): Promise<C> {
      const { abi, address } = await deployments
        .get(name)
        .catch(async () =>
          hre.network.name === 'localhost'
            ? await hre.artifacts.readArtifact(name)
            : await deployments.getArtifact(name)
        )
        .then((artifact) => ({
          abi: artifact.abi,
          address:
            config?.at ?? ('address' in artifact ? artifact.address : null),
        }))

      if (address == null)
        throw new Error(
          `No deployment exists for ${name}. If expected, supply an address (config.at)`
        )

      let contract = await ethers.getContractAt(abi, address)

      if (config?.from) {
        const signer = Signer.isSigner(config.from)
          ? config.from
          : ethers.provider.getSigner(config.from)
        contract = contract.connect(signer)
      }

      return contract as C
    },

    proxy: {
      initializedVersion: async (proxy: string | Contract): Promise<number> => {
        const address = typeof proxy === 'string' ? proxy : proxy.address
        const isProxy = await ozUpgrades.isTransparentOrUUPSProxy(
          hre.ethers.provider,
          address
        )
        if (!isProxy) throw new Error(`Address ${address} is not a proxy`)
        const storage = await ethers.provider.getStorageAt(address, 0)
        return BigNumber.from(storage).toNumber()
      },
    },
  }

  hre.tokens = {
    async get(nameOrAddress: string): Promise<ERC20> {
      let address: string
      if (ethers.utils.isAddress(nameOrAddress)) {
        address = nameOrAddress
      } else {
        const tokens = await getTokens(hre)
        address = tokens.all[nameOrAddress.toUpperCase()]
        if (!address) throw new Error(`Token ${nameOrAddress} not found`)
      }
      return await ethers.getContractAt('ERC20', address)
    },
  }

  hre.getNamedSigner = async (name: string): Promise<Signer> => {
    const accounts = await hre.getNamedAccounts()
    return ethers.provider.getSigner(accounts[name])
  }

  hre.evm = {
    async setNextBlockTimestamp(timestamp: moment.Moment): Promise<void> {
      await network.provider.send('evm_setNextBlockTimestamp', [
        timestamp.unix(),
      ])
    },

    async advanceTime(
      seconds: BigNumberish | moment.Duration,
      options?: AdvanceTimeOptions
    ): Promise<void> {
      const secs = moment.isDuration(seconds)
        ? seconds
        : moment.duration(BigNumber.from(seconds).toString(), 's')
      if (options?.withoutBlocks) {
        const block = await ethers.provider.getBlock('latest')
        const timestamp = moment(
          secs.add(block.timestamp, 's').asMilliseconds()
        )
        await this.setNextBlockTimestamp(timestamp)
        if (options?.mine) await this.mine()
      } else {
        const secsPerBlock = 15
        const blocks = BigNumber.from(secs.asSeconds())
          .div(secsPerBlock)
          .toNumber()
        await this.advanceBlocks(blocks, secsPerBlock)
      }
    },

    async advanceBlocks(blocks = 1, secsPerBlock = 15): Promise<void> {
      for (let block = 0; block < blocks; block++) {
        await network.provider.send('evm_increaseTime', [secsPerBlock])
        await this.mine()
      }
    },

    async mine(): Promise<void> {
      await network.provider.send('evm_mine')
    },

    async snapshot(): Promise<() => Promise<void>> {
      const id = await network.provider.send('evm_snapshot')
      return async () => {
        await network.provider.send('evm_revert', [id])
      }
    },

    async withBlockScope(blocks: number, fn: () => any): Promise<any> {
      const revert = await this.snapshot()
      await this.advanceBlocks(blocks)
      const result = await fn()
      await revert()
      // eslint-disable-next-line @typescript-eslint/no-unsafe-return
      return result
    },

    async impersonate(address: string): Promise<ImpersonateReturn> {
      await network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [address],
      })
      const signer = ethers.provider.getSigner(address)
      return {
        signer,
        stop: async () => await this.stopImpersonating(address),
      }
    },

    async stopImpersonating(address: string): Promise<void> {
      await network.provider.request({
        method: 'hardhat_stopImpersonatingAccount',
        params: [address],
      })
    },
  }

  hre.toBN = (amount: BigNumberish, decimals?: BigNumberish): BigNumber => {
    if (typeof amount === 'string') {
      return ethers.utils.parseUnits(amount, decimals)
    }

    const num = BigNumber.from(amount)
    if (decimals) {
      return num.mul(BigNumber.from('10').pow(decimals))
    }
    return num
  }

  hre.fromBN = (amount: BigNumberish, decimals?: BigNumberish): BigNumber => {
    const num = BigNumber.from(amount)
    if (decimals) {
      return num.div(BigNumber.from('10').pow(decimals))
    }
    return num
  }

  hre.log = (msg: string, config: LogConfig = {}): void => {
    const { disable = process.env.DISABLE_LOGS === 'true' } = config

    if (disable) return
    const fn = config?.error ? process.stderr : process.stdout
    fn.write(formatMsg(msg, config))
  }

  hre.defender.proposeUpgradeAndCall = async (
    proxyAddress,
    implFactory,
    { title, description, callFn, callArgs, ...opts }
  ): Promise<ProposalResponse> => {
    const newImpl = await hre.upgrades.prepareUpgrade(
      proxyAddress,
      implFactory,
      opts
    )
    const newImplAddr =
      typeof newImpl === 'string'
        ? newImpl
        : await newImpl.wait().then((r) => r.contractAddress)

    const proxyAdmin = await hre.upgrades.admin.getInstance()
    const { protocolAdminSafe } = await hre.getNamedAccounts()

    const admin = getAdminClient(hre)
    return await admin.createProposal({
      contract: {
        address: proxyAdmin.address,
        network: await getNetwork(hre),
        abi: JSON.stringify(
          proxyAdmin.interface.fragments.map((fragment) =>
            JSON.parse(fragment.format('json'))
          )
        ),
      },
      title: title,
      description: description,
      type: 'custom',
      // metadata: {
      //   sendTo: '0xA91382E82fB676d4c935E601305E5253b3829dCD',
      //   sendValue: '10000000000000000',
      //   sendCurrency: {
      //     name: 'Ethereum',
      //     symbol: 'ETH',
      //     decimals: 18,
      //     type: 'native',
      //   },
      // },
      functionInterface: {
        name: 'upgradeAndCall',
        inputs: [
          {
            internalType: 'contract TransparentUpgradeableProxy',
            name: 'proxy',
            type: 'address',
          },
          { internalType: 'address', name: 'implementation', type: 'address' },
          { internalType: 'bytes', name: 'data', type: 'bytes' },
        ],
      },
      functionInputs: [
        proxyAddress,
        newImplAddr,
        implFactory.interface.encodeFunctionData(callFn, callArgs),
      ],
      viaType: 'Gnosis Safe',
      via: protocolAdminSafe,
      // set simulate to true
      // simulate: true,
    })
  }
})

type OZDefenderDeployOpts = (DeployProxyOptions | DeployBeaconOptions) &
  DeployCustomName
async function ozDefenderDeploy(
  hre: HardhatRuntimeEnvironment,
  deployType: 'proxy' | 'beacon',
  contractName: string,
  opts?: OZDefenderDeployOpts
): Promise<Contract>
async function ozDefenderDeploy(
  hre: HardhatRuntimeEnvironment,
  deployType: 'proxy' | 'beacon',
  contractName: string,
  initArgs?: unknown[],
  opts?: DeployProxyOptions
): Promise<Contract>
async function ozDefenderDeploy(
  hre: HardhatRuntimeEnvironment,
  deployType: 'proxy' | 'beacon',
  contractName: string,
  initArgs: unknown[] | OZDefenderDeployOpts = [],
  opts: OZDefenderDeployOpts = {}
): Promise<Contract> {
  const isProxy = deployType === 'proxy'
  const contractTypeStr = isProxy ? 'Proxy' : 'Beacon'

  if (!Array.isArray(initArgs)) {
    // eslint-disable-next-line no-param-reassign
    opts = initArgs
    // eslint-disable-next-line no-param-reassign
    initArgs = []
  }

  const saveName = opts.customName ?? contractName

  hre.log('----------')
  hre.log('')
  hre.log(
    `${chalk.underline('Contract')} (${chalk.italic(
      contractTypeStr
    )}): ${chalk.bold(`${saveName}`)} ${
      saveName !== contractName ? ` (${chalk.italic(`${contractName}`)})` : ''
    }`
  )
  hre.log('')

  let proxy: Contract
  const implFactory = await hre.ethers.getContractFactory(contractName)
  const existingDeployment = await hre.deployments.getOrNull(saveName)
  if (existingDeployment) {
    hre.log(`${chalk.bold.yellow(`Existing ${deployType} deployment found`)}`, {
      indent: 1,
    })

    proxy = await hre.ethers.getContractAt(
      contractName,
      existingDeployment.address
    )
  } else {
    hre.log(`${chalk.bold.green(`Deploying new ${deployType}...`)}`, {
      indent: 1,
    })

    if (isProxy) {
      proxy = await hre.upgrades.deployProxy(implFactory, initArgs, opts)
    } else {
      proxy = await hre.upgrades.deployBeacon(implFactory, opts)
    }
  }

  const proxyLabel = chalk.bold(`${contractTypeStr}: `)
  const implementationLabel = chalk.bold(`Implementation: `)
  const maxLabelLength = Math.max(proxyLabel.length, implementationLabel.length)
  hre.log(proxyLabel, {
    star: false,
    nl: false,
    pad: { start: { length: maxLabelLength, char: ' ' } },
  })
  hre.log(`${proxy.address}`, { star: false })
  await proxy.deployed()

  const implementation = isProxy
    ? await hre.upgrades.erc1967.getImplementationAddress(proxy.address)
    : await hre.upgrades.beacon.getImplementationAddress(proxy.address)
  hre.log(implementationLabel, {
    star: false,
    nl: false,
    pad: { start: { length: maxLabelLength, char: ' ' } },
  })
  hre.log(`${implementation}`, { star: false })

  const abi = implFactory.interface.fragments.map((fragment) =>
    JSON.parse(fragment.format('json'))
  )
  await hre.deployments.save(saveName, {
    address: proxy.address,
    implementation,
    abi,
    transactionHash:
      proxy?.deployTransaction?.hash ?? existingDeployment?.transactionHash,
    receipt:
      (await proxy?.deployTransaction?.wait()) ?? existingDeployment?.receipt,
  })

  hre.log('')
  hre.log('----------')

  return proxy
}
