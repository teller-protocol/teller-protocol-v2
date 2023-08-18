


/*
Admin can add to a mapping of contracts that can be called ... ? 

*/


contract FlashLoanVault {




/*
Should only be able to be called by an allowlisted contract 

*/
 function flash(
    uint256 amount0,
    
    bytes calldata data
) public {
    uint256 balanceBefore = IERC20(token0).balanceOf(address(this));
  //  uint256 balance1Before = IERC20(token1).balanceOf(address(this));

    if (amount0 > 0) IERC20(token0).transfer(msg.sender, amount0);
    //if (amount1 > 0) IERC20(token1).transfer(msg.sender, amount1);

    IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(data);

    require(IERC20(token0).balanceOf(address(this)) >= balance0Before);
   // require(IERC20(token1).balanceOf(address(this)) >= balance1Before);

    emit Flash(msg.sender, amount0);
}




}