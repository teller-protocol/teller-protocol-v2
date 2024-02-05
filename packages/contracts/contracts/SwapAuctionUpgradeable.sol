pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

/*
An escrow vault for repayments 
*/

// Contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
    using SafeERC20 for ERC20;

    //account => token => balance
    //mapping(address => mapping(address => uint256)) public balances;

    //mapping(address =>  ProposedSwap) public balances;

    struct ProposedSwap {

        address proposer;
        uint256 amountIn; 
        uint256 amountOut;

        uint256 proposedAt; 

    }

    ProposedSwap public proposedSwap;
    uint256 proposalExpiresAt; 


    address public tokenIn;
    address public tokenOut;

    //uint256 public minimumSwapAuctionAmountOut;

    function __initialize_SwapAuctionUpgradeable (
        address _tokenIn,
        address _tokenOut
    ) internal onlyInitializing {

        tokenIn = _tokenIn;
        tokenOut = _tokenOut; 
        
    }

/*
    function __setMinimumSwapAuctionAmountOut (
        uint256 _minimumAmountOut
    ) internal {

        minimumSwapAuctionAmountOut = _minimumAmountOut;

    }
    */

    function proposeSwapAuction( 
        uint256 _amountIn,
        uint256 _amountOut
     ) external {
        if(  proposedSwap.proposedAt != 0 ){
            
            uint256 newAmountInPerAmountOut = _amountIn * 10**18 / _amountOut;
            uint256 existingAmountInPerAmountOut = proposedSwap.amountIn * 10**18 / proposedSwap.amountOut;
            

             require( 
                newAmountInPerAmountOut >=  (existingAmountInPerAmountOut * 110 / 100 ) , //new proposal must be significantly larger than the last 
               "Invalid amount in for propose swap"    
                           
              ); 

              require(  _amountOut >= proposedSwap.amountOut,
              "Invalid amount out for propose swap"    
               );

        }


        /*
            update minimumSwapAuctionAmountOut
           
        */
        uint256 currentTokenOutBalance = IERC20(tokenOut).balanceOf(address(this));
        // __setMinimumSwapAuctionAmountOut(currentTokenOutBalance);

        require( currentTokenOutBalance > 0 );
 

            //is there a way to restructure this and still avoid griefing? im not sure 
            // if this required == then a grief attack would be to send token dust in to make the tx revert. 
         require( 
            _amountOut = currentTokenOutBalance ,
             "Insufficient amountOut" 
             );


       
        // pull in the new amount in 
        IERC20(tokenIn).transferFrom(msg.sender,address(this),_amountIn);

        if(  proposedSwap.proposer != address(0) ){
            //refund the old proposed swap if it exists, this can never be higher than _amountIn
          IERC20(tokenIn).transfer(proposedSwap.proposer, proposedSwap.amountIn);
        }

        proposedSwap = ProposedSwap({
            proposer: msg.sender,
            amountIn: _amountIn,
            amountOut: _amountOut,
            proposedAt: block.timestamp  

        });
    }

    function performSwap( ) external {
        require( msg.sender == proposedSwap.proposer  );

        require(  proposedSwap.proposedAt > block.timestamp + (60 minutes));

        address recipient = proposedSwap.proposer;
        uint256 amountToSend = proposedSwap.amountOut;



         proposedSwap = ProposedSwap({
            proposer: address(0),
            amountIn: 0,
            amountOut: 0,
            proposedAt: 0
        });


         minimumSwapAuctionAmountOut = 0;

            //do this here to prevent re-entrancy calling
         IERC20(tokenOut).transfer(recipient,amountToSend);

    }





    
    uint256[50] private __gap;

}
