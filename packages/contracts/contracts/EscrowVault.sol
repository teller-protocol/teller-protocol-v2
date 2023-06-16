
pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT



/*


An escrow vault for repayments 


*/

// Contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

// Interfaces
import "./interfaces/IEscrowVault.sol";
 

contract EscrowVault is
    Initializable,
    OwnableUpgradeable,
  
    IEscrowVault
{

    using SafeERC20 for ERC20;
   
    //account => token => balance
    mapping( address => mapping( address => uint256 ))  public balances;

   
 
    constructor( )  { }

    function initialize( address _tellerV2 ) external initializer {
        
         __Ownable_init_unchained();
    }
 

    /**
     * @notice Registers a new active lender for a loan, minting the nft
     * @param account The id for the loan to set.
     * @param token The address of the new active lender.
     */
    function increaseBalance(
        address account,
        address token,
        uint256 amount 
        )
        public
        override
        onlyOwner
    {
        balances[account][token] += amount;         
    }

      /**
     * @notice Registers a new active lender for a loan, minting the nft
     * @param account The id for the loan to set.
     * @param token The address of the new active lender.
     */

    function _decreaseBalance( 
        address account,
        address token,
        uint256 amount 

     ) internal {
        balances[account][token] -= amount;        
     }


     function withdraw( 
        address token, 
        uint256 amount 
    ) external{ 

        address account = msg.sender;
        
        _decreaseBalance(account, token, amount);

        ERC20(token).safeTransfer( account, amount );

    }
 
}