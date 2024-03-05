pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LenderCommitmentGroupShares is ERC20, Ownable {
    uint8 private immutable DECIMALS;

    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol)
        Ownable()
    {
        DECIMALS = _decimals;
    }

    function mint(address _recipient, uint256 _amount) external onlyOwner {
        _mint(_recipient, _amount);
    }

    function burn(address _burner, uint256 _amount) external onlyOwner {
        _burn(_burner, _amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }
}
