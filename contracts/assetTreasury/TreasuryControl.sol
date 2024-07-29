// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DRYP Treasury Controller
 * @author Ateet Tiwari
 */

import {IPancakeswapV2PositionManager} from "../interfaces/IPancakeSwap.sol";
import "./TreasuryCore.sol";

contract TreasuryController is TreasuryInitializer {
    /***************************************
                 Configuration
    ****************************************/

    /**
     * @notice Set address of initial treasury setup
     */

    function startTreasury(address[] calldata _assets, uint8[] calldata _decimals, uint16[] calldata _allocatPercentage, uint32[] calldata _price, uint256[] calldata _amounts) external payable onlyRole(TREASURY_MANAGER) nonReentrant {
        require(_treasuryStarted == false, "Already started");
        uint256 assetCount = _assets.length;
        require(
                assetCount == _decimals.length &&
                assetCount == _allocatPercentage.length &&
                assetCount == _price.length &&
                assetCount == _amounts.length,
                "Array lengths mismatch"
        );
        for (uint256 i = 0; i < assetCount; ++i) {
            require(_amounts[i] > 0, "Zero asset not allowed");
            require(!_redeemBasketAssets[_assets[i]].isSupported, "Asset already supported in RB");
            require(!_unredeemBasketAssets[_assets[i]].isSupported, "Asset already supported in URB");
            
            _addAssetInRedeemBasket(_assets[i], _decimals[i], _allocatPercentage[i], _price[i], _amounts[i]);
            _addAssetInUnRedeemBasket(_assets[i], _decimals[i], _allocatPercentage[i], _price[i], 0);
            _allAssets.push(_assets[i]);
            emit AssetAdded(_assets[i]);
        }
        _treasuryStarted = true;
    }

    /***************************************
                Asset Config
    ****************************************/
    /**
     * @notice Add a supported asset to the contract, i.e. one that can be
     *         to mint OTokens.
     * @param _asset Address of asset
     */
    function addAsset(address _asset, uint8 _decimals, uint16 _allocatedPercentage, uint32 _price, uint256 _amount)
        external
        payable
        onlyRole(TREASURY_MANAGER)
    {
        require(
            _treasuryStarted == true,
            "treasury initialized"
        );
        require(!_redeemBasketAssets[_asset].isSupported, "Asset already supported");
        require(!_unredeemBasketAssets[_asset].isSupported, "Asset already supported");
        _addAssetInRedeemBasket(_asset, _decimals, _allocatedPercentage, _price, _amount);
        _addAssetInUnRedeemBasket(_asset, _decimals, _allocatedPercentage, _price, _amount);
        _allAssets.push(_asset);
        emit AssetAdded(_asset);
    }

    function updateAssetToRedeemBasket(address _asset,bool _isSupported, uint8 _decimals, uint16 _allocatedPercentage, uint32 _price)
        external
        onlyRole(TREASURY_MANAGER)
    {
        require(
            _treasuryStarted == true,
            "treasury not initialized"
        );
        require(_redeemBasketAssets[_asset].isSupported, "Asset Not Supported");
        TreasuryAsset storage asset = _redeemBasketAssets[_asset];
        asset.isSupported = _isSupported;
        asset.decimals = _decimals;
        asset.allotatedPercentange = _allocatedPercentage;
        asset.priceInUsdt = _price; 
        emit AssetUpdated(_asset, _isSupported, _decimals, _allocatedPercentage, _price);
    }

    function updateAssetToUnRedeemBasket(address _asset,bool _isSupported, uint8 _decimals, uint16 _allocatedPercentage, uint32 _price)
        external
        onlyRole(TREASURY_MANAGER)
    {
        require(
            _treasuryStarted == true,
            "treasury not initialized"
        );
        require(_unredeemBasketAssets[_asset].isSupported, "Asset Not Supported");
        TreasuryAsset storage asset = _unredeemBasketAssets[_asset];
        asset.isSupported = _isSupported;
        asset.decimals = _decimals;
        asset.allotatedPercentange = _allocatedPercentage;
        asset.priceInUsdt = _price;
        emit AssetUpdated(_asset, _isSupported, _decimals, _allocatedPercentage, _price);
    }

    function _addAssetInRedeemBasket(address _asset, uint8 _decimals, uint16 _allocatedPercentage, uint32 _price, uint256 _amount)
        internal
    {

        require(_amount > 0, "amount zero");
        require(IERC20(_asset).transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        _redeemBasketAssets[_asset] = TreasuryAsset({
            isSupported: true,
            decimals: _decimals,
            allotatedPercentange: _allocatedPercentage,
            priceInUsdt: _price,
            amount: _amount
        });
    }

    function _addAssetInUnRedeemBasket(address _asset, uint8 _decimals, uint16 _allocatedPercentage, uint32 _price, uint256 _amount)
        internal
    {
        require(IERC20(_asset).transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        _unredeemBasketAssets[_asset] = TreasuryAsset({
            isSupported: true,
            decimals: _decimals,
            allotatedPercentange: _allocatedPercentage, // will be overridden in _cacheDecimals
            priceInUsdt: _price,
            amount: _amount
        });
    }

    function addMintingToken(address _asset,string memory _symbol, uint8 _decimals, uint32 _price)
        external
        onlyRole(TREASURY_MANAGER)
    {
        _addMintingAsset(_asset, _decimals, _symbol, _price);
    }

    function _addMintingAsset(address _asset, uint8 _decimals, string memory _symbol, uint32 _price)
        internal
    {
        require(!_mintTokens[_asset].isSupported, "Asset already supported");

        _mintTokens[_asset] = ExchangeToken({
            isSupported: true,
            allowed: true,
            megaPool: address(0),
            decimals: _decimals,
            maxAllowed: 10000000000,
            symbol: _symbol,
            priceInUsdt: _price
        });

        emit MintAssetAdded(_asset);
    }


    function removeMintingToken(address _asset)
        external
        onlyRole(TREASURY_MANAGER)
    {
        _removeMintingAsset(_asset);
    }

    function _removeMintingAsset(address _asset) internal {
        require(_mintTokens[_asset].isSupported, "Asset not supported");
        require(
            IERC20(_asset).balanceOf(address(this)) <= 1e13,
            "Treasury still holds asset"
        );
        delete _mintTokens[_asset];
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
        require(_redeemBasketAssets[_asset].isSupported, "Asset not supported");
        require(_unredeemBasketAssets[_asset].isSupported, "Asset not supported");
        require(
            IERC20(_asset).balanceOf(address(this)) <= 1e13,
            "Treasury still holds asset"
        );
        uint assetsCount = _allAssets.length;
        uint assetIndex = assetsCount; // initialize at invaid index
        for (uint i = 0; i < assetsCount; ++i) {
            if (_allAssets[i] == _asset) {
                assetIndex = i;
                break;
            }
        }

        // Note: If asset is not found in `allAssets`, the following line
        // will revert with an out-of-bound error. However, there's no
        // reason why an asset would have `Asset.isSupported = true` but
        // not exist in `allAssets`.

        // Update allAssets array
        _allAssets[assetIndex] = _allAssets[assetsCount - 1];
        _allAssets.pop();
        // Remove asset from storage
        delete _redeemBasketAssets[_asset];
        delete _unredeemBasketAssets[_asset];
        emit AssetRemoved(_asset);
    }

    function depositToRedeemableBasket(address _asset, uint256 _amount) external payable onlyRole(TREASURY_MANAGER) {
        require(msg.value > _amount, "require send amount");
        _depositToRedeemableBasket(_asset, _amount);
    }

    function _depositToRedeemableBasket(
        address _asset,
        uint256 _amount
    ) internal {
        require(_redeemBasketAssets[_asset].isSupported, "Invalid token");
        require(IERC20(_asset).transferFrom(msg.sender, address(this),_amount), "Transfer failed");
        TreasuryAsset storage asset = _redeemBasketAssets[_asset];
        asset.amount += _amount;
    }

    function depositToUnRedeemableBasket(address _asset,
        uint256 _amount) external payable onlyRole(TREASURY_MANAGER) {
            require(msg.value > _amount, "require send amount");
        _depositToUnRedeemableBasket(_asset, _amount);
    }

    function _depositToUnRedeemableBasket(
        address _asset,
        uint256 _amount
    ) internal {
        require(_unredeemBasketAssets[_asset].isSupported, "Invalid token");
        require(IERC20(_asset).transferFrom(msg.sender, address(this),_amount), "Transfer failed");
        TreasuryAsset storage asset = _unredeemBasketAssets[_asset];
        asset.amount += _amount;
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
         require(_unredeemBasketAssets[_asset].isSupported, "Invalid token");
         require(_unredeemBasketAssets[_asset].amount > _amount, "Invalid token");
         TreasuryAsset storage asset = _unredeemBasketAssets[_asset];
         IERC20(_asset).transferFrom(address(this), _treasury_manager, _amount);
         asset.amount -= _amount;
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
        require(_redeemBasketAssets[_asset].isSupported, "Invalid token");
        require(_redeemBasketAssets[_asset].amount > _amount, "Invalid token");
        TreasuryAsset storage asset = _redeemBasketAssets[_asset];
        IERC20(_asset).transferFrom(address(this), _treasury_manager, _amount);
        asset.amount -= _amount;
         
    }

    /***************************************
                    Utils
    ****************************************/

    function _transferToken(address _asset, uint256 _amount)
        internal
    {
        IERC20(_asset).transfer(_treasury_manager, _amount);
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
        uint256 assetLeng= _allAssets.length;
        for (uint32 i = 0; i < assetLeng; ++i) {
            if(_unredeemBasketAssets[_allAssets[i]].isSupported)
            {
                uint ercAmount = IERC20(_allAssets[i]).balanceOf(address(this));
                if(ercAmount > 0)
                {
                    IERC20(_allAssets[i]).transfer(_treasury_manager,  ercAmount);
                }
            }
        }
    }
}
