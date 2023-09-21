// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExtensionsContext {
    function isExtensionAdded(address extension) external view returns (bool);

    function isExtensionBlocked(address extension) external view returns (bool);

    function hasApprovedExtension(address extension, address account) external view returns (bool);

    function approveExtension(address extension) external;

    function revokeExtension(address extension) external;

     
}