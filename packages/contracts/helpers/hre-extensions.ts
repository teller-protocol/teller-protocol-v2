import '@nomicfoundation/hardhat-ethers'
import {
  AdminClient,
  ProposalResponse
} from '@openzeppelin/defender-admin-client'
import {
  PartialContract,
  ProposalFunctionInputs,
  ProposalStep,
  ProposalTargetFunction
} from '@openzeppelin/defender-admin-client/lib/models/proposal'
import { HardhatDefender as OZHD } from '@openzeppelin/hardhat-defender'
import {
  getAdminClient,
  getNetwork
} from '@openzeppelin/hardhat-defender/dist/utils'
import {
  DeployBeaconOptions,
  DeployProxyOptions
} from '@openzeppelin/hardhat-upgrades/dist/utils'
import { PrepareUpgradeOptions } from '@openzeppelin/hardhat-upgrades/src/utils/options'
import * as ozUpgrades from '@openzeppelin/upgrades-core'
import chalk from 'chalk'
import {
  BaseContract,
  BigNumberish,
  ContractFactory,
  HDNodeWallet,
  Numeric,
  Signer
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
interface DeployExtraOpts {
  customName?: string
  libraries?: { [libraryName: string]: string }
}

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    deployProxy: <C = BaseContract>(
      contractName: string,
      opts?: DeployProxyOptions & DeployProxyInitArgs & DeployExtraOpts
    ) => Promise<C>
    deployBeacon: <C = BaseContract>(
      contractName: string,
      opts?: DeployBeaconOptions & DeployExtraOpts
    ) => Promise<C>
    contracts: ContractsExtension
    tokens: TokensExtension
    evm: EVM
    getNamedSigner: (name: string) => Promise<Signer>
    toBN: (amount: BigNumberish, decimals?: BigNumberish) => bigint
    fromBN: (amount: BigNumberish, decimals?: BigNumberish) => bigint
    log: (msg: string, config?: LogConfig) => void
  }

  interface ProposeProxyUpgradeStep {
    proxy: string | BaseContract
    implFactory: ContractFactory
    opts?: PrepareUpgradeOptions & {
      call?: {
        fn: string
        args: any[]
      }
    }
  }
  interface ProposeBeaconUpgradeStep {
    beacon: string | BaseContract
    implFactory: ContractFactory
    opts?: PrepareUpgradeOptions
  }
  //type ProposeUpgradeStep = ProposeProxyUpgradeStep | ProposeBeaconUpgradeStep

  interface ProposeCallStep {
    contractAddress: string
    contractImplementation: ContractFactory
    callFn: string
    callArgs: any[]
  }

  type ProposalStep =
    | ProposeCallStep
    | ProposeProxyUpgradeStep
    | ProposeBeaconUpgradeStep

  interface HardhatDefender extends OZHD {
    proposeCall: (
      contractAddress: string,
      contractImplementation: ContractFactory,
      callFn: string,
      callArgs: any[],

      title: string,
      description: string
    ) => Promise<ProposalResponse>

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
    proposeBatch: ({
      title,
      description,
      _steps
    }: {
      title: string
      description: string
      _steps: ProposalStep[]
    }) => Promise<ProposalResponse>
    proposeBatchTimelock: ({
      title,
      description,
      _steps,
      useTimelock
    }: {
      title: string
      description: string
      _steps: ProposalStep[]
      useTimelock: boolean
    }) => Promise<{ schedule: ProposalResponse; execute: ProposalResponse }>
  }
}

interface LogConfig extends FormatMsgConfig {
  disable?: boolean
  error?: boolean
}

interface ContractsExtension {
  get: <C extends BaseContract>(
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
    initializedVersion: (proxy: string | BaseContract) => Promise<number>
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
   * @param seconds {Numeric | moment.Duration} Amount of seconds to increase the next block's timestamp by.
   */
  advanceTime: (
    seconds: Numeric | moment.Duration,
    option?: AdvanceTimeOptions
  ) => Promise<void>

  /**
   * Will mine the specified number of blocks locally. This is helpful when functionality
   * requires a certain number of blocks to be processed for values to change.
   * @param blocks {Numeric} Amount of blocks to mine.
   * @param secsPerBlock {number} Determines how many seconds to increase time by for
   *  each block that is mined. Default is 15.
   */
  advanceBlocks: (blocks?: Numeric, secsPerBlock?: number) => Promise<void>

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
  from?: string | HDNodeWallet
  at?: string
}

extendEnvironment((hre) => {
  const { deployments, ethers, network } = hre

  hre.deployProxy = async (contractName, { initArgs, ...opts } = {}) => {
    return await ozDefenderDeploy(hre, 'proxy', contractName, initArgs, opts)
  }

  hre.deployBeacon = async (contractName, opts) => {
    return await ozDefenderDeploy(hre, 'beacon', contractName, opts)
  }

  hre.contracts = {
    async get<C = BaseContract>(
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
            config?.at ?? ('address' in artifact ? artifact.address : null)
        }))

      if (address == null)
        throw new Error(
          `No deployment exists for ${name}. If expected, supply an address (config.at)`
        )

      let signer: Signer | undefined
      if (config?.from) {
        signer =
          typeof config.from === 'string'
            ? await ethers.provider.getSigner(config.from)
            : config.from
      }
      const contract = await ethers.getContractAt(abi, address, signer)

      return contract as C
    },

    proxy: {
      initializedVersion: async (
        proxy: string | BaseContract
      ): Promise<number> => {
        const address =
          typeof proxy === 'string' ? proxy : await proxy.getAddress()
        const isProxy = await ozUpgrades.isTransparentOrUUPSProxy(
          hre.ethers.provider,
          address
        )
        if (!isProxy) throw new Error(`Address ${address} is not a proxy`)
        const storage = await ethers.provider.getStorage(address, 0)
        return Number(storage)
      }
    }
  }

  hre.tokens = {
    async get(nameOrAddress: string): Promise<ERC20> {
      let address: string
      if (ethers.isAddress(nameOrAddress)) {
        address = nameOrAddress
      } else {
        const tokens = await getTokens(hre)
        address = tokens.all[(nameOrAddress as string).toUpperCase()]
        if (!address) throw new Error(`Token ${nameOrAddress} not found`)
      }
      return await ethers.getContractAt('ERC20', address)
    }
  }

  hre.getNamedSigner = async (name: string): Promise<Signer> => {
    const accounts = await hre.getNamedAccounts()
    return await ethers.provider.getSigner(accounts[name])
  }

  hre.evm = {
    async setNextBlockTimestamp(timestamp: moment.Moment): Promise<void> {
      await network.provider.send('evm_setNextBlockTimestamp', [
        timestamp.unix()
      ])
    },

    async advanceTime(
      seconds: Numeric | moment.Duration,
      options?: AdvanceTimeOptions
    ): Promise<void> {
      const secs = moment.isDuration(seconds)
        ? seconds
        : moment.duration(seconds.toString(), 's')
      if (options?.withoutBlocks) {
        const block = await ethers.provider.getBlock('latest')
        if (!block) throw new Error('Could not get latest block')

        const timestamp = moment(
          secs.add(block.timestamp, 's').asMilliseconds()
        )
        await this.setNextBlockTimestamp(timestamp)
        if (options?.mine) await this.mine()
      } else {
        const secsPerBlock = 15
        const blocks = BigInt(secs.asSeconds()) / BigInt(secsPerBlock)
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
        params: [address]
      })
      const signer = await ethers.provider.getSigner(address)
      return {
        signer,
        stop: async () => await this.stopImpersonating(address)
      }
    },

    async stopImpersonating(address: string): Promise<void> {
      await network.provider.request({
        method: 'hardhat_stopImpersonatingAccount',
        params: [address]
      })
    }
  }

  hre.toBN = (amount: BigNumberish, decimals?: BigNumberish): bigint => {
    if (typeof amount === 'string') {
      return ethers.parseUnits(amount, decimals)
    }

    const num = BigInt(amount)
    if (decimals) {
      return num * 10n ** BigInt(decimals)
    }
    return num
  }

  hre.fromBN = (amount: BigNumberish, decimals?: BigNumberish): bigint => {
    const num = BigInt(amount)
    if (decimals) {
      return num / 10n ** BigInt(decimals)
    }
    return num
  }

  hre.log = (msg: string, config: LogConfig = {}): void => {
    const { disable = process.env.DISABLE_LOGS === 'true' } = config

    if (disable) return
    const fn = config?.error ? process.stderr : process.stdout
    fn.write(formatMsg(msg, config))
  }

  hre.defender.proposeCall = async (
    contractAddress,
    contractImplementation,
    callFn,
    callArgs,
    title,
    description
  ): Promise<ProposalResponse> => {
    let functionInputs = JSON.parse(
      JSON.stringify(
        contractImplementation.interface.getFunction(callFn)?.inputs
      )
    )

    if (typeof functionInputs == 'undefined') {
      throw new Error('Function inputs undefined')
    }

    const admin = getAdminClient(hre)
    const { protocolOwnerSafe } = await hre.getNamedAccounts()

    return await admin.createProposal({
      contract: {
        address: contractAddress,
        network: await getNetwork(hre),
        abi: JSON.stringify(
          contractImplementation.interface.fragments.map((fragment) =>
            JSON.parse(fragment.format('json'))
          )
        )
      },
      title: title,
      description: description,
      type: 'custom',

      functionInterface: {
        name: callFn,
        inputs: functionInputs
      },
      functionInputs: callArgs,
      viaType: 'Gnosis Safe',
      via: protocolOwnerSafe
      // set simulate to true
      // simulate: true,
    })
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
        : await newImpl.wait(1).then((r) => {
            if (!r?.contractAddress) throw new Error('No contract address')
            return r.contractAddress
          })

    await updateDeploymentAbi({
      hre,
      address: proxyAddress,
      abi: JSON.parse(implFactory.interface.formatJson())
    })

    const proxyAdmin = await hre.upgrades.admin.getInstance()
    const { protocolOwnerSafe } = await hre.getNamedAccounts()

    const admin = getAdminClient(hre)
    return await admin.createProposal({
      contract: {
        address: await proxyAdmin.getAddress(),
        network: await getNetwork(hre),
        abi: JSON.stringify(
          proxyAdmin.interface.fragments.map((fragment) =>
            JSON.parse(fragment.format('json'))
          )
        )
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
            name: 'proxy',
            type: 'address'
          },
          { name: 'implementation', type: 'address' },
          { name: 'data', type: 'bytes' }
        ]
      },
      functionInputs: [
        proxyAddress,
        newImplAddr,
        implFactory.interface.encodeFunctionData(callFn, callArgs)
      ],
      viaType: 'Gnosis Safe',
      via: protocolOwnerSafe
      // set simulate to true
      // simulate: true,
    })
  }

  /*
  hre.defender.proposeBatchUpgrade = async (
    title,
    description,
    _steps
  ): Promise<ProposalResponse> => {
    const network = await getNetwork(hre)
    const proxyAdmin = await hre.upgrades.admin.getInstance()

    const { protocolOwnerSafe } = await hre.getNamedAccounts()

    const steps = Array.isArray(_steps) ? _steps : [_steps]
    const contracts: PartialContract[] = []
    const proposalSteps: ProposalStep[] = []
    for (const step of steps) {
      let toContractAddress: string
      let refAddress: string
      let call: { fn: string; args: any[] } | undefined
      if ('proxy' in step) {
        refAddress =
          typeof step.proxy === 'string'
            ? step.proxy
            : await step.proxy.getAddress()
        call = step.opts?.call
      } else {
        refAddress =
          typeof step.beacon === 'string'
            ? step.beacon
            : await step.beacon.getAddress()
      }
      const newImpl = await hre.upgrades.prepareUpgrade(
        refAddress,
        step.implFactory,
        step.opts
      )
      const newImplAddr =
        typeof newImpl === 'string'
          ? newImpl
          : await newImpl.wait(1).then((r) => {
              if (!r?.contractAddress) throw new Error('No contract address')
              return r.contractAddress
            })

      let targetFunction: ProposalTargetFunction
      let functionInputs: ProposalFunctionInputs
      if ('proxy' in step) {
        toContractAddress = await proxyAdmin.getAddress()

        if (call) {
          targetFunction = {
            name: 'upgradeAndCall',
            inputs: [
              {
                name: 'proxy',
                type: 'address'
              },
              {
                name: 'implementation',
                type: 'address'
              },
              { name: 'data', type: 'bytes' }
            ]
          }
          functionInputs = [
            refAddress,
            newImplAddr,
            step.implFactory.interface.encodeFunctionData(call.fn, call.args)
          ]
        } else {
          targetFunction = {
            name: 'upgrade',
            inputs: [
              {
                name: 'proxy',
                type: 'address'
              },
              {
                name: 'implementation',
                type: 'address'
              }
            ]
          }
          functionInputs = [refAddress, newImplAddr]
        }
      } else {
        toContractAddress = refAddress
        targetFunction = {
          name: 'upgradeTo',
          inputs: [
            {
              name: 'newImplementation',
              type: 'address'
            }
          ]
        }
        functionInputs = [newImplAddr]
      }

      contracts.push({
        address: toContractAddress,
        network
      })
      proposalSteps.push({
        contractId: `${network}-${toContractAddress}`,
        type: 'custom',
        targetFunction,
        functionInputs
      })
    }

    const admin = getAdminClient(hre)
    return await admin.createProposal({
      contract: contracts,
      title: title,
      description: description,
      type: 'batch',
      viaType: 'Gnosis Safe',
      via: protocolOwnerSafe,
      metadata: {},
      steps: proposalSteps
    })
  }
*/

  /*

  Refactor this to allow for passing in either  

  upgradeAndCall
  call 

  */
  hre.defender.proposeBatchTimelock = async ({
    title,
    description,
    _steps
  }: {
    title: string
    description: string
    _steps: ProposalStep[]
  }): Promise<{ schedule: ProposalResponse; execute: ProposalResponse }> => {
    const network = await getNetwork(hre)
    const proxyAdmin = await hre.upgrades.admin.getInstance()

    const { protocolOwnerSafe, protocolTimelock } = await hre.getNamedAccounts()

    //build the timelock batch args from the steps
    const timelockBatchArgs = {
      targets: new Array<string>(),
      values: new Array<string>(),
      payloads: new Array<string>(),
      predecessor: ethers.encodeBytes32String(''),
      salt: ethers.encodeBytes32String(''),
      delay: moment.duration(3, 'minutes').asSeconds().toString()
    }

    const steps = Array.isArray(_steps) ? _steps : [_steps]
    for (const step of steps) {
      //figure out what TYPE of step it is

      let stepType = getStepType(step)

      switch (stepType) {
        case 'call':
          addBatchArgsForCall(step, timelockBatchArgs)
          break
        case 'upgradeProxy':
          addBatchArgsForUpgradeProxy(step, timelockBatchArgs)
          break
        case 'upgradeBeacon':
          addBatchArgsForUpgradeBeacon(step, timelockBatchArgs)
          break
        default:
          throw new Error('Invalid step type - cannot add batch args')
      }

      //remove the below

      let refAddress: string
      let call: { fn: string; args: any[] } | undefined
      if ('proxy' in step) {
        refAddress =
          typeof step.proxy === 'string'
            ? step.proxy
            : await step.proxy.getAddress()
        call = step.opts?.call
      } else {
        refAddress =
          typeof step.beacon === 'string'
            ? step.beacon
            : await step.beacon.getAddress()
      }

      const newImpl = await hre.upgrades.prepareUpgrade(
        refAddress,
        step.implFactory,
        step.opts
      )
      const newImplAddr =
        typeof newImpl === 'string'
          ? newImpl
          : await newImpl.wait(1).then((r) => {
              if (!r?.contractAddress) throw new Error('No contract address')
              return r.contractAddress
            })

      await updateDeploymentAbi({
        hre,
        address: refAddress,
        abi: JSON.parse(step.implFactory.interface.formatJson())
      })

      //produce the timelock batch args
      timelockBatchArgs.values.push('0')
      if ('proxy' in step) {
        timelockBatchArgs.targets.push(await proxyAdmin.getAddress())

        if (call) {
          timelockBatchArgs.payloads.push(
            proxyAdmin.interface.encodeFunctionData('upgradeAndCall', [
              refAddress,
              newImplAddr,
              step.implFactory.interface.encodeFunctionData(call.fn, call.args)
            ])
          )
        } else {
          timelockBatchArgs.payloads.push(
            proxyAdmin.interface.encodeFunctionData('upgrade', [
              refAddress,
              newImplAddr
            ])
          )
        }
      } else {
        timelockBatchArgs.targets.push(refAddress)

        const iface = new ethers.Interface([
          ethers.FunctionFragment.from({
            inputs: [
              {
                name: 'newImplementation',
                type: 'address'
              }
            ],
            name: 'upgradeTo',
            stateMutability: 'nonpayable',
            type: 'function'
          })
        ])
        timelockBatchArgs.payloads.push(
          iface.encodeFunctionData('upgradeTo', [newImplAddr])
        )
      }
    }

    const admin = getAdminClient(hre)
    return createScheduledBatchProposal({
      title,
      description,
      network,
      admin,
      protocolOwnerSafe,
      protocolTimelock,
      timelockBatchArgs
    })
  }
})

const getStepType = (step: ProposalStep): string => {
  if (step.hasOwnProperty('callFn')) {
    return 'call'
  } else if (step.hasOwnProperty('proxy')) {
    return 'upgradeProxy'
  } else if (step.hasOwnProperty('beacon')) {
    return 'upgradeBeacon'
  } else {
    throw new Error('invalid step - cannot ascertain step type')
  }
}

interface TimelockBatchArgs {
  targets: string[]
  values: string[]
  payloads: string[]
  predecessor: string
  salt: string
  delay: string
}

const createScheduledBatchProposal = async ({
  title,
  description,
  network,
  admin,
  protocolOwnerSafe,
  protocolTimelock,
  timelockBatchArgs
}: {
  title: string
  description: string
  network: any //OZ network
  admin: AdminClient
  protocolOwnerSafe: string
  protocolTimelock: string
  timelockBatchArgs: TimelockBatchArgs
}) => {
  return {
    schedule: await admin.createProposal({
      title: `${title} (Schedule Timelock)`,
      description: description,
      type: 'custom',
      viaType: 'Gnosis Safe',
      via: protocolOwnerSafe,
      contract: {
        name: 'TellerV2 Protocol Timelock',
        network,
        address: protocolTimelock
      },
      functionInterface: {
        name: 'scheduleBatch',
        inputs: [
          { name: 'targets', type: 'address[]' },
          { name: 'values', type: 'uint256[]' },
          { name: 'payloads', type: 'bytes[]' },
          { name: 'predecessor', type: 'bytes32' },
          { name: 'salt', type: 'bytes32' },
          { name: 'delay', type: 'uint256' }
        ]
      },
      functionInputs: [
        timelockBatchArgs.targets,
        timelockBatchArgs.values,
        timelockBatchArgs.payloads,
        timelockBatchArgs.predecessor,
        timelockBatchArgs.salt,
        timelockBatchArgs.delay
      ]
    }),
    execute: await admin.createProposal({
      title: `${title} (Execute Timelock)`,
      description: description,
      type: 'custom',
      viaType: 'Gnosis Safe',
      via: protocolOwnerSafe,
      contract: {
        name: 'TellerV2 Protocol Timelock',
        network,
        address: protocolTimelock
      },
      functionInterface: {
        name: 'executeBatch',
        inputs: [
          { name: 'targets', type: 'address[]' },
          { name: 'values', type: 'uint256[]' },
          { name: 'payloads', type: 'bytes[]' },
          { name: 'predecessor', type: 'bytes32' },
          { name: 'salt', type: 'bytes32' }
        ]
      },
      functionInputs: [
        timelockBatchArgs.targets,
        timelockBatchArgs.values,
        timelockBatchArgs.payloads,
        timelockBatchArgs.predecessor,
        timelockBatchArgs.salt
      ]
    })
  }
}

type OZDefenderDeployOpts = (DeployProxyOptions | DeployBeaconOptions) &
  DeployExtraOpts

async function ozDefenderDeploy<C = BaseContract>(
  hre: HardhatRuntimeEnvironment,
  deployType: 'proxy' | 'beacon',
  contractName: string,
  opts?: OZDefenderDeployOpts
): Promise<C>
async function ozDefenderDeploy<C = BaseContract>(
  hre: HardhatRuntimeEnvironment,
  deployType: 'proxy' | 'beacon',
  contractName: string,
  initArgs?: unknown[],
  opts?: DeployProxyOptions
): Promise<C>
async function ozDefenderDeploy<C = BaseContract>(
  hre: HardhatRuntimeEnvironment,
  deployType: 'proxy' | 'beacon',
  contractName: string,
  initArgs: unknown[] | OZDefenderDeployOpts = [],
  opts: OZDefenderDeployOpts = {}
): Promise<C> {
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

  let proxy: BaseContract
  const implFactory = await hre.ethers.getContractFactory(contractName, {
    libraries: opts.libraries
  })
  const existingDeployment = await hre.deployments.getOrNull(saveName)
  if (existingDeployment) {
    hre.log(`${chalk.bold.yellow(`Existing ${deployType} deployment found`)}`, {
      indent: 1
    })

    proxy = await hre.ethers.getContractAt(
      contractName,
      existingDeployment.address
    )
  } else {
    hre.log(`${chalk.bold.green(`Deploying new ${deployType}...`)}`, {
      indent: 1
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
    pad: { start: { length: maxLabelLength, char: ' ' } }
  })
  hre.log(`${await proxy.getAddress()}`, { star: false })
  await proxy.waitForDeployment()
  const proxyAddress = await proxy.getAddress()
  const implementation = isProxy
    ? await hre.upgrades.erc1967.getImplementationAddress(proxyAddress)
    : await hre.upgrades.beacon.getImplementationAddress(proxyAddress)
  hre.log(implementationLabel, {
    star: false,
    nl: false,
    pad: { start: { length: maxLabelLength, char: ' ' } }
  })
  hre.log(`${implementation}`, { star: false })

  const abi = JSON.parse(implFactory.interface.formatJson())
  const deployTx = proxy.deploymentTransaction()
  const transactionHash = deployTx?.hash ?? existingDeployment?.transactionHash
  const receipt = Object.assign({}, deployTx, existingDeployment?.receipt)
  await hre.deployments.save(saveName, {
    address: proxyAddress,
    implementation,
    abi,
    transactionHash,
    receipt
  })

  hre.log('')
  hre.log('----------')

  return proxy as C
}

async function updateDeploymentAbi({
  hre,
  address,
  abi
}: {
  hre: HardhatRuntimeEnvironment
  address: string
  abi: any[]
}): Promise<void> {
  const deployments = await hre.deployments.all()
  for (const [contractName, deployment] of Object.entries(deployments)) {
    if (deployment.address === address) {
      await hre.deployments.save(contractName, {
        ...deployment,
        abi
      })
    }
  }
}
