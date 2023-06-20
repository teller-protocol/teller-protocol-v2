import { BigNumber as BN } from 'ethers'
import { ethers } from 'hardhat'

export const isInitialized = async (address: string): Promise<boolean> => {
  const storage = await ethers.provider.getStorageAt(address, 0)
  return !BN.from(storage).isZero()
}

export const getProxyImplementation = async (
  proxyAddr: string
): Promise<string> => {
  const storage = await ethers.provider.getStorageAt(
    proxyAddr,
    '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
  )
  return ethers.utils.getAddress(storage)
}
