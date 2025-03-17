pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT


import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; 

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
  

 /*

    This token keeps track of the last time it was transferred and provides that information

    This can help mitigate sandwich attacking and flash loan attacking 
 

    Ideally , deploy this as a beacon proxy that is upgradeable 

 */

abstract contract LenderCommitmentGroupSharesIntegrated is

    Initializable, 
    ERC20Upgradeable
{
  
    uint8 private constant DECIMALS  = 18;

   
    mapping(address => uint256) private poolSharesLastTransferredAt;


    event SharesLastTransferredAt(
        address recipient,
         
        uint256 transferredAt 
    );



    constructor()   {  }


    function __Shares_init( ) internal onlyInitializing {
        __ERC20_init("LenderPoolShares", "LPS");
    }

   

    function mintShares(address _recipient, uint256 _amount) internal {  // only wrapper contract can call 
        _mint(_recipient, _amount);
    }

    function burnShares(address _burner, uint256 _amount ) internal { // only wrapper contract can call 
  
   
        poolSharesLastTransferredAt[_burner] = block.timestamp;        
        emit SharesLastTransferredAt(_burner, block.timestamp);

        _burn(_burner, _amount);

    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }



    // this occurs after mint and transfer 
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
    function getLastTransferredAt(
        address owner        
    )  public view returns (uint256)  {

        return poolSharesLastTransferredAt[owner];
      
    }


     // Storage gap for future upgrades
    uint256[50] private __gap;
    


}



