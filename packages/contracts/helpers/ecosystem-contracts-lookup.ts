




export function get_ecosystem_contract_address(
	networkName: string, contractName: string 
): string {


	if (contractName === "uniswapV3Factory") {


	  let uniswapV3FactoryAddress: string
	  switch (networkName) {  //hre.network.name
	    case 'mainnet':
	    case 'mainnet_live_fork':
	    case 'goerli':
	    case 'arbitrum':
	    case 'optimism':
	    case 'polygon':
	    case 'localhost':
	      uniswapV3FactoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
	      break
	    case 'base':
	      uniswapV3FactoryAddress = '0x33128a8fC17869897dcE68Ed026d694621f6FDfD'
	      break
	    case 'sepolia':
	      uniswapV3FactoryAddress = '0x0227628f3F023bb0B980b67D528571c95c6DaC1c'
	      break
	    case 'katana':
	      uniswapV3FactoryAddress = '0x203e8740894c8955cB8950759876d7E7E45E04c1'
	      break
	    default:
	      throw new Error('No swap factory address found for this network')
	  }

	  return uniswapV3FactoryAddress; 


	}

	 



}