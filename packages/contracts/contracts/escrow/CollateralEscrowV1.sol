// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Interfaces
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {
    SafeERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "../interfaces/escrow/ICollateralEscrowV1.sol";

contract CollateralEscrowV1 is OwnableUpgradeable, ICollateralEscrowV1 {

    uint256 public bidId;
    /* Mappings */
    mapping(address => Collateral) public collateralBalances; // collateral address -> collateral

    /* Events */
    event CollateralDeposited(address _collateralAddress, uint256 _amount);
    event CollateralWithdrawn(address _collateralAddress, uint256 _amount, address _recipient);

    /**
     * @notice Initializes the implementation.
     */
    constructor() {
        initialize(0);
    }

    /**
     * @notice Initializes an escrow.
     * @notice The id of the associated bid.
     */
    function initialize(uint256 _bidId)
        public
        initializer
    {
        require(owner() == address(0), "Escrow already initialized");
        __Ownable_init();
        bidId = _bidId;
    }

    /**
     * @notice Deposits a collateral ERC20 token into the escrow.
     * @param _collateralAddress The address of the collateral token.
     * @param _amount The amount to deposit.
     */
    function depositToken(
        address _collateralAddress,
        uint256 _amount
    )
        external
        payable
        onlyOwner
    {
        require(_amount > 0, "Deposit amount cannot be zero");
        _depositCollateral(CollateralType.ERC20, _collateralAddress, _amount, 0);
        Collateral storage collateral = collateralBalances[_collateralAddress];
        collateral._collateralType = CollateralType.ERC20;
        collateral._amount = _amount;
        collateral._tokenId = 0;
        emit CollateralDeposited(_collateralAddress, _amount);
    }

    /**
     * @notice Deposits a collateral asset into the escrow.
     * @param _collateralType The type of collateral asset to deposit (ERC721, ERC1155).
     * @param _collateralAddress The address of the collateral token.
     * @param _amount The amount to deposit.
     */
    function depositAsset(
        CollateralType _collateralType,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    )
        external
        payable
        onlyOwner
    {
        require(_amount > 0, "Deposit amount cannot be zero");
        _depositCollateral(_collateralType, _collateralAddress, _amount, _tokenId);
        Collateral storage collateral = collateralBalances[_collateralAddress];
        collateral._collateralType = _collateralType;
        collateral._amount = _amount;
        collateral._tokenId = _tokenId;
        emit CollateralDeposited(_collateralAddress, _amount);
    }

    /**
     * @notice Withdraws a collateral asset from the escrow.
     * @param _collateralAddress The address of the collateral contract.
     * @param _amount The amount to withdraw.
     * @param _recipient The address to send the assets to.
     */
    function withdraw(address _collateralAddress, uint256 _amount, address _recipient)
        external
        onlyOwner
    {
        require(_amount > 0, "Withdraw amount cannot be zero");
        Collateral storage collateral = collateralBalances[_collateralAddress];
        require(collateral._amount > 0, "No collateral balance for asset");
        _withdrawCollateral(collateral, _collateralAddress, _amount, _recipient);
        collateral._amount -= _amount;
        emit CollateralWithdrawn(_collateralAddress, _amount, _recipient);
    }


    function _depositCollateral(
        CollateralType _collateralType,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    ) internal {
        // Deposit ERC20
        if (_collateralType == CollateralType.ERC20) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(_collateralAddress),
                msg.sender,
                address(this),
                _amount
            );
            return;
        }
        // Deposit ERC721
        if (_collateralType == CollateralType.ERC721) {
            IERC721Upgradeable(_collateralAddress)
                .safeTransferFrom(
                    msg.sender,
                    address(this),
                    _tokenId
                );
            return;
        }
        // Deposit ERC1155
        if (_collateralType == CollateralType.ERC721) {
            bytes memory data;

            IERC1155Upgradeable(_collateralAddress)
                .safeTransferFrom(
                    msg.sender,
                    address(this),
                    _tokenId,
                    _amount,
                    data
                );
            return;
        }
    }

    function _withdrawCollateral(
        Collateral memory _collateral,
        address _collateralAddress,
        uint256 _amount,
        address _recipient
    ) internal {
        // Withdraw ERC20
        if (_collateral._collateralType == CollateralType.ERC20) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(_collateralAddress),
                address(this),
                _recipient,
                _collateral._amount
            );
            return;
        }
        // Withdraw ERC721
        if (_collateral._collateralType == CollateralType.ERC721) {
            IERC721Upgradeable(_collateralAddress)
            .safeTransferFrom(
                address(this),
                _recipient,
                _collateral._tokenId
            );
            return;
        }
        // Withdraw ERC1155
        if (_collateral._collateralType == CollateralType.ERC721) {
            bytes memory data;

            IERC1155Upgradeable(_collateralAddress)
            .safeTransferFrom(
                address(this),
                _recipient,
                _collateral._tokenId,
                _amount,
                data
            );
            return;
        }
    }

    // On NFT Received handlers

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
        bytes4(
            keccak256("onERC721Received(address,address,uint256,bytes)")
        );
    }

    function onERC1155Received(
        address,
        address,
        uint256 id,
        uint256 value,
        bytes calldata
    ) external returns (bytes4) {
        return
        bytes4(
            keccak256(
                "onERC1155Received(address,address,uint256,uint256,bytes)"
            )
        );
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata
    ) external returns (bytes4) {
        require(
            _ids.length == 1,
            "Only allowed one asset batch transfer per transaction."
        );
        return
        bytes4(
            keccak256(
                "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
            )
        );
    }

}
