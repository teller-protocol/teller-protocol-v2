pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT


import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
  
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

 /*

    This ERC20 token keeps track of the last time it was transferred and provides that information

    This can help mitigate sandwich attacking and flash loan attacking if additional external logic is used for that purpose 
   
    Ideally , deploy this as a beacon proxy that is upgradeable 

 */

abstract contract LenderCommitmentGroupSharesIntegrated is
    Initializable, 
    ERC20Upgradeable
{
  
    uint8 private constant DECIMALS  = 18;
   
    mapping(address => uint256) private poolSharesLastTransferredAt;

    event SharesLastTransferredAt(
        address indexed recipient,         
        uint256 transferredAt 
    );

 
    constructor()   {}

    /*
        The two tokens MUST implement IERC20Metadata or else this will fail.

    */
    function __Shares_init(
        address principalTokenAddress,
        address collateralTokenAddress
    ) internal onlyInitializing {

        string memory principalTokenSymbol = IERC20Metadata(principalTokenAddress).symbol();
        string memory collateralTokenSymbol = IERC20Metadata(collateralTokenAddress).symbol();
        
        // Create combined name and symbol
        string memory combinedName = string(abi.encodePacked(
            principalTokenSymbol, "-", collateralTokenSymbol, " shares"
        ));
        string memory combinedSymbol = string(abi.encodePacked(
            principalTokenSymbol, "-", collateralTokenSymbol
        ));
        
        // Initialize with the dynamic name and symbol
        __ERC20_init(combinedName, combinedSymbol);       

    }
  

    function mintShares(address _recipient, uint256 _amount) internal {  // only wrapper contract can call 
        _mint(_recipient, _amount);   //triggers _afterTokenTransfer
    }

    function burnShares(address _burner, uint256 _amount ) internal { // only wrapper contract can call 
        _burn(_burner, _amount);  //triggers _afterTokenTransfer
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }
 

    // this occurs after mint, burn and transfer 
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {

        if (amount > 0) {

            poolSharesLastTransferredAt[from] =  block.timestamp;
            emit SharesLastTransferredAt(from, block.timestamp);

        } 
      
    }

    /*
        Get the last timestamp pool shares have been transferred for this account 
    */
    function getSharesLastTransferredAt(
        address owner        
    )  public view returns (uint256)  {

        return poolSharesLastTransferredAt[owner];
      
    }


     // Storage gap for future upgrades
    uint256[50] private __gap;
    


}



