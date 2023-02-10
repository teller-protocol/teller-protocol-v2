pragma solidity >=0.8.0 <0.9.0;

/*
See examples 
https://github.com/maple-labs/maple-core-v2/tree/main/scripts


*/

import { Script } from "forge-std/Script.sol";
import { Foo } from "../src/Foo.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployFoo is Script {
    address internal deployer;
    Foo internal foo;

    function setUp() public virtual {
        string memory mnemonic = vm.envString("MNEMONIC");
        (deployer,) = deriveRememberKey(mnemonic, 0);
    }

    function run() public {
        vm.startBroadcast(deployer);
        foo = new Foo();
        vm.stopBroadcast();
    }
}