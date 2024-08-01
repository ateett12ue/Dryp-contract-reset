// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DRYP Treasury Storage contract
 * @author Ateet Tiwari
 */

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Dryp } from "../treasuryToken/Dryp.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "../utils/Helpers.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PancakeswapHelpers} from "./Pool.sol";
import { UtilMath } from "../utils/UtilMath.sol";
contract TreasuryStorage is Initializable, AccessControl, ReentrancyGuardUpgradeable,PancakeswapHelpers {
    using SafeERC20 for IERC20;
    using UtilMath for uint256;

    // for asset to be added and remove from treasury
    event AssetAdded(address _asset);
    event AssetRemoved(address _asset);
    event AssetUpdated(address _asset,bool _isSupported, uint8 _decimals, uint16 _allocatedPercentage, uint256 _price);

    // for asset to be added and remove from treasury
    event MintAssetAdded(address _asset);
    event MintAssetRemoved(address _asset);

    // minting and redeem calls from treasury manager
    event Mint(address _addr, uint256 _value);
    event Redeem(address _addr, uint256 _value);

    // total treasury paused by treasury manager
    event CapitalPaused();
    event CapitalUnpaused();

    // rebasing paused by treasury manager
    event RebasePaused();
    event RebaseUnpaused();

    // DAI< USDT < USDC
    struct ExchangeToken{
        bool isSupported;
        bool allowed;
        address megaPool;
        uint8 decimals;
        uint256 maxAllowed;
        string symbol;
        uint32 priceInUsdt;
    }

    // ETH< WBTC < DAI < LINK -- AAVE TOKENS
    struct TreasuryAsset {
        bool isSupported;
        uint8 decimals;
        uint16 allotatedPercentange;
        uint256 priceInUsdt;
        uint256 amount;
    }

    bytes32 public constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);


    address public _usdt;
    address public _treasury_manager;
    /// @dev list of all assets supported by the treasury.

    mapping(address => TreasuryAsset) internal _redeemBasketAssets;

    /// @dev list of all assets supported by the treasury in nonRedeemBasket.
    mapping(address => TreasuryAsset) internal _unredeemBasketAssets;

    /// @dev list of all assets supported for swapping DRYP.
    mapping(address => ExchangeToken) internal _mintTokens;

    address[] internal _allAssets;

    address[] internal _mintingAssets;
    bool internal _treasuryStarted;

    // Rebalancing Configs approved for use by the Vault
    struct Rebalancer {
        bool isSupported;
        uint256 _deprecated; // Deprecated storage slot
        uint256 _redeemBasketPercentage;
        uint256 _unredeemBasketPercentage;
    }
    /// @notice pause rebasing if true
    bool public rebasePaused;
    /// @notice pause operations that change the DRYP supply.
    /// eg mint, redeem, allocate, mint/burn for rebalancing
    bool public capitalPaused;
    /// @dev Address of the Dryp token.
    Dryp public _dryp;
    bytes32 internal constant TREASURY_MANAGER = keccak256("TREASURY_MANAGER_1");


    function setAdminImpl(address newImpl) external onlyRole(TREASURY_MANAGER) {
        require(newImpl != address(0), "new implementation is not a contract");
        _setImplementation(newImpl);
    }

    function _setImplementation(address newImpl) private {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImpl)
        }
    }

    function getImplementation() external view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

}
