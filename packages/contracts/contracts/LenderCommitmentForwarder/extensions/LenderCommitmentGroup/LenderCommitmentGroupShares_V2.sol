pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT


import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; 

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
 

 /*

    DEPRECATED 

 */

/*
contract LenderCommitmentGroupShares_V2 is Initializable, ERC20Upgradeable,  OwnableUpgradeable {
  
    uint8 private constant DECIMALS  = 18;

   
    mapping(address => uint256) public poolSharesLastTransferredAt;


    event SharesLastTransferredAt(
        address recipient,
         
        uint256 transferredAt 
    );



    constructor()   {  }



    function initialize( )  external initializer {
 
        __ERC20_init("LenderPoolShares", "LPS");
        __Ownable_init();

    }    


    function mint(address _recipient, uint256 _amount) external onlyOwner {
        _mint(_recipient, _amount);
    }

    function burn(address _burner, uint256 _amount ) external onlyOwner {
 
          
   
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


    function getLastTransferredAt(
        address owner        
    )  external view returns (uint256)  {

        return poolSharesLastTransferredAt[owner];
      
    }





}



*/