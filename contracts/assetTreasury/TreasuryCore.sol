// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DRYP Token TreasuryCore contract
 * @author Ateet Tiwari
 */

import "./TreasuryInitializer.sol";
import { UtilMath } from "../utils/UtilMath.sol";
contract TreasuryCore is TreasuryInitializer {
    using UtilMath for uint256;
    modifier whenNotCapitalPaused() {
        require(!capitalPaused, "Capital paused");
        _;
    }
    modifier onlyWhenTreasuryInitialized() {
        require(
            _treasuryStarted == true,
            "treasury not initialized"
        );
        _;
    }

    function totalValueLockedInRedeemBasket() public view returns (uint256) {
        uint256 totalLocked = 0;
        uint8 usdtDecimal = 6;
        uint256 assetCount = _allAssets.length;
        for (uint32 i = 0; i < assetCount; ++i) {
            address assetAddress = _allAssets[i];
            if(!_redeemBasketAssets[assetAddress].isSupported)
            {
                continue;
            }
            uint8 assetDecimal = _redeemBasketAssets[assetAddress].decimals;
            uint256 totalAssetLocked = IERC20(assetAddress).balanceOf(address(this));
            if(usdtDecimal != assetDecimal)
            {
                uint unitPriceInUsdt = _toUnitsPrice(assetDecimal, totalAssetLocked);
                totalLocked += unitPriceInUsdt*_mintTokens[assetAddress].priceInUsdt;
            }
            else
            {
                uint totalDollarValue = totalAssetLocked*_redeemBasketAssets[assetAddress].priceInUsdt;
                totalLocked += totalDollarValue;
            }
        }
        return totalLocked;
    }

    function totalValueLockedInNonRedeemBasket() public view returns (uint256) {
        uint256 totalLocked = 0;
        uint8 usdtDecimal = 6;
        uint256 assetCount = _allAssets.length;
        for (uint32 i = 0; i < assetCount; ++i) {
            address assetAddress = _allAssets[i];
            if(!_unredeemBasketAssets[assetAddress].isSupported)
            {
                continue;
            }
            uint8 assetDecimal = _unredeemBasketAssets[assetAddress].decimals;
            uint256 totalAssetLocked = IERC20(assetAddress).balanceOf(address(this));
            if(usdtDecimal != assetDecimal)
            {
                uint unitPriceInUsdt = _toUnitsPrice(assetDecimal, totalAssetLocked);
                totalLocked += unitPriceInUsdt*_mintTokens[assetAddress].priceInUsdt;
            }
            else
            {
                uint totalDollarValue = totalAssetLocked*_unredeemBasketAssets[assetAddress].priceInUsdt;
                totalLocked += totalDollarValue;
            }
        }
        return totalLocked;
    }

    function totalValueLockedInRevenue() public view returns (uint256) {
        uint256 totalLocked = 0;
        uint8 usdtDecimal = 6;
        uint256 assetCount = _mintingAssets.length;
        for (uint32 i = 0; i < assetCount; ++i) {
            address mintingAddress = _mintingAssets[i];
            if(!_mintTokens[mintingAddress].isSupported)
            {
                continue;
            }
            uint8 assetDecimal = _mintTokens[mintingAddress].decimals;
            uint256 totalAssetLocked = IERC20(mintingAddress).balanceOf(address(this));
            if(usdtDecimal != assetDecimal)
            {
                uint unitPriceInUsdt = _toUnitsPrice(assetDecimal, totalAssetLocked);
                totalLocked += unitPriceInUsdt*_mintTokens[mintingAddress].priceInUsdt;
            }
            else
            {
                uint256 totalDollarValue = totalAssetLocked*_mintTokens[mintingAddress].priceInUsdt;
                totalLocked += totalDollarValue;
            }
        }
        return totalLocked;
    }

    /**
     * @notice Deposit a supported asset and mint Dryp Token.
     * @param _asset Address of the asset being deposited
     * @param _amount Amount of the asset being deposited
     * @param _minimumDrypAmount Minimum Dryp to mint
     */
    function mint(
        address _asset,
        uint256 _amount,
        uint256 _minimumDrypAmount,
        address _recipient
    ) external whenNotCapitalPaused onlyWhenTreasuryInitialized payable {
        _mint(_asset, _amount, _minimumDrypAmount, _recipient);
    }

    // pool usdt + 
    // pool dryp -
    function _mint(
        address __asset,
        uint256 __amount,
        uint256 __minimumDrypAmount,
        address __recipient
    ) internal virtual {
        require(_mintTokens[__asset].isSupported, "Asset not supported");
        require(__amount > 0, "Amount less than 0");
        require(__amount < _mintTokens[__asset].maxAllowed, "Amount greater than maxAllowed");

        uint256 priceAdjustedDeposit = _getDrypDollar(__amount, _usdt);

        if (__minimumDrypAmount > 0) {
            require(
                priceAdjustedDeposit >= __minimumDrypAmount,
                "Mint amount lower than minimum"
            );
        }

        emit Mint(__recipient, priceAdjustedDeposit);
        // Mint matching amount of Dryp
        _dryp.mint(__recipient, priceAdjustedDeposit);

        // Transfer the deposited coins to the treasury as revenue
        require(IERC20(__asset).transferFrom(msg.sender, address(this),__amount), "Transfer failed");
    }

    /**
     * @notice Withdraw a supported asset and burn Dryp.
     * @param _amount Amount of Asset to withdraw
     * @param _recipient Recipient of funds
     */
    function redeemAssets(uint256 _amount, address _recipient)
        external
        whenNotCapitalPaused
        onlyWhenTreasuryInitialized
        payable
    {
        _redeem(_amount, _recipient);
    }

    /**
     * @notice Withdraw a supported asset and burn Dryp.
     * @param __amount Amount of Dryp to burn
     * @param __recipient user getting funds
     */
    function _redeem(uint256 __amount, address __recipient)
        internal
        virtual
    {  
        require(__amount > 0, "Redeem amount less than 0");
        // uint256 usdtRedeemValue = _drypPool.getRedeemValue(__amount);
        uint256 usdtRedeemValue = _getDrypDollar(__amount, address(_dryp));
        uint256[] memory outputs = _calculateRedeemOutputs(usdtRedeemValue);

        emit Redeem(__recipient, __amount);

        // Send outputs
        uint256 assetCount = _allAssets.length;
        for (uint256 i = 0; i < assetCount; ++i) {
            if (outputs[i] == 0) continue;
            address assetAddr = _allAssets[i]; 
            uint256 assetBalance = IERC20(assetAddr).balanceOf(address(this));
            if(outputs[i] > assetBalance)
            {
                revert("not available for redeem");
            }
            if (IERC20(assetAddr).balanceOf(address(this)) >= outputs[i]) {
                IERC20(assetAddr).transfer(__recipient, outputs[i]);
                _redeemBasketAssets[assetAddr].amount = _redeemBasketAssets[assetAddr].amount - outputs[i];
            } else {
                revert("Liquidity error");
            }
        }
        // send back from user to dryp
        _dryp.burn(address(__recipient), __amount);
    }

    /**
     * @notice Calculate the outputs for a redeem function, i.e. the mix of
     * coins that will be returned
     */
    function calculateRedeemOutputs(uint256 _amount)
        external
        view
        onlyWhenTreasuryInitialized
        returns (uint256[] memory)
    {
        uint256 usdtRedeemValue = _getDrypDollar(_amount, _usdt);
        return _calculateRedeemOutputs(usdtRedeemValue);
    }

    /**
     * @dev Calculate the outputs for a redeem function, i.e. the mix of
     * coins that will be returned.
     * @return outputs Array of amounts respective to the supported assets
     */
    function _calculateRedeemOutputs(uint256 _amount)
        internal
        view
        virtual
        returns (uint256[] memory outputs)
    {
        uint256 assetCount = _allAssets.length;
        outputs = new uint256[](assetCount);
        uint256 totalUsdtValue = 0;
        // Calculate assets balances and decimals once,
        // for a large gas savings.
        for (uint32 i = 0; i < assetCount; ++i) {
            address assetAddr = _allAssets[i];
            TreasuryAsset memory asset = _redeemBasketAssets[assetAddr];
            if (asset.isSupported) {
                uint256 totalValueLocked = asset.amount;
                totalUsdtValue += totalValueLocked * asset.priceInUsdt;
            }
        }
        // Calculate totalOutputRatio
        for (uint256 i = 0; i < assetCount; ++i) {
            address assetAddress = _allAssets[i];
            TreasuryAsset memory asset = _redeemBasketAssets[assetAddress];
            if (asset.isSupported) {
                uint256 assetValueInUsdt = (asset.priceInUsdt * asset.allotatedPercentange) / 100;
                uint256 amountToRedeem = (_amount * assetValueInUsdt) / totalUsdtValue;
                outputs[i] = amountToRedeem;
            }
        }
        return outputs;
    }

    /***************************************
                    Utils
    ****************************************/

    function _toUnitsPrice( uint256 _decimal, uint256 _amount)
        public
        pure
        returns (uint256)
    {
        uint256 usdtDecimal = 6;
        if (_decimal == usdtDecimal) {
            return _amount;
        } else{
           uint256 _rawAdjusted= _amount.scaleBy(usdtDecimal, _decimal);
           return _rawAdjusted;
        }
    }
    /**
     * @dev Falldown to the admin implementation
     * @notice This is a catch all for all functions not declared in core
     */
    fallback() external {
        bytes32 slot = adminImplPosition;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(
                gas(),
                sload(slot),
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
