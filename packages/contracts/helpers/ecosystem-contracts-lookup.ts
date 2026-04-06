




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
	    case 'hyperevm':
	     	uniswapV3FactoryAddress = '0xFf7B3e8C00e57ea31477c32A5B52a58Eea47b072'
	     	break
	    case 'bsc':
	      uniswapV3FactoryAddress = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865' // PancakeSwap V3
	      break
	    case 'apechain':
	      uniswapV3FactoryAddress = '0x10aA510d94E094Bd643677bd2964c3EE085Daffc' // Camelot V3 (Algebra)
	      break
	    case 'xdc':
	      uniswapV3FactoryAddress = '0xcb2436774C3e191c85056d248EF4260ce5f27A9D'
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

		      case 'hyperevm':
		      weth9Address = '0x1fbccdc677c10671ee50b46c61f0f7d135112450'
		      break
		    case 'bsc':
		      weth9Address = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c' // WBNB
		      break
		    case 'apechain':
		      weth9Address = '0x48b62137EdfA95a428D35C09E44256a739F6B557' // WAPE
		      break
		    case 'xdc':
		      weth9Address = '0x951857744785e80e2de051c32ee7b25f9c458c42' // WXDC
		      break

		    default:
		    	return undefined 
		      //throw new Error('No swap factory address found for this network')
		  }

	  return weth9Address; 
	}

	if (contractName === "uniswapV3SwapRouter") {

		let swapRouterAddress: string | undefined  = undefined 
		  switch (networkName) {  //hre.network.name
		    case 'mainnet':		   
		    case 'mainnet_live_fork':
		      swapRouterAddress = '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45'
		      break
		    case 'base':
		      swapRouterAddress = '0x2626664c2603336E57B271c5C0b26F421741e481'
		      break
		    case 'polygon':
		      swapRouterAddress = '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45'
		      break
		    case 'arbitrum':
		      swapRouterAddress = '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45'
		      break
		     //case 'optimism':
		   //   swapRouterAddress = '0x0000000000000000000000000000000000000006'
		    //  break
		     case 'katana':
		       swapRouterAddress = '0x4e1d81A3E627b9294532e990109e4c21d217376C'
		       break 

		     case 'hyperevm':
		       swapRouterAddress = '0x1EbDFC75FfE3ba3de61E7138a3E8706aC841Af9B'
		       break
		    case 'bsc':
		      swapRouterAddress = '0x1b81D678ffb9C0263b24A97847620C99d213eB14' // PancakeSwap V3
		      break
		    case 'apechain':
		      swapRouterAddress = '0xC69Dc28924930583024E067b2B3d773018F4EB52' // Camelot V3
		      break
		    case 'xdc':
		      swapRouterAddress = '0xaa52bB8110fE38D0d2d2AF0B85C3A3eE622CA455'
		      break
		    default:
		    	return undefined 
		      //throw new Error('No swap factory address found for this network')
		  }

	  return swapRouterAddress; 


	}

	 
	
	if (contractName === "uniswapV3Quoter") {

			let quoterAddress: string | undefined  = undefined 
			  switch (networkName) {  //hre.network.name
			    case 'mainnet':		   
			    case 'mainnet_live_fork':
			      quoterAddress = '0x5e55c9e631fae526cd4b0526c4818d6e0a9ef0e3'
			      break
			    case 'base':
			      quoterAddress = '0x222ca98f00ed15b1fae10b61c277703a194cf5d2'
			      break
			    case 'polygon':
			      quoterAddress = '0x5e55c9e631fae526cd4b0526c4818d6e0a9ef0e3'
			      break
			    case 'arbitrum':
			      quoterAddress = '0x5e55c9e631fae526cd4b0526c4818d6e0a9ef0e3'
			      break
			  //   case 'optimism':
			  //    quoterAddress = '0x0000000000000000000000000000000000000006'
			  //    break
			     case 'katana':
			       quoterAddress = '0x3C111250572f08493CdC262e210093F92A67DBD9' //'0x92dea23ED1C683940fF1a2f8fE23FE98C5d3041c'
			       break 
			     case 'hyperevm':
			     	quoterAddress = ' ' //'0x239F11a7A3E08f2B8110D4CA9F6B95d4c8865258'
			     	break
			    case 'bsc':
			      quoterAddress = '0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997' // PancakeSwap V3
			      break
			    case 'apechain':
			      quoterAddress = '0x60A186019F81bFD04aFc16c9C01804a04E79e68B' // Camelot V3
			      break
			    case 'xdc':
			      quoterAddress = '0x5911cB3633e764939edc2d92b7e1ad375Bb57649'
			      break
			    default:
			    	return undefined 
			      //throw new Error('No swap factory address found for this network')
			  }

		  return quoterAddress; 


		
	}



}