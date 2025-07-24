




export function get_ecosystem_contract_address(
	networkName: string, contractName: string 
): string | undefined {


	if (contractName === "uniswapV3Factory") {


	  let uniswapV3FactoryAddress: string | undefined  = undefined 
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
	      return undefined 
	  }

	  return uniswapV3FactoryAddress; 


	}

	if (contractName === "weth9") {


		let weth9Address: string | undefined  = undefined 
		  switch (networkName) {  //hre.network.name
		    case 'mainnet':		   
		    case 'mainnet_live_fork':
		      weth9Address = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'
		      break
		    case 'base':
		      weth9Address = '0x4200000000000000000000000000000000000006'
		      break
		    case 'polygon':
		      weth9Address = '0x7ceb23fd6bc0add59e62ac25578270cff1b9f619'
		      break
		    case 'arbitrum':
		      weth9Address = '0x82af49447d8a07e3bd95bd0d56f35241523fbab1'
		      break
		     case 'optimism':
		      weth9Address = '0x4200000000000000000000000000000000000006'
		      break
		     case 'katana':
		       weth9Address = '0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62'
		       break 
		    default:
		    	return undefined 
		      //throw new Error('No swap factory address found for this network')
		  }

	  return weth9Address; 
	}

	 
	 



}