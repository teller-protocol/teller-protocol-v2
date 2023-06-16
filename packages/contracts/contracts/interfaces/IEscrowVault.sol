// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IEscrowVault {

    /**
     * @notice Increases the balance of a token for an account
     * @param account The address of the account
     * @param token The address of the token
     * @param amount The amount to increase the balance
     */
    function increaseBalance(
        address account,
        address token,
        uint256 amount 
    ) external;

}
