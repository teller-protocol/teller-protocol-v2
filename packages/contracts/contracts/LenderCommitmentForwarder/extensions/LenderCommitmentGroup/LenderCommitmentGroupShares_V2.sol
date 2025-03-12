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

contract LenderCommitmentGroupShares_V2 is Initializable, ERC20Upgradeable,  OwnableUpgradeable {
    //uint8 private immutable DECIMALS;
     uint8 private constant DECIMALS  = 18;

   
    mapping(address => uint256) public poolSharesLastTransferredAt;


    event SharesLastTransferredAt(
        address recipient,
         
        uint256 transferredAt 
    );



    constructor()  
    {
          _disableInitializers();
    }



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


    // ---- 

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


    // ---- 

 




}



/*




TypeError: Derived contract must override function "_msgData". Two or more base classes define function with same name and parameter types.
  --> contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroupShares_V2.sol:22:1:
   |
22 | contract LenderCommitmentGroupShares_V2 is ERC20, OwnableUpgradeable {
   | ^ (Relevant source part starts here and spans across multiple lines).
Note: Definition in "ContextUpgradeable": 
  --> @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol:27:5:
   |
27 |     function _msgData() internal view virtual returns (bytes calldata) {
   |     ^ (Relevant source part starts here and spans across multiple lines).
Note: Definition in "Context": 
  --> @openzeppelin/contracts/utils/Context.sol:21:5:
   |
21 |     function _msgData() internal view virtual returns (bytes calldata) {
   |     ^ (Relevant source part starts here and spans across multiple lines).


TypeError: Derived contract must override function "_msgSender". Two or more base classes define function with same name and parameter types.
  --> contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroupShares_V2.sol:22:1:
   |
22 | contract LenderCommitmentGroupShares_V2 is ERC20, OwnableUpgradeable {
   | ^ (Relevant source part starts here and spans across multiple lines).
Note: Definition in "ContextUpgradeable": 
  --> @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol:23:5:
   |
23 |     function _msgSender() internal view virtual returns (address) {
   |     ^ (Relevant source part starts here and spans across multiple lines).
Note: Definition in "Context": 
  --> @openzeppelin/contracts/utils/Context.sol:17:5:
   |
17 |     function _msgSender() internal view virtual returns (address) {
   |     ^ (Relevant source part starts here and spans across multiple lines).


Error HH600: Compilation failed

For more info go to https://hardhat.org/HH600 or run Hardhat with --show-stack-traces

*/