

pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT



/*


An escrow vault for repayments 


*/


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

// Interfaces
import "./interfaces/IEscrowVault.sol";
import "./interfaces/ITellerV2.sol"; 

contract EscrowVault is
    Initializable,
    OwnableUpgradeable,
  
    IEscrowVault
{

    using SafeERC20 for ERC20;
    ITellerV2 public tellerV2;

    //account => token => balance
    mapping( address => mapping( address => uint256 ))  public balances;

     /* Modifiers */
    modifier onlyTellerV2() {
        require(_msgSender() == address(tellerV2), "Sender not authorized");
        _;
    }
 
    constructor(IMarketRegistry _marketRegistry) {
        marketRegistry = _marketRegistry;
    }

    function initialize( address _tellerV2 ) external initializer {
        tellerV2 = ITellerV2(_tellerV2);
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
        onlyTellerV2
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
