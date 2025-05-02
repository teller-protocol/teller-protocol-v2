pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract LenderCommitmentGroupShares is ERC20, Ownable {

    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;


    uint8 private immutable DECIMALS;


    mapping(address => uint256) public poolSharesPreparedToWithdrawForLender;
    mapping(address => uint256) public poolSharesPreparedTimestamp;


       // Using EnumerableSet to track unique holders
    EnumerableSetUpgradeable.AddressSet private holders;

    event SharesPrepared(
        address recipient,
        uint256 sharesAmount,
        uint256 preparedAt

    );



    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol)
        Ownable()
    {
        DECIMALS = _decimals;
    }

    function mint(address _recipient, uint256 _amount) external onlyOwner {
        _mint(_recipient, _amount);
          holders.add(_recipient);
    }

    function burn(address _burner, uint256 _amount, uint256 withdrawDelayTimeSeconds) external onlyOwner {


        //require prepared 
        require(poolSharesPreparedToWithdrawForLender[_burner] >= _amount,"Shares not prepared for withdraw");
        require(poolSharesPreparedTimestamp[_burner] <= block.timestamp - withdrawDelayTimeSeconds,"Shares not prepared for withdraw");
        
 
        //reset prepared   
        poolSharesPreparedToWithdrawForLender[_burner] = 0;
        poolSharesPreparedTimestamp[_burner] =  block.timestamp;
  

        _burn(_burner, _amount);
        _removeHolderIfEmpty(_burner);
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }


    // ---- 

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._afterTokenTransfer(from, to, amount);

        if (amount > 0) {
            poolSharesPreparedToWithdrawForLender[from] = 0;
            poolSharesPreparedTimestamp[from] = block.timestamp;


                 if (from != address(0)) {
                _removeHolderIfEmpty(from);
                }

                if (to != address(0)) {
                    holders.add(to);
                }

        }

       
    }


    // ---- 


      /**
    * @notice Prepares shares for withdrawal, allowing the user to burn them later for principal tokens + accrued interest.
    * @param _amountPoolSharesTokens Amount of pool shares to prepare for withdrawal.
    * @return True if the preparation is successful.
    */
    function prepareSharesForBurn(
         address _recipient,
        uint256 _amountPoolSharesTokens  
    ) external onlyOwner
     returns (bool) {
        
        return _prepareSharesForBurn(_recipient, _amountPoolSharesTokens); 
    }


    /**
    * @notice Internal function to prepare shares for withdrawal using the required delay to mitigate sandwich attacks.
    * @param _recipient Address of the user preparing their shares.
    * @param _amountPoolSharesTokens Amount of pool shares to prepare for withdrawal.
    * @return True if the preparation is successful.
    */

     function _prepareSharesForBurn(
        address _recipient,
        uint256 _amountPoolSharesTokens 
    ) internal returns (bool) {
   
        require(  balanceOf(_recipient) >= _amountPoolSharesTokens  );

        poolSharesPreparedToWithdrawForLender[_recipient] = _amountPoolSharesTokens; 
        poolSharesPreparedTimestamp[_recipient] = block.timestamp; 


        emit SharesPrepared(  
            _recipient,
            _amountPoolSharesTokens,
           block.timestamp

         );

        return true; 
    }

     /**
     * @notice Returns the list of all token holders.
     */
    function getAllHolders() external view returns (address[] memory) {
        return holders.values();
    }

    /**
     * @notice Removes a holder if their balance reaches zero.
     * @param account The address to check and remove.
     */
    function _removeHolderIfEmpty(address account) internal {
        if (balanceOf(account) == 0) {
            holders.remove(account);
        }
    }





}
