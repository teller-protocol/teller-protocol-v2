// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ILenderCommitmentForwarder_U1 {
    

    struct PoolRouteConfig {
        address pool;
        bool zeroForOne;
        uint32 twapInterval;
        uint256 token0Decimals;
        uint256 token1Decimals;
    } 

}
