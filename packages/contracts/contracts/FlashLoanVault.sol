pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT



/*
 

*/
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


/// @title Callback for IUniswapV3PoolActions#flash
/// @notice Any contract that calls IUniswapV3PoolActions#flash must implement this interface
interface ITellerV2FlashCallback {
    /// @notice Called to `msg.sender` after transferring to the recipient from IUniswapV3Pool#flash.

    /// @dev In the implementation you must repay the pool the tokens sent by flash plus the computed fee amounts.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
   
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#flash call
    function tellerV2FlashCallback(
        uint256 amount, 
        address token,
        bytes calldata data
    ) external;
}

interface IFlashSingleToken {

  function flash(
      uint256 amount,
      address token, 
      bytes calldata data
  ) external ;

}


contract FlashLoanVault is OwnableUpgradeable, IFlashSingleToken { 
    using SafeERC20 for ERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
 
    EnumerableSet.AddressSet internal allowlist;
 

    event Flash(address sender, uint256 amount);


    modifier onlyAllowlisted{

      require( allowlist.contains(msg.sender) );

      _;
    }



    function initialize() public initializer{
      __Ownable_init();
    }



    function addToAllowlist(address guy) external onlyOwner { 
      allowlist.add(guy);
    }

    function removeFromAllowlist(address guy) external onlyOwner { 
       allowlist.remove(guy);
    }


  /*
  Should only be able to be called by an allowlisted contract 
  */
  function flash(
      uint256 amount,
      address token, 
      bytes calldata data
  ) external onlyAllowlisted {
      uint256 balanceBefore = IERC20(token).balanceOf(address(this));  

      if (amount > 0) IERC20(token).transfer(msg.sender, amount);    

      ITellerV2FlashCallback(msg.sender).tellerV2FlashCallback(amount,token,data);

      require(IERC20(token).balanceOf(address(this)) >= balanceBefore);   

      emit Flash(msg.sender, amount);
  }


  function withdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
  }



}