pragma solidity ^0.8.0;


import {IFlashLoanSimpleReceiver} from '../../interfaces/aave/IFlashLoanSimpleReceiver.sol';
  
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AavePoolMock  {
 

function flashLoanSimple(
     address receiverAddress,
    address asset,
    uint256 amount,
    bytes calldata params,
    uint16 referralCode

) external {

    uint256 balanceBefore = IERC20(asset).balanceOf(address(this));

    IERC20(asset).transfer( receiverAddress, amount );

    uint256 premium = amount /100;
    address initiator = msg.sender;

    bool success = IFlashLoanSimpleReceiver(receiverAddress).executeOperation(
        asset,amount,premium,initiator,params
    );

    //require balance is what it was plus the fee.. 
    uint256 balanceAfter = IERC20(asset).balanceOf(address(this));

    require(balanceAfter >= balanceBefore + premium, "Must repay flash loan");

}


}