pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestERC1155Token is ERC1155 {
    
    uint256 public _totalSupply;
    constructor(
        string memory _name,
        string memory _symbol        
    ) ERC1155(_name, _symbol) { }

    function mint(address recipient) public returns (uint256) {
        uint256 tokenId = _totalSupply++;
        _mint(recipient, tokenId);
        return tokenId;
    }
}
