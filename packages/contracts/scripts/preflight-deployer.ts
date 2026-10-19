/**
 * Pre-deploy check: who is about to deploy, and can they pay for it.
 *
 * Deliberately not the `account` hardhat task. That task prints the deployer's
 * private key to stdout, which is tolerable on a laptop and not tolerable on a
 * CI or Railway job, where stdout is a log store that outlives the run and is
 * readable by everyone with access to the project. Nothing here prints
 * anything that is not already public once the first transaction lands.
 *
 * It also fails on an underfunded deployer rather than letting the run die
 * somewhere in the middle of pass 1 with a gas error and a half-deployed
 * protocol to reason about.
 */
import { ZeroAddress, formatEther, parseEther } from 'ethers'
import hre from 'hardhat'

// Enough for a full two-pass deploy with room to spare; a measured run on an
// Arbitrum Orbit L2 costs well under half of this. Override it for a chain
// whose gas token is not priced like ether.
const MIN_BALANCE = process.env.MIN_DEPLOYER_BALANCE ?? '0.02'

async function main(): Promise<void> {
  const { ethers, network } = hre

  // Throws on a malformed mnemonic, which is the other thing worth catching
  // before a deploy rather than during one.
  const [deployer] = await ethers.getSigners()
  const address = await deployer.getAddress()

  const [balance, nonce] = await Promise.all([
    ethers.provider.getBalance(address),
    ethers.provider.getTransactionCount(address),
  ])

  console.log(`network:  ${network.name} (chainId ${network.config.chainId})`)
  console.log(`deployer: ${address}`)
  console.log(`balance:  ${formatEther(balance)}`)
  console.log(`nonce:    ${nonce}`)

  // The protocol owner is a constant in hardhat.config.ts on most chains, but
  // on some (Rome, where there is no Safe) it comes from the environment, and
  // a forgotten variable falls back to the zero address. Deploying with that
  // would hand the timelock a zero proposer and the protocol to nobody; with
  // the deployer as owner, a burner key would own it. Neither is recoverable.
  if (network.live) {
    const { protocolOwnerSafe } = await hre.getNamedAccounts()
    console.log(`owner:    ${protocolOwnerSafe}`)
    if (protocolOwnerSafe == null || protocolOwnerSafe === ZeroAddress) {
      throw new Error(
        `protocolOwnerSafe is the zero address on ${network.name}. Set the ` +
          `protocol owner for this chain (see namedAccounts in ` +
          `hardhat.config.ts) before deploying.`
      )
    }
    if (protocolOwnerSafe.toLowerCase() === address.toLowerCase()) {
      throw new Error(
        `protocolOwnerSafe on ${network.name} is the deployer ${address}. ` +
          `The protocol owner must be a separate account from the deploy key.`
      )
    }
  }

  const minimum = parseEther(MIN_BALANCE)
  if (balance < minimum) {
    throw new Error(
      `Deployer ${address} holds ${formatEther(balance)} on ${network.name}, ` +
        `under the ${MIN_BALANCE} minimum. Fund it before deploying, or set ` +
        `MIN_DEPLOYER_BALANCE lower if this chain's gas is cheaper than that.`
    )
  }
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : err)
  process.exit(1)
})
