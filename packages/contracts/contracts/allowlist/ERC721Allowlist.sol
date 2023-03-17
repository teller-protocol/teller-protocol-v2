
pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT
import "../interfaces/allowlist/IAllowlistManager.sol";
 
import "../interfaces/allowlist/IERC721Allowlist.sol";

 import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

contract ERC721Allowlist is IAllowlistManager,IERC721Allowlist {
 
    event UpdatedAllowList(uint256 commitmentId);

     
    IERC721Upgradeable public immutable accessToken; //IERC721

 

    constructor(address _accessToken){  
        accessToken = IERC721Upgradeable(_accessToken);
    }

    function addressIsAllowed(uint256 _commitmentId, address _account) public virtual returns (bool) {
        return accessToken.balanceOf(_account) >= 1;
    }

    /*
    function getAllowedAddresses(uint256 _commitmentId)
        public
        view
        returns (address[] memory borrowers_)
    {
        borrowers_ = allowList[_commitmentId].values();
    }*/

}