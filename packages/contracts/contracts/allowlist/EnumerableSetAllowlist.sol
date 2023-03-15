

import "../interfaces/IAllowlistManager.sol";
import "../interfaces/IEnumerableSetAllowlist.sol";

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";


contract EnumerableSetAllowlist is IAllowlistManager,IEnumerableSetAllowlist {
 using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    event UpdatedAllowList(uint256 commitmentId);

    address public immutable authorized;

    mapping(uint256 => EnumerableSetUpgradeable.AddressSet) internal allowList;

    modifier onlyAuthorized(){
        require(msg.sender == authorized,"Must be authorized.");
        _;
    }

    constructor(address _authorized){  
        authorized = _authorized;
    }


    function setAllowlist(
        uint256 _commitmentId,
        address[] calldata _addressList
    ) public onlyAuthorized {
       
        delete allowList[_commitmentId];
        _addToAllowlist(_commitmentId, _addressList);
    }

 
    /**
     * @notice Adds a addresses to the allowlist for a commmitment.
     * @param _commitmentId The id of the commitment that will allow the new borrower
     * @param _addressList the address array that will be allowed to accept loans using the commitment
     */
    function _addToAllowlist(
        uint256 _commitmentId,
        address[] calldata _addressList
    ) internal virtual {
        
        for (uint256 i = 0; i < _addressList.length; i++) {
            allowList[_commitmentId].add(_addressList[i]);
        }
        emit UpdatedAllowList(_commitmentId);
    }


    function addressIsAllowed(uint256 _commitmentId, address _account) public virtual returns (bool) {
        return allowList[_commitmentId].contains(_account);
    }

    function getAllowedAddresses(uint256 _commitmentId)
        public
        view
        returns (address[] memory borrowers_)
    {
        borrowers_ = allowList[_commitmentId].values();
    }

}