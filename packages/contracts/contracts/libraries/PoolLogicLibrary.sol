
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";


library PoolLogicLibrary {


  uint256 public constant EXCHANGE_RATE_EXPANSION_FACTOR = 1e36;  


   
  


 /**
     * @notice Converts an amount to its underlying value using a given exchange rate with rounding down
     * @dev Uses MathUpgradeable.mulDiv with explicit rounding down to prevent favorable rounding for users
     * @dev This function is used for conversions where rounding down protects the protocol (e.g., calculating shares to mint)
     * @param amount The amount to convert (in the source unit)
     * @param rate The exchange rate to apply, expanded by EXCHANGE_RATE_EXPANSION_FACTOR
     * @return value_ The converted value in the target unit, rounded down
     */
    function valueOfUnderlying(uint256 amount, uint256 rate)
        public
        pure
        returns (uint256 value_)
    {
        if (rate == 0) {
            return 0;
        }

         // value_ = MathUpgradeable.mulDiv(amount ,  EXCHANGE_RATE_EXPANSION_FACTOR   ,  rate );

         value_ = MathUpgradeable.mulDiv(
                amount, 
                EXCHANGE_RATE_EXPANSION_FACTOR, 
                rate,
                MathUpgradeable.Rounding.Down  // Explicitly round down
            );


    }


    /**
     * @notice Converts an amount to its underlying value using a given exchange rate with rounding up
     * @dev Uses MathUpgradeable.mulDiv with explicit rounding up to ensure protocol safety
     * @dev This function is used for conversions where rounding up protects the protocol (e.g., calculating assets needed for shares)
     * @param amount The amount to convert (in the source unit)
     * @param rate The exchange rate to apply, expanded by EXCHANGE_RATE_EXPANSION_FACTOR
     * @return value_ The converted value in the target unit, rounded up
     */
    function valueOfUnderlyingRoundUpwards(uint256 amount, uint256 rate)
        public
        pure
        returns (uint256 value_)
    {
        if (rate == 0) {
            return 0;
        }

     
         value_ = MathUpgradeable.mulDiv(
                amount, 
                EXCHANGE_RATE_EXPANSION_FACTOR, 
                rate,
                MathUpgradeable.Rounding.Up  // Explicitly round down
            ); 

    }


}