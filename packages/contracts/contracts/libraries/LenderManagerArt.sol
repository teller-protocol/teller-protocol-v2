/**
 *Submitted for verification at Etherscan.io on 2023-06-21
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;


import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import { Collateral, CollateralType } from "../interfaces/escrow/ICollateralEscrowV1.sol";
 

//must use this custom interface since the OZ one doesnt support decimals
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

library LenderManagerArt {
 
 using Strings for uint256;
using Strings for uint32;
using Strings for uint16;


bytes constant _bg_defs_filter = abi.encodePacked (


    "<filter id='f1'>",
      "<feImage result='p0' xlink:href='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nMjkwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI5MCA1MDAnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PHJlY3Qgd2lkdGg9JzI5MHB4JyBoZWlnaHQ9JzUwMHB4JyBmaWxsPScjMEQyQjI4Jy8+PC9zdmc+' />",
      "<feImage result='p1' xlink:href='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nMjkwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI5MCA1MDAnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PGNpcmNsZSBjeD0nMTknIGN5PScyNzEnIHI9JzEyMHB4JyBmaWxsPScjMjdFNkUyJy8+PC9zdmc+' />",
      "<feImage result='p2' xlink:href='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nMjkwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI5MCA1MDAnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PGNpcmNsZSBjeD0nMTA0JyBjeT0nNDYyJyByPScxMjBweCcgZmlsbD0nIzAwQzVDMScvPjwvc3ZnPg==' />",
      "<feImage result='p3' xlink:href='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nMjkwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI5MCA1MDAnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PGNpcmNsZSBjeD0nMjU4JyBjeT0nNDQzJyByPScxMDBweCcgZmlsbD0nI0EzREZFMCcvPjwvc3ZnPg==' />",
      "<feBlend mode='overlay' in='p0' in2='p1' />",
      "<feBlend mode='exclusion' in2='p2' />",
      "<feBlend mode='overlay' in2='p3' result='blendOut' />"
      "<feGaussianBlur in='blendOut' stdDeviation='42' />",
    "</filter>"

);
 

bytes constant _bg_defs_clip_path = abi.encodePacked (


     "<clipPath id='corners'>",
      "<rect width='290' height='500' rx='6' ry='6' />",
    "</clipPath>",
    
    "<path id='minimap' d='M234 444C234 457.949 242.21 463 253 463' />",
    "<filter id='top-region-blur'>",
      "<feGaussianBlur in='SourceGraphic' stdDeviation='24' />",
    "</filter>",
    "<linearGradient id='grad-up' x1='1' x2='0' y1='1' y2='0'>",
      "<stop offset='0.0' stop-color='white' stop-opacity='1' />",
      "<stop offset='.9' stop-color='white' stop-opacity='0' />",
    "</linearGradient>",
    "<linearGradient id='grad-down' x1='0' x2='1' y1='0' y2='1'>",
      "<stop offset='0.0' stop-color='white' stop-opacity='1' />",
      "<stop offset='0.9' stop-color='white' stop-opacity='0' />",
    "</linearGradient>"

);
 

bytes constant _bg_defs_mask = abi.encodePacked (
  "<mask id='fade-up' maskContentUnits='objectBoundingBox'>",
      "<rect width='1' height='1' fill='url(#grad-up)' />",
    "</mask>",
    "<mask id='fade-down' maskContentUnits='objectBoundingBox'>",
      "<rect width='1' height='1' fill='url(#grad-down)' />",
    "</mask>",
    "<mask id='none' maskContentUnits='objectBoundingBox'>",
      "<rect width='1' height='1' fill='white' />",
    "</mask>",

    "<linearGradient id='grad-symbol'>",
      "<stop offset='0.7' stop-color='white' stop-opacity='1' />",
      "<stop offset='.95' stop-color='white' stop-opacity='0' />",
    "</linearGradient>",
    "<mask id='fade-symbol' maskContentUnits='userSpaceOnUse'>",
      "<rect width='290px' height='200px' fill='url(#grad-symbol)' />",
    "</mask>"
);

bytes constant _bg_defs =  abi.encodePacked(
    "<defs>",

  
    _bg_defs_filter,

    _bg_defs_clip_path,

    _bg_defs_mask,
   
  


"</defs>"

);


bytes constant _clip_path_corners = abi.encodePacked(  

     "<g clip-path='url(#corners)'>",
    "<rect fill='83843f' x='0px' y='0px' width='290px' height='500px' />",
    "<rect style='filter: url(#f1)' x='0px' y='0px' width='290px' height='500px' />",
    "<g style='filter:url(#top-region-blur); transform:scale(1.5); transform-origin:center top;'>",
    "<rect fill='none' x='0px' y='0px' width='290px' height='500px'/>",
    "<ellipse cx='50%' cy='0px' rx='180px' ry='120px' fill='#000' opacity='0.85'/>",
    "</g>",
    "<rect x='0' y='0' width='290' height='500' rx='0' ry='0' fill='rgba(0,0,0,0)' stroke='rgba(255,255,255,0.2)'/>",
    "</g>"


);

 

bytes constant _teller_logo_path_1 = abi.encodePacked( 
"<path class='st0' d='M151.4,221.5l6.6,15.1l-2.5,4.2L124,226.5l0.8-11.4l3.1-3.9M130.4,182.3l15,28.8l8.6-6.7L130.4,182.3zM145.5,211.1l-16.6-6.7l1.6-22.1l-3.3,3.3l-1.3,22.4l16.7,7.8L145.5,211.1zM128.8,204.4l-3,3.5M142.5,215.7l11.5-11.3'/>",
"<path class='st0' d='M128,211.1l23.5,10.4l11.1-9.5l11.3,11l-15.7,13.7L127.5,223L128,211.1z'/>",
"<path class='st1' d='M156.2,239.7l-31.3-14.2l0.8-11.5'/>",
"<path class='st1' d='M156.8,238.7l-31.1-14l0.7-11.6'/>",
"<path class='st1' d='M157.4,237.6l-30.9-13.8l0.7-11.7'/>",
"<path class='st0' d='M127.3,222.9l-3.3,3.5M155.5,240.8l18.3-17.8M126.5,231l37.4,16.4l18.4-17.2l11.7,11.2c0,0-13.6,1.5-20.1,17.9c0,0-0.8,2.3-2.6,2.4s-4.7-1.7-6-2.6s-20.4-13.8-39.1-16.8L126.5,231L126.5,231z'/>",
"<path class='st0' d='M126.5,231l-3.2,3.1l-0.8,12.5c0,0,16.3,2.3,34.6,13.4c1.4,0.9,2.8,1.9,4.1,2.9c2.1,1.7,6.2,4.3,8.4,1.9l3.3-4M126.2,242.3l-3.7,4.3M164,247.3l7.4,14.3M175.8,255.3c0,0,5.6-8,14.8-9.4l3.4-4.5'/>",
"<path class='st1' d='M175.8,255.3c4.6-8.4,14-11.9,17.1-12.4'/>"

);


bytes constant _teller_logo_path_2 = abi.encodePacked( 

"<path class='st1' d='M175.8,255.3c2.3-4.2,9.8-10,15.9-10.9M125.9,231.6l-0.4,11.5c15,2.4,33.6,13.1,38.2,16.1c1.3,0.9,3.9,2.3,5.6,2.7c1,0.2,2.2,0.5,3-0.3'/>",
"<path class='st1' d='M125.3,232.2l-0.5,11.8c11.3,1.8,29.3,10.3,37.3,15.4c1.4,0.9,3.7,2.2,5.2,2.7c1.3,0.5,3.2,1.5,4.4,0.2'/>",
"<path class='st1' d='M124.6,232.8l-0.6,12c7.5,1.2,25,7.6,36.4,14.7c1.4,0.9,3.4,2,4.9,2.8c1.6,0.8,4.2,2.4,5.7,0.8'/>",
"<path class='st1' d='M124,233.5l-0.7,12.2c3.8,0.6,20.7,5,35.5,14.1c1.4,0.9,3.1,1.9,4.5,2.8c1.9,1.2,5.2,3.4,7.1,1.3M129.7,183l-1.5,22.2l16.6,6.9'/>",
"<path class='st1' d='M129.1,183.6l-1.5,22.2l16.7,7.1'/>",
"<path class='st1' d='M128.4,184.3l-1.4,22.3l16.7,7.3'/>",
"<path class='st1' d='M127.8,184.9l-1.4,22.3l16.7,7.6M143.4,214.4l8.3-8.1M144.1,213l4.6-4.3M156.8,238.7l13.2-12.2'/>",
"<ellipse transform='matrix(0.6384 -0.7697 0.7697 0.6384 -121.0959 193.8277)' class='st2' cx='145.7' cy='225.8' rx='57.9' ry='97.9'/>",
"<ellipse transform='matrix(0.6384 -0.7697 0.7697 0.6384 -118.098 194.5624)' class='st2' cx='148' cy='223' rx='61.5' ry='105.9'/>",
"<path class='st2' d='M62.9,160.5l-7.2,11.2c-16.1,27.3,3.1,75,45.6,110.3c30.3,25.1,64.6,37.4,90.5,34.9c14.1-1.4,26.7-9.1,34.5-20.9l3.7-5.8'/>"


    
);

bytes constant _teller_logo = abi.encodePacked( 


"<svg id='Layer_2' xmlns='http://www.w3.org/2000/svg' viewBox='-5 130 300 236.73'>",
  "<style type='text/css'>",
  ".st0{fill:none;stroke:#FFFFFF;stroke-width:0.3021;stroke-linejoin:round;stroke-miterlimit:1.2083;}",
  ".st1{fill:none;stroke:#FFFFFF;stroke-width:0.151;stroke-linejoin:round;stroke-miterlimit:1.2083;}",
  ".st2{fill:none;stroke:#FFFFFF;stroke-width:0.3021;stroke-miterlimit:3.0208;}",
"</style>",
"<g id='Layer_7'>",
 _teller_logo_path_1,
 _teller_logo_path_2,
"</g></svg>"


);
 


function _generate_large_title( 
    string memory amount,
    string memory symbol
) public pure returns (string memory) {


    return string(abi.encodePacked(

 "<g mask='url(#fade-symbol)'>",
"<rect fill='none' x='0px' y='0px' width='290px' height='200px'/>",
"<text y='50px' x='32px' fill='white' font-family='Courier New, monospace' font-weight='200' font-size='12px'>AMOUNT</text>",
"<text y='90px' x='32px' fill='white' font-family='Courier New, monospace' font-weight='200' font-size='12px'><tspan font-size='36px'>",amount,"</tspan> ",symbol,"</text>",
"</g>",
"<rect x='16' y='16' width='258' height='468' rx='4' ry='4' fill='rgba(0,0,0,0)' stroke='rgba(255,255,255,0.2)'/>"

 

  
  ));
}


function _generate_text_label( 
    string memory label,
    string memory value, 
    
    uint256 y_offset
) public pure returns (string memory) {


    return string(abi.encodePacked(
       "<g style='transform:translate(29px,", Strings.toString(y_offset) , "px)'>",
            "<rect width='232' height='26' rx='4' ry='4' fill='rgba(0,0,0,0.6)'/>",
            "<text x='12' y='17' font-family='Courier New, monospace' font-size='12' fill='#fff'>",
                "<tspan fill='rgba(255,255,255,0.6)'>", label, "</tspan>",value,
            "</text>",
        "</g>"
    ));
}

 
function _get_token_amount_formatted( 
    uint256 amount,
    uint256 decimals 
) public pure returns (string memory) { 
         uint256 precision = Math.min(3,decimals);
    

         //require(precision <= decimals, "Precision cannot be greater than decimals");

         uint256 before_decimal = amount / (10 ** decimals);

         uint256 after_decimal = amount % (10 ** decimals);

         // truncate to the required precision
         after_decimal = after_decimal / (10 ** (decimals - precision));

        if(before_decimal >= 1000000000000000){
            return "> RANGE";
        }

        if(before_decimal >= 1000000000000){
            uint256 trillions = before_decimal / 1000000000000;
            uint256 billions = (before_decimal % 1000000000000) / 100000000000;  // Get the first digit after the decimal point
            return string(abi.encodePacked(
                Strings.toString(trillions),
                ".",
                Strings.toString(billions),
                "T"
            ));
        }

         if(before_decimal >= 1000000000){
            uint256 billions = before_decimal / 1000000000;
            uint256 millions = (before_decimal % 1000000000) / 100000000;  // Get the first digit after the decimal point
            return string(abi.encodePacked(
                Strings.toString(billions),
                ".",
                Strings.toString(millions),
                "B"
            ));
        }

         if(before_decimal >= 1000000){
            uint256 millions = before_decimal / 1000000;
            uint256 thousands = (before_decimal % 1000000) / 100000;  // Get the first digit after the decimal point
            return string(abi.encodePacked(
                Strings.toString(millions),
                ".",
                Strings.toString(thousands),
                "M"
            ));
        }

        if(before_decimal >= 1000){
            uint256 fullThousands = before_decimal / 1000;
            uint256 remainder = (before_decimal % 1000) / 100;  // Get the first digit after the decimal point
            return string(abi.encodePacked(
                Strings.toString(fullThousands),
                ".",
                Strings.toString(remainder),
                "K"
            ));
        }

  
         return string(abi.encodePacked( 
             Strings.toString(before_decimal),
            ".",
             Strings.toString(after_decimal)
         ));
        
      

}


function _buildSvgData  (
    string memory loanId,
    string memory principalAmountFormatted,
    string memory principalTokenSymbol,
    string memory collateralLabel,
    string memory interestRateLabel,
    string memory loanDurationLabel


) internal pure returns (string memory) {

  return   string(abi.encodePacked(

"<svg width='290' height='500' viewBox='0 0 290 500' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>",

_bg_defs,


_clip_path_corners,
 

_generate_large_title( 
 principalAmountFormatted,
 principalTokenSymbol
),

_teller_logo,


_generate_text_label(
    "Loan ID:",
    loanId, //Strings.toString(bidId),
    354
),


_generate_text_label(
    "Collateral:",
    collateralLabel, //string(abi.encodePacked(collateral_amount_formatted," ",collateral_token_symbol)), 
    384
),


_generate_text_label(
    "APR:",
    interestRateLabel, //  "30 %",
    414
),


_generate_text_label(
    "Duration:",
    loanDurationLabel, //"7 days",
    444
),

 
"</svg>"
    ));



}

    function _get_token_decimals(address token) internal view returns (uint256) {
        if(token.code.length == 0){
            return 0;
        }

        try IERC20(token).decimals() returns (uint8 decimals) {
            return decimals;
        } catch {
            return 18; // Fallback to a standard number of decimals if the call fails
        }
    }

    function _get_token_symbol(address token) internal view returns (string memory) {
         if(token.code.length == 0){
            return "?";
        }
        
        try IERC20(token).symbol() returns (string memory symbol) {
            return symbol;
        } catch {
            return "?"; // Fallback to 'Unknown' if the call fails
        }
    }

function _get_interest_rate_formatted(uint16 interestRate) internal pure returns (string memory) {
    return string(abi.encodePacked( (interestRate / 100).toString(), " %"));
}

function _get_duration_formatted(uint32 sec) internal pure returns (string memory) {
        uint32 _months = sec / 4 weeks;
        uint32 _weeks = sec / 1 weeks;
        uint32 _days = sec / 1 days;
        uint32 _hours = sec / 1 hours;
        uint32 _minutes = sec / 1 minutes;
       
        if (_months > 0) {
            return string(abi.encodePacked(_months.toString(), " months "));
        } else if (_weeks > 0) {
            return string(abi.encodePacked(_weeks.toString(), " weeks "));
        } else if (_days > 0) {
            return string(abi.encodePacked(_days.toString(), " days "));
        } else if (_hours > 0) {
            return string(abi.encodePacked(_hours.toString(), " hours "));
        } else {
            return string(abi.encodePacked(_minutes.toString(), " minutes"));
        }
    }

function _get_collateral_label(Collateral memory collateral) internal view returns (string memory) {
    
    if(collateral._collateralAddress == address(0)){
        return "None";
    }
    
    if(collateral._collateralType == CollateralType.ERC20){
        string memory collateralAmountFormatted = _get_token_amount_formatted( 
                collateral._amount,
                _get_token_decimals(collateral._collateralAddress)
                
            );

        string memory collateralTokenSymbol = _get_token_symbol(collateral._collateralAddress);  

        return string(abi.encodePacked(collateralAmountFormatted," ",collateralTokenSymbol));
    }

    if(collateral._collateralType == CollateralType.ERC721){
        return "ERC721";
    }

    if(collateral._collateralType == CollateralType.ERC1155){
        return "ERC1155";
    }
   
     
  
}

function generateSVG( 
        uint256 bidId,
        uint256 principalAmount,
        address principalTokenAddress,
        Collateral memory collateral,        
        uint16 interestRate,
        uint32 loanDuration
        ) public view returns (string memory) {

 
    string memory principalAmountFormatted = _get_token_amount_formatted( 
        principalAmount,
        _get_token_decimals(principalTokenAddress)
       
    );

    string memory principalTokenSymbol = _get_token_symbol(principalTokenAddress);

   

    string memory svgData = _buildSvgData(  
             (bidId).toString(),
            principalAmountFormatted,
            principalTokenSymbol,
            _get_collateral_label(collateral),
           
            _get_interest_rate_formatted(interestRate),
            _get_duration_formatted(loanDuration) 

    )  ;

   
    return svgData;
}

 



}



