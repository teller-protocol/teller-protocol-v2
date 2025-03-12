pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

 

 /*

    This token keeps track of the last time it was transferred and provides that information

    This can help mitigate sandwich attacking and flash loan attacking 



    Ideally , deploy this as a beacon proxy that is upgradeable 

 */

contract LenderCommitmentGroupShares_V2 is ERC20, Ownable {
    uint8 private immutable DECIMALS;


   
    mapping(address => uint256) public poolSharesLastTransferredAt;


    event SharesLastTransferredAt(
        address recipient,
         
        uint256 transferredAt 
    );



    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol)
        Ownable()
    {
        DECIMALS = _decimals;
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
