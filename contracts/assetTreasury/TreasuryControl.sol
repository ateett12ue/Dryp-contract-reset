// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DRYP Treasury Controller
 * @author Ateet Tiwari
 */

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UtilMath } from "../utils/UtilMath.sol";

import "./TreasuryStorage.sol";

contract TreasuryController is TreasuryStorage {
    using SafeERC20 for IERC20;
    using UtilMath for uint256;

    /***************************************
                 Configuration
    ****************************************/

    /**
     * @notice Set address of initial treasury setup
     */

    function startTreasury(address[] calldata _assets, uint8[] calldata _decimals, uint16[] calldata _allocatPercentage, uint256[] calldata _price) external onlyRole(TREASURY_MANAGER) {
        require(treasuryStarted == false, "treasury already started");
        
        uint256 assetCount = _assets.length;
        for (uint256 i = 0; i < assetCount; ++i) {
            _addAsset(_assets[i], _decimals[i], _allocatPercentage[i], _price[i]);
        }
        treasuryStarted = true;
    }

    function updateDrypAddress(address newDrypAddress) external onlyRole(TREASURY_MANAGER) returns(bool)
    {
        _dryp = Dryp(newDrypAddress);
        return true;
    }

    function updateDrypPoolAddress(address newDrypPool) external onlyRole(TREASURY_MANAGER) returns(bool)
    {
        _drypPool = newDrypPool;
        return true;
    }

    /***************************************
                Asset Config
    ****************************************/

    /**
     * @notice Add a supported asset to the contract, i.e. one that can be
     *         to mint OTokens.
     * @param _asset Address of asset
     */
    function addAsset(address _asset, uint8 _decimals, uint16 _allocatedPercentage, uint256 _price)
        external
        onlyRole(TREASURY_MANAGER)
    {
        _addAsset(_asset, _decimals, _allocatedPercentage, _price);
    }

    function _addAsset(address _asset, uint8 _decimals, uint16 _allocatedPercentage, uint256 _price)
        internal
    {
        require(!redeemBasketAssets[_asset].isSupported, "Asset already supported in Redeem Basket");
        require(!unredeemBasketAssets[_asset].isSupported, "Asset already supported in unRedeem Basket");

        redeemBasketAssets[_asset] = TreasuryAsset({
            isSupported: true,
            decimals: _decimals,
            allotatedPercentange: _allocatedPercentage, // will be overridden in _cacheDecimals
            priceInUsdt: _price
        });

        unredeemBasketAssets[_asset] = TreasuryAsset({
            isSupported: true,
            decimals: _decimals,
            allotatedPercentange: _allocatedPercentage, // will be overridden in _cacheDecimals
            priceInUsdt: _price
        });

        _cacheDecimals(_asset);
        allAssets.push(_asset);

        emit AssetAdded(_asset);
    }

    function addMintingToken(address _asset,string memory _symbol, uint8 _decimals, uint256 _price)
        external
        onlyRole(TREASURY_MANAGER)
    {
        _addMintingAsset(_asset, _decimals, _symbol, _price);
    }

    function _addMintingAsset(address _asset, uint8 _decimals, string memory _symbol, uint256 _price)
        internal
    {
        require(!mintTokens[_asset].isSupported, "Asset already supported as Exchange Token");

        mintTokens[_asset] = ExchangeToken({
            isSupported: true,
            allowed: true,
            megaPool: address(0),
            decimals: _decimals,
            maxAllowed: 0,
            symbol: _symbol,
            priceInUsdt: _price
        });

        _cacheDecimals(_asset);
        emit MintAssetAdded(_asset);
    }


    function removeMintingToken(address _asset)
        external
        onlyRole(TREASURY_MANAGER)
    {
        _removeMintingAsset(_asset);
    }

    function _removeMintingAsset(address _asset) internal {
        require(mintTokens[_asset].isSupported, "Asset not supported for minting");
        require(
            IERC20(_asset).balanceOf(address(this)) <= 1e13,
            "Treasury still holds asset"
        );

        delete mintTokens[_asset];

        emit MintAssetRemoved(_asset);
    }

    /**
     * @notice Remove a supported asset from the Vault
     * @param _asset Address of asset
     */
    function removeAsset(address _asset) external onlyRole(TREASURY_MANAGER) {
        _removeAsset(_asset);
    }

    function _removeAsset(address _asset) internal {
        require(redeemBasketAssets[_asset].isSupported, "Asset not supported in redeem basket");
        require(unredeemBasketAssets[_asset].isSupported, "Asset not supported in unredeem basket");
        require(
            IERC20(_asset).balanceOf(address(this)) <= 1e13,
            "Treasury still holds asset"
        );

        uint256 assetsCount = allAssets.length;
        uint256 assetIndex = assetsCount; // initialize at invaid index
        for (uint256 i = 0; i < assetsCount; ++i) {
            if (allAssets[i] == _asset) {
                assetIndex = i;
                break;
            }
        }

        // Note: If asset is not found in `allAssets`, the following line
        // will revert with an out-of-bound error. However, there's no
        // reason why an asset would have `Asset.isSupported = true` but
        // not exist in `allAssets`.

        // Update allAssets array
        allAssets[assetIndex] = allAssets[assetsCount - 1];
        allAssets.pop();
        // Remove asset from storage
        delete redeemBasketAssets[_asset];
        delete unredeemBasketAssets[_asset];

        emit AssetRemoved(_asset);
    }

    function depositToRedeemableBasket(address[] calldata _assets,
        uint256[] calldata _amounts) external onlyRole(TREASURY_MANAGER) {
        _depositToRedeemableBasket(_assets, _amounts);
    }


    function _depositToRedeemableBasket(
        address[] calldata _assets,
        uint256[] calldata _amounts
    ) internal {
        
        require(_assets.length == _amounts.length, "Parameter length mismatch");

        uint256 assetCount = _assets.length;
        for (uint256 i = 0; i < assetCount; ++i) {
            require( redeemBasketAssets[_assets[i]].isSupported, "Invalid to token");
            address assetAddr = _assets[i];
            // Send required amount of funds to the strategy
            IERC20(assetAddr).safeTransferFrom(treasury_manager, address(this), _amounts[i]);
        }
    }

    function depositToUnRedeemableBasket(address[] calldata _assets,
        uint256[] calldata _amounts) external onlyRole(TREASURY_MANAGER) {
        _depositToUnRedeemableBasket(_assets, _amounts);
    }

    function _depositToUnRedeemableBasket(
        address[] calldata _assets,
        uint256[] calldata _amounts
    ) internal {
        require(_assets.length == _amounts.length, "Parameter length mismatch");
        uint256 assetCount = _assets.length;
        for (uint256 i = 0; i < assetCount; ++i) {
            require( unredeemBasketAssets[_assets[i]].isSupported, "Invalid token");
            address assetAddr = _assets[i];
            // Send required amount of funds to the strategy
            IERC20(assetAddr).safeTransferFrom(treasury_manager, address(this), _amounts[i]);
        }
    }

    /**
     * @notice Withdraw multiple assets from the strategy to the vault.
     * @param _asset asset address that will be withdrawn from the strategy.
     * @param _amount amounts of each corresponding asset to withdraw.
     */
    function withdrawFromUnredeemableBaseket(
        address _asset,
        uint256 _amount
    ) external onlyRole(TREASURY_MANAGER) nonReentrant {
        _withdrawFromUnredeemableBaseket(
            _asset,
            _amount
        );
    }

    function _withdrawFromUnredeemableBaseket(
        address _asset,
        uint256 _amount
    )internal {
         require(unredeemBasketAssets[_asset].isSupported, "Invalid token");
         IERC20(_asset).safeTransferFrom(address(this), treasury_manager, _amount);
    }

    function withdrawFromredeemableBaseket(
        address _asset,
        uint256 _amount
    ) external onlyRole(TREASURY_MANAGER) nonReentrant {
        _withdrawFromredeemableBaseket(
            _asset,
            _amount
        );
    }

    function _withdrawFromredeemableBaseket(
        address _asset,
        uint256 _amount
    )internal {
         require(redeemBasketAssets[_asset].isSupported, "Invalid token");
         IERC20(_asset).safeTransferFrom(address(this), treasury_manager, _amount);
    }

    /***************************************
                    Pause
    ****************************************/

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

    /***************************************
                    Utils
    ****************************************/

    /**
     * @notice Transfer token to governor. Intended for recovering tokens stuck in
     *      contract, i.e. mistaken sends.
     * @param _asset Address for the asset
     * @param _amount Amount of the asset to transfer
     */
    function transferToken(address _asset, uint256 _amount)
        external
        onlyRole(TREASURY_MANAGER)
    {
        _transferToken(_asset, _amount);
    }

    function _transferToken(address _asset, uint256 _amount)
        internal
    {
        require(!redeemBasketAssets[_asset].isSupported, "Only unsupported assets");
        IERC20(_asset).safeTransfer(treasury_manager, _amount);
    }

    function _treasury_manager() external view returns (address) {
        return treasury_manager;
    }

    /***************************************
             Strategies Admin
    ****************************************/

    /**
     * @notice Withdraws all assets from non redeem basket.
     */
    function withdrawAllFromNonRedeemBasket()
        external
        onlyRole(TREASURY_MANAGER)
    {
        uint256 assetLeng= allAssets.length;
        for (uint256 i = 0; i < assetLeng; ++i) {
            if(unredeemBasketAssets[allAssets[i]].isSupported)
            {
                if(IERC20(allAssets[i]).balanceOf(address(this)) > 0)
                {
                    _transferToken(allAssets[i], IERC20(allAssets[i]).balanceOf(address(this)));
                }
            }
        }
    }

    /***************************************
                    Utils
    ****************************************/

    function _cacheDecimals(address token) internal {
        TreasuryAsset storage tokenAsset = redeemBasketAssets[token];
        if (tokenAsset.decimals != 0) {
            return;
        }
        uint8 decimals = tokenAsset.decimals;
        require(decimals >= 6 && decimals <= 18, "Unexpected precision");
        tokenAsset.decimals = decimals;
    }
}
