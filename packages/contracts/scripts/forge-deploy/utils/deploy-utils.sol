pragma solidity >=0.8.0 <0.9.0;

import { Script } from "forge-std/Script.sol";

contract DeployUtils is Script {
    function isContract(address _addr) private returns (bool isContract) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    //build a function that upgrades a proxy to a newly deployed impl !
}
