// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Dryp TreasuryInitializer contract
 * @notice The Treasury contract initializes the Treasury.
 * @author Ateet Tiwari
 */

import "./TreasuryStorage.sol";

contract TreasuryInitializer is TreasuryStorage {
    function initialize(address __drypToken, address __drypPool, address __treasuryManager, address __usdt)
        external
        initializer
    {
        require(__drypToken != address(0), "drypToken is zero");
        require(__drypPool != address(0), "dryp Pool is zero");
        require(__treasuryManager != address(0), "treasury manager is zero");
        require(__usdt != address(0), "usdt is zero");

        __ReentrancyGuard_init();
        _dryp = Dryp(__drypToken);
        __Pool_init(__drypPool);

        rebasePaused = true;
        capitalPaused = false;

        _grantRole(TREASURY_MANAGER, __treasuryManager);
        _treasury_manager = __treasuryManager;
        _usdt = __usdt;

        _mintTokens[_usdt] = ExchangeToken({
            isSupported: true,
            allowed: true,
            symbol: "USDT",
            decimals: 6,
            megaPool: address(0),
            maxAllowed: 100e6,
            priceInUsdt: 1000000
        });
        _mintingAssets.push(_usdt);
        _treasuryStarted = false;
        rebasePaused = true;
        capitalPaused = false;
    }
}
