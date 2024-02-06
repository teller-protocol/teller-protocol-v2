pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

/*
An escrow vault for repayments 
*/

// Contracts
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

// Interfaces

/*


This will function quite like a Foundation App auction, except for ERC20 swaps. 


This contract contains a lot of 'Token Out' and it wants to have 'Token In'.  

Therefore, at any time,  




LATER: we can build pools that will passively earn money by executing these ... 


*/

contract SwapAuctionUpgradeable is Initializable  {
    using SafeERC20 for IERC20;

    


    address public tokenIn;
    address public tokenOut;
 

    function __initialize_SwapAuctionUpgradeable (
        address _tokenIn,
        address _tokenOut
    ) internal onlyInitializing {

        tokenIn = _tokenIn;
        tokenOut = _tokenOut; 
        
    }
 
    function performSwap( 
        uint256 _amountIn,
        uint256 _amountOut
     ) external {
            
            uint256 newAmountInPerAmountOut = _amountIn * 10**18 / _amountOut;
             
             
             uint256 uniswapAmountInPerAmountOut = getUniswapPriceRatio();
            

             require( 
                newAmountInPerAmountOut >=  (uniswapAmountInPerAmountOut * 90 / 100 ) , //new proposal must be significantly larger than the last 
               "Insufficient amount in for swap"    
                           
              );  

        
 
       // uint256 currentTokenOutBalance = IERC20(tokenOut).balanceOf(address(this));
       
        // pull in the new amount in 
        IERC20(tokenIn).transferFrom(msg.sender,address(this),_amountIn);

       
        IERC20(tokenOut).transfer( msg.sender, _amountOut);
        
    }

    function getUniswapPriceRatio( ) public view returns (uint256) {
      return 0;
    }





    
    uint256[50] private __gap;

}
