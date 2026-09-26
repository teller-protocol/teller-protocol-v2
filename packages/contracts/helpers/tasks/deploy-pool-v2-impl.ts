import fs from 'fs'
import path from 'path'

import {
  AbiCoder,
  Contract,
  formatEther,
  getAddress,
  Interface,
  keccak256,
  toUtf8Bytes,
  ZeroAddress,
  ZeroHash,
} from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Deploys a prebuilt pool implementation from `upgrades/<dir>/` and writes the
 * Safe batches that put it live behind the V2 beacon.
 *
 * Prebuilt rather than compiled here, because the implementation a beacon runs
 * is not necessarily what this checkout would compile. Base's V2 beacon runs a
 * build of e30dbeb5 under solc 0.8.11, and `develop` has moved on from it - a
 * fresh compile would upgrade every V2 pool to code nobody asked for, and would
 * not even fit under the 24,576-byte limit. The directory carries the exact
 * creation bytecode and the standard JSON input it came from, so what ships is
 * what was reviewed.
 *
 * The deployer can do the deploy and lock the implementation, and nothing
 * else. The beacon belongs to the protocol timelock and `setWithdrawDelayTime`
 * is onlyProtocolOwner, so those are written out as Safe Transaction Builder
 * files for the protocol Safe to import: one to schedule the upgrade, one to
 * execute it after the delay and apply the settings that depend on it. Same
 * reasoning as the Hypernative wiring - the deployer is not a Safe owner or
 * delegate, so it has nothing to propose with.
 *
 * Resumable. `--impl` picks up an implementation an earlier run deployed, and
 * each step checks the chain before it acts, so a re-run never deploys twice
 * or re-initializes.
 *
 *   yarn hh deploy-pool-v2-impl --network base \
 *     --dir base_pool_v2_max_withdraw_delay_30d --dry-run true
 */

const TIMELOCK_ABI = [
  'function getMinDelay() view returns (uint256)',
  'function PROPOSER_ROLE() view returns (bytes32)',
  'function EXECUTOR_ROLE() view returns (bytes32)',
  'function hasRole(bytes32 role, address account) view returns (bool)',
  'function hashOperation(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt) view returns (bytes32)',
  'function isOperation(bytes32 id) view returns (bool)',
  'function isOperationReady(bytes32 id) view returns (bool)',
  'function isOperationDone(bytes32 id) view returns (bool)',
  'function schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay)',
  'function execute(address target, uint256 value, bytes payload, bytes32 predecessor, bytes32 salt) payable',
]

const BEACON_ABI = [
  'function implementation() view returns (address)',
  'function owner() view returns (address)',
  'function upgradeTo(address newImplementation)',
]

const IMPL_ABI = [
  'function TELLER_V2() view returns (address)',
  'function SMART_COMMITMENT_FORWARDER() view returns (address)',
  'function UNISWAP_V3_FACTORY() view returns (address)',
  'function UNISWAP_PRICING_HELPER() view returns (address)',
  'function owner() view returns (address)',
  'function transferOwnership(address newOwner)',
]

interface Manifest {
  description: string
  chainId: number
  contractName: string
  sourcePath: string
  compilerVersion: string
  beacon: string
  currentImplementation: string
  timelock: string
  protocolOwner: string
  constructorArgs: Record<string, string>
  expectedImmutables: Record<string, string>
  lockImplementation?: {
    initialize: Record<string, unknown>
    transferOwnershipTo?: string
  }
  afterUpgrade: {
    label: string
    to: string
    signature: string
    args: string[]
    read?: { signature: string; expect: string }
  }[]
}

interface SafeTx {
  to: string
  value: string
  data: string
  contractMethod: null
  contractInputsValues: null
}

const same = (a: string, b: string): boolean =>
  a.toLowerCase() === b.toLowerCase()

const functionName = (signature: string): string =>
  signature.replace(/^function\s+/, '').split('(')[0].trim()

const safeBatch = (
  chainId: number,
  name: string,
  description: string,
  transactions: SafeTx[]
): string =>
  `${JSON.stringify(
    {
      version: '1.0',
      chainId: String(chainId),
      createdAt: Date.now(),
      meta: { name, description, txBuilderVersion: '1.16.5' },
      transactions,
    },
    null,
    2
  )}\n`

/**
 * Explorer verification. Non-fatal: the implementation works whether or not
 * the explorer shows its source, and explorer APIs are the least reliable
 * thing a deploy touches. What it does buy is that the Safe signers can read
 * the code they are about to point every V2 pool at.
 */
const verifyOnExplorer = async (
  chainId: number,
  address: string,
  manifest: Manifest,
  standardJson: string,
  constructorArgs: string
): Promise<void> => {
  const apiKey = process.env.ETHERSCANV2_VERIFY_API_KEY
  if (!apiKey) {
    console.log('  verify     skipped: ETHERSCANV2_VERIFY_API_KEY is not set')
    return
  }
  const api = `https://api.etherscan.io/v2/api?chainid=${chainId}`
  const body = new URLSearchParams({
    apikey: apiKey,
    module: 'contract',
    action: 'verifysourcecode',
    contractaddress: address,
    sourceCode: standardJson,
    codeformat: 'solidity-standard-json-input',
    contractname: `${manifest.sourcePath}:${manifest.contractName}`,
    compilerversion: manifest.compilerVersion,
    // Etherscan's own spelling.
    constructorArguements: constructorArgs.replace(/^0x/, ''),
  })

  try {
    // The explorer indexes a new contract a little after it lands; submitting
    // straight away is answered with "Unable to locate ContractCode".
    let guid = ''
    for (let attempt = 1; attempt <= 6 && guid === ''; attempt++) {
      const res = (await (await fetch(api, { method: 'POST', body })).json()) as {
        status: string
        result: string
      }
      if (res.status === '1') {
        guid = res.result
      } else if (/already verified/i.test(res.result)) {
        console.log('  verify     already verified')
        return
      } else {
        console.log(`  verify     attempt ${attempt}: ${res.result}`)
        await new Promise((r) => setTimeout(r, 10_000))
      }
    }
    if (guid === '') return

    for (let attempt = 1; attempt <= 12; attempt++) {
      await new Promise((r) => setTimeout(r, 5_000))
      const res = (await (
        await fetch(
          `${api}&module=contract&action=checkverifystatus&guid=${guid}&apikey=${apiKey}`
        )
      ).json()) as { status: string; result: string }
      if (/pending/i.test(res.result)) continue
      console.log(`  verify     ${res.result}`)
      return
    }
    console.log('  verify     still pending; check the explorer')
  } catch (err) {
    console.log(
      `  verify     failed (non-fatal): ${err instanceof Error ? err.message : err}`
    )
  }
}

task(
  'deploy-pool-v2-impl',
  'Deploys a prebuilt pool implementation from upgrades/<dir> and writes the Safe batches to put it behind the beacon'
)
  .addParam('dir', 'Directory under upgrades/', undefined, types.string)
  .addOptionalParam(
    'impl',
    'An implementation an earlier run already deployed, to resume from rather than deploy again',
    '',
    types.string
  )
  .addOptionalParam(
    'dryRun',
    'Check everything and print the plan without sending transactions',
    false,
    types.boolean
  )
  .setAction(async (args, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const { ethers, network } = hre
    const dir = path.join(__dirname, '..', '..', 'upgrades', String(args.dir))
    if (!fs.existsSync(path.join(dir, 'manifest.json'))) {
      throw new Error(`No manifest.json in ${dir}.`)
    }

    const manifest = JSON.parse(
      fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8')
    ) as Manifest
    const deployData = fs
      .readFileSync(path.join(dir, 'deploy-tx-data.txt'), 'utf8')
      .trim()
    const constructorArgs = fs
      .readFileSync(path.join(dir, 'constructor-args.txt'), 'utf8')
      .trim()
    const artifact = JSON.parse(
      fs.readFileSync(path.join(dir, `${manifest.contractName}.json`), 'utf8')
    ) as { abi: unknown[]; deployedBytecode: string }
    const expectedRuntimeBytes = (artifact.deployedBytecode.length - 2) / 2

    const chainId = Number((await ethers.provider.getNetwork()).chainId)
    if (chainId !== manifest.chainId) {
      throw new Error(
        `${args.dir} is for chain ${manifest.chainId}; --network ${network.name} is chain ${chainId}.`
      )
    }

    // The deploy data is the reviewed bytecode followed by the constructor
    // args; a mismatch means one of the two files was edited on its own.
    const encodedArgs = AbiCoder.defaultAbiCoder()
      .encode(
        ['address', 'address', 'address', 'address'],
        [
          manifest.constructorArgs.TELLER_V2,
          manifest.constructorArgs.SMART_COMMITMENT_FORWARDER,
          manifest.constructorArgs.UNISWAP_V3_FACTORY,
          manifest.constructorArgs.UNISWAP_PRICING_HELPER,
        ]
      )
      .slice(2)
    if (
      !deployData.endsWith(encodedArgs) ||
      !same(constructorArgs.replace(/^0x/, ''), encodedArgs)
    ) {
      throw new Error(
        'deploy-tx-data.txt / constructor-args.txt do not end in the constructorArgs in manifest.json.'
      )
    }

    const [signer] = await ethers.getSigners()
    const deployer = await signer.getAddress()
    const beacon = new Contract(manifest.beacon, BEACON_ABI, signer)
    const timelock = new Contract(manifest.timelock, TIMELOCK_ABI, signer)
    const tellerV2 = new Contract(
      manifest.constructorArgs.TELLER_V2,
      ['function owner() view returns (address)'],
      signer
    )

    const [liveImpl, beaconOwner, protocolOwner, minDelay] = await Promise.all([
      beacon.implementation() as Promise<string>,
      beacon.owner() as Promise<string>,
      tellerV2.owner() as Promise<string>,
      timelock.getMinDelay() as Promise<bigint>,
    ])

    console.log(`network      ${network.name} (${chainId})`)
    console.log(`upgrade      ${args.dir}`)
    console.log(`             ${manifest.description}`)
    console.log(`deployer     ${deployer}`)
    console.log(`beacon       ${manifest.beacon}`)
    console.log(`  live impl  ${liveImpl}`)
    console.log(`  owner      ${beaconOwner}`)
    console.log(`timelock     ${manifest.timelock} (min delay ${minDelay}s)`)
    console.log(`TellerV2     owner ${protocolOwner}`)

    if (!same(beaconOwner, manifest.timelock)) {
      throw new Error(
        `The beacon is owned by ${beaconOwner}, not the timelock ${manifest.timelock} the batches would go through.`
      )
    }
    if (!same(protocolOwner, manifest.protocolOwner)) {
      throw new Error(
        `TellerV2 is owned by ${protocolOwner}, not ${manifest.protocolOwner}; the post-upgrade calls would revert "OO".`
      )
    }

    const resumeImpl = String(args.impl ?? '').trim()
    if (
      !same(liveImpl, manifest.currentImplementation) &&
      !(resumeImpl !== '' && same(liveImpl, resumeImpl))
    ) {
      throw new Error(
        `The beacon runs ${liveImpl}, not ${manifest.currentImplementation}. Someone upgraded it since this directory was built; rebuild against what is live rather than overwrite it.`
      )
    }

    // The new implementation must be built against the same four contracts
    // the live one points at. Anything else changes more than the one line.
    const live = new Contract(liveImpl, IMPL_ABI, signer)
    for (const [name, want] of Object.entries(manifest.constructorArgs)) {
      const got = (await live.getFunction(name)()) as string
      if (!same(got, want)) {
        throw new Error(
          `Live implementation has ${name} = ${got}; manifest says ${want}.`
        )
      }
    }
    console.log('  live immutables match the manifest')

    const [proposerRole, executorRole] = await Promise.all([
      timelock.PROPOSER_ROLE() as Promise<string>,
      timelock.EXECUTOR_ROLE() as Promise<string>,
    ])
    const [safeProposes, safeExecutes, anyoneExecutes] = await Promise.all([
      timelock.hasRole(proposerRole, manifest.protocolOwner) as Promise<boolean>,
      timelock.hasRole(executorRole, manifest.protocolOwner) as Promise<boolean>,
      timelock.hasRole(executorRole, ZeroAddress) as Promise<boolean>,
    ])
    console.log(
      `  Safe ${manifest.protocolOwner} proposer=${safeProposes} executor=${safeExecutes} (open execution=${anyoneExecutes})`
    )
    if (!safeProposes || !(safeExecutes || anyoneExecutes)) {
      throw new Error(
        `The protocol Safe cannot ${
          safeProposes ? 'execute' : 'schedule'
        } on the timelock, so the batches this writes could not be run by it.`
      )
    }

    const gas = resumeImpl
      ? 0n
      : await ethers.provider.estimateGas({ from: deployer, data: deployData })
    if (!resumeImpl) {
      const fee = await ethers.provider.getFeeData()
      console.log(
        `  deploy gas ~${gas} (~${formatEther(
          gas * (fee.maxFeePerGas ?? fee.gasPrice ?? 0n)
        )} ETH at current fees)`
      )
    }

    if (args.dryRun) {
      console.log('\ndry run: nothing sent')
      return
    }

    // --- deploy -----------------------------------------------------------
    let implAddress: string
    if (resumeImpl) {
      implAddress = getAddress(resumeImpl)
      console.log(`\nresuming    ${implAddress}`)
    } else {
      console.log('\ndeploying...')
      const tx = await signer.sendTransaction({ data: deployData })
      console.log(`  tx         ${tx.hash}`)
      const rcpt = await tx.wait()
      if (!rcpt?.contractAddress) {
        throw new Error(`Deploy ${tx.hash} produced no contract address.`)
      }
      implAddress = getAddress(rcpt.contractAddress)
    }
    console.log(`  NEW_IMPL   ${implAddress}`)

    // --- check what landed ------------------------------------------------
    const code = await ethers.provider.getCode(implAddress)
    const runtimeBytes = (code.length - 2) / 2
    if (runtimeBytes !== expectedRuntimeBytes) {
      throw new Error(
        `${implAddress} has ${runtimeBytes} bytes of code; the reviewed build has ${expectedRuntimeBytes}.`
      )
    }
    const impl = new Contract(
      implAddress,
      [
        ...IMPL_ABI,
        ...Object.keys(manifest.expectedImmutables).map(
          (n) => `function ${n}() view returns (uint256)`
        ),
      ],
      signer
    )
    for (const [name, want] of Object.entries(manifest.constructorArgs)) {
      const got = (await impl.getFunction(name)()) as string
      if (!same(got, want)) {
        throw new Error(`New implementation has ${name} = ${got}, expected ${want}.`)
      }
    }
    for (const [name, want] of Object.entries(manifest.expectedImmutables)) {
      const got = String(await impl.getFunction(name)())
      if (got !== want) {
        throw new Error(`New implementation has ${name} = ${got}, expected ${want}.`)
      }
      console.log(`  ${name} = ${got}`)
    }

    // --- lock the implementation -------------------------------------------
    // Nothing a pool holds is reachable through its implementation's storage,
    // but an uninitialized implementation hands owner() to whoever calls
    // initialize first. Take it, then pass it to the protocol owner.
    if (manifest.lockImplementation) {
      let owner = (await impl.owner()) as string
      if (same(owner, ZeroAddress)) {
        const init = manifest.lockImplementation.initialize
        const poolIface = new Interface(artifact.abi as never)
        const data = poolIface.encodeFunctionData('initialize', [
          [
            init.principalTokenAddress,
            init.collateralTokenAddress,
            init.marketId,
            init.maxLoanDuration,
            init.interestRateLowerBound,
            init.interestRateUpperBound,
            init.liquidityThresholdPercent,
            init.collateralRatio,
          ],
          (init.poolOracleRoutes as Record<string, unknown>[]).map((r) => [
            r.pool,
            r.zeroForOne,
            r.twapInterval,
            r.token0Decimals,
            r.token1Decimals,
          ]),
        ])
        console.log('\ninitializing the implementation...')
        const tx = await signer.sendTransaction({ to: implAddress, data })
        await tx.wait()
        console.log(`  tx         ${tx.hash}`)
        owner = (await impl.owner()) as string
      }
      console.log(`  impl owner ${owner}`)

      const target = manifest.lockImplementation.transferOwnershipTo
      if (target && !same(owner, target)) {
        if (!same(owner, deployer)) {
          throw new Error(
            `The implementation is owned by ${owner}, which is neither the deployer nor ${target}. Someone initialized it first: deploy another rather than put this one behind the beacon.`
          )
        }
        const tx = await impl.transferOwnership(target)
        await tx.wait()
        owner = (await impl.owner()) as string
        console.log(`  -> ${owner} (${tx.hash})`)
      }
    }

    await verifyOnExplorer(
      chainId,
      implAddress,
      manifest,
      fs.readFileSync(path.join(dir, 'standard-json-input.json'), 'utf8'),
      constructorArgs
    )

    // --- Safe batches ------------------------------------------------------
    const upgradeData = beacon.interface.encodeFunctionData('upgradeTo', [
      implAddress,
    ])
    // Deterministic, so a re-run writes the same operation id rather than
    // scheduling a second one.
    const salt = keccak256(toUtf8Bytes(`${args.dir}:${implAddress}`))
    const opId = (await timelock.hashOperation(
      manifest.beacon,
      0,
      upgradeData,
      ZeroHash,
      salt
    )) as string

    const scheduleTx: SafeTx = {
      to: manifest.timelock,
      value: '0',
      data: timelock.interface.encodeFunctionData('schedule', [
        manifest.beacon,
        0,
        upgradeData,
        ZeroHash,
        salt,
        minDelay,
      ]),
      contractMethod: null,
      contractInputsValues: null,
    }
    const executeTxs: SafeTx[] = [
      {
        to: manifest.timelock,
        value: '0',
        data: timelock.interface.encodeFunctionData('execute', [
          manifest.beacon,
          0,
          upgradeData,
          ZeroHash,
          salt,
        ]),
        contractMethod: null,
        contractInputsValues: null,
      },
      ...manifest.afterUpgrade.map((call) => ({
        to: getAddress(call.to),
        value: '0',
        data: new Interface([call.signature]).encodeFunctionData(
          functionName(call.signature),
          call.args
        ),
        contractMethod: null,
        contractInputsValues: null,
      })),
    ]

    const outDir = path.join('deployments', network.name, 'upgrades', String(args.dir))
    fs.mkdirSync(outDir, { recursive: true })
    const files = {
      '1-schedule-safe-batch.json': safeBatch(
        chainId,
        `Schedule: ${args.dir}`,
        `Schedules beacon ${manifest.beacon}.upgradeTo(${implAddress}) on the timelock. Executable ${minDelay}s after this runs.`,
        [scheduleTx]
      ),
      '2-execute-safe-batch.json': safeBatch(
        chainId,
        `Execute: ${args.dir}`,
        `Executes the scheduled upgrade, then: ${manifest.afterUpgrade
          .map((c) => c.label)
          .join('; ')}`,
        executeTxs
      ),
    }
    const receipt = {
      upgrade: args.dir,
      chainId,
      implementation: implAddress,
      beacon: manifest.beacon,
      previousImplementation: manifest.currentImplementation,
      timelock: manifest.timelock,
      timelockOperationId: opId,
      salt,
      minDelaySeconds: String(minDelay),
    }
    fs.writeFileSync(
      path.join(outDir, 'receipt.json'),
      `${JSON.stringify(receipt, null, 2)}\n`
    )
    for (const [name, body] of Object.entries(files)) {
      fs.writeFileSync(path.join(outDir, name), body)
    }

    // Printed in full as well as written: on an ephemeral host the log may be
    // the only copy anyone can reach.
    console.log(`\nreceipt ${JSON.stringify(receipt)}`)
    for (const [name, body] of Object.entries(files)) {
      console.log(`\n----- ${outDir}/${name} -----\n${body}----- end -----`)
    }

    const [scheduled, ready, done] = await Promise.all([
      timelock.isOperation(opId) as Promise<boolean>,
      timelock.isOperationReady(opId) as Promise<boolean>,
      timelock.isOperationDone(opId) as Promise<boolean>,
    ])
    console.log(
      `\ntimelock operation ${opId}: scheduled=${scheduled} ready=${ready} done=${done}`
    )
    console.log(
      [
        '',
        'Next, from the protocol Safe:',
        `  1. import ${outDir}/1-schedule-safe-batch.json and execute it`,
        `  2. after ${minDelay}s, import ${outDir}/2-execute-safe-batch.json and execute it`,
      ].join('\n')
    )
    for (const call of manifest.afterUpgrade) {
      if (!call.read) continue
      const got = String(
        await new Contract(call.to, [call.read.signature], signer).getFunction(
          functionName(call.read.signature)
        )()
      )
      console.log(`  now: ${functionName(call.read.signature)} = ${got} (after step 2: ${call.read.expect})`)
    }
  })
