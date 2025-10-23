



//use mul div and make sure we  round the proper way ! 



/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format) 
library FixedPointQ96 {
    uint8 constant RESOLUTION = 96;
    uint256 constant Q96 = 0x1000000000000000000000000;



    // Example: Convert a decimal number (like 0.5) into FixedPoint96 format
    function toFixedPoint96(uint256 numerator, uint256 denominator) public pure returns (uint256) {
        // The number is scaled by Q96 to convert into fixed point format
        return (numerator * FixedPoint96.Q96) / denominator;
    }

    // Example: Multiply two fixed-point numbers
    function multiplyFixedPoint96(uint256 fixedPointA, uint256 fixedPointB) public pure returns (uint256) {
        // Multiply the two fixed-point numbers and scale back by Q96 to maintain precision
        return (fixedPointA * fixedPointB) / FixedPoint96.Q96;
    }

    // Example: Divide two fixed-point numbers
    function divideFixedPoint96(uint256 fixedPointA, uint256 fixedPointB) public pure returns (uint256) {
        // Divide the two fixed-point numbers and scale back by Q96 to maintain precision
        return (fixedPointA * FixedPoint96.Q96) / fixedPointB;
    }


     function fromFixedPoint96(uint256 q96Value) public pure returns (uint256) {
        // To convert from Q96 back to normal (human-readable) value, divide by Q96
        return q96Value / FixedPoint96.Q96;
    }

}
