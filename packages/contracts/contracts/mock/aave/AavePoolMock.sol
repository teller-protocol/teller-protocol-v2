pragma solidity ^0.8.0;


import {IFlashLoanSimpleReceiver} from '../../interfaces/aave/IFlashLoanSimpleReceiver.sol';
 

contract AavePoolMock  {
 

function flashLoanSimple() public {



    bool success = IFlashLoanSimpleReceiver(msg.sender).executeOperation(
        asset,amount,premium,initiator,params
    );

    //require balance is what it was plus the fee.. 

}


}