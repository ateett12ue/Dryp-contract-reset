// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DRYP Treasury Controller
 * @author Ateet Tiwari
 */

import {IPancakeswapV2PositionManager} from "../interfaces/IPancakeSwap.sol";
import "./TreasuryCore.sol";

contract TreasuryBase is TreasuryInitializer {
    function updateDrypAddress(address newDrypAddress) external onlyRole(TREASURY_MANAGER) returns(bool)
    {
        _dryp = Dryp(newDrypAddress);
        return true;
    }

    function updateDrypPoolAddress(address newDrypPool) external onlyRole(TREASURY_MANAGER) returns(bool)
    {
        _drypPoolPositionManager = IPancakeswapV2PositionManager(newDrypPool);
        return true;
    }

    /**
     * @notice Set the deposit paused flag to true to prevent rebasing.
     */
    function pauseRebase() external onlyRole(TREASURY_MANAGER) {
        rebasePaused = true;
        emit RebasePaused();
    }

    /**
     * @notice Set the deposit paused flag to true to allow rebasing.
     */
    function unpauseRebase() external onlyRole(TREASURY_MANAGER) {
        rebasePaused = false;
        emit RebaseUnpaused();
    }

    /**
     * @notice Set the deposit paused flag to true to prevent capital movement.
     */
    function pauseCapital() external onlyRole(TREASURY_MANAGER) {
        capitalPaused = true;
        emit CapitalPaused();
    }

    /**
     * @notice Set the deposit paused flag to false to enable capital movement.
     */
    function unpauseCapital() external onlyRole(TREASURY_MANAGER) {
        capitalPaused = false;
        emit CapitalUnpaused();
    }

    /**
     * @notice function to return the address of Dexspan.
     */
    function isTokenAllowedForMiniting(address token) public view returns (bool) {
        return _mintTokens[token].isSupported;
    }

    /**
     * @notice function to return the address of AssetForwarder.
     */
    function getAllAssets() external view returns (address[] memory) {
        return _allAssets;
    }

    function getAllMinitingAssets() external view returns (address[] memory) {
        return _mintingAssets;
    }

    function isTreasuryStarted() public view returns (bool) {
        return _treasuryStarted;
    }

    /**
     * @notice Get the balance of an asset held in Vault and all strategies.
     * @param _asset Address of asset
     * @return uint256 Balance of asset in decimals of asset
     */
    function checkBalance(address _asset) external view onlyRole(TREASURY_MANAGER) returns (uint256) {
        IERC20 asset = IERC20(_asset);
        return asset.balanceOf(address(this));
    }

    /**
     * @notice Gets the vault configuration of a supported asset.
     */
    function getRedeemAssetConfig(address _asset)
        public
        view
        returns (TreasuryAsset memory config)
    {
        config = _redeemBasketAssets[_asset];
    }

    function getUnRedeemAssetConfig(address _asset)
        public
        view
        returns (TreasuryAsset memory config)
    {
        config = _unredeemBasketAssets[_asset];
    }

}
