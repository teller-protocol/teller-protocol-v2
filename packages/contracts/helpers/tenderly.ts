import axios, { AxiosInstance, AxiosResponse } from 'axios'
import { ethers } from 'ethers'

const defaultConfig = {
  chainId: '1',
  blockNumber: 16322511,
}

const rpcURL = process.env.TENDERLY_RPC_URL
const tenderlyUser = process.env.TENDERLY_USER
const accessKey = process.env.TENDERLY_ACCESS_KEY
const project = process.env.TENDERLY_PROJECT

export const anAxiosOnTenderly = (): AxiosInstance =>
  axios.create({
    baseURL: 'https://api.tenderly.co/api/v1',
    headers: {
      'X-Access-Key': accessKey ?? '',
      'Content-Type': 'application/json',
    },
  })

export const projectBase = `account/${tenderlyUser}/project/${project}`

export const getSimulations = async (): Promise<AxiosResponse> => {
  return await anAxiosOnTenderly().get(`${projectBase}/simulations`)
}

export const addBalance = async (
  address: string,
  amount = '100'
): Promise<null> => {
  const provider = new ethers.providers.JsonRpcProvider(rpcURL ?? undefined)
  await provider.send('tenderly_addBalance', [
    [address],
    ethers.utils.hexValue(ethers.utils.parseEther(amount)),
  ])
  return null
}
