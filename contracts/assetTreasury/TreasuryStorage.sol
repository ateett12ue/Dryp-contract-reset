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

contract TreasuryStorage is Initializable, AccessControl, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // for asset to be added and remove from treasury
    event AssetAdded(address _asset);
    event AssetRemoved(address _asset);

    // for asset to be added and remove from treasury
    event MintAssetAdded(address _asset);
    event MintAssetRemoved(address _asset);

    // for asset configs to be updated by rebalancer
    event AssetDefaultUpdatedByRebalancer(address _asset, address _rebalancer, uint256 percentage);
    event AssetAllocated(address _asset, address _rebalancer, uint256 _amount);

    // adding or removing new Rebalancer
    event RebalancerApproved(address _addr);
    event RebalancerRemoved(address _addr);

    // minting and redeem calls from treasury manager
    event Mint(address _addr, uint256 _value);
    event Redeem(address _addr, uint256 _value);

    // total treasury paused by treasury manager
    event CapitalPaused();
    event CapitalUnpaused();

    // rebasing paused by treasury manager
    event RebasePaused();
    event RebaseUnpaused();

    // redeem and unredeem buckets paused by treasury manager
    event RedeemBucketPaused();
    event RedeemBucketUnpaused();
    event NoredeemBucketPaused();
    event NoredeemBucketUnpaused();

    // redeem and unredeem threshold created by treasury manager
    event AssetRedeemThresholdUpdated(uint256 _redeemAllocated);
    event AssetNoRedeemThresholdUpdated(uint256 _noredeemAllocated);

    // timelock hit by treasury manager
    event TreasuryTimeLockUpdated(uint256 _treasuryTimeLock);

    // static contract rights updated
    event TreasuryMangerUpdated(address _address);
    event TreasuryAdminUpdated(address _address);
    event RevenueTresuryUpdated(address _revenueAddress);
    event TreasuryTokenUpdated(address _address);
    event TreasuryTokenPoolUpdated(address _address);
    // flipper contract
    event SwapperChanged(address _address);
    event Swapped(
        address indexed _fromAsset,
        address indexed _toAsset,
        uint256 _fromAssetAmount,
        uint256 _toAssetAmount
    );

    // DAI< USDT < USDC
    struct ExchangeToken{
        bool isSupported;
        bool allowed;
        address megaPool;
        uint8 decimals;
        uint256 maxAllowed;
        string symbol;
        uint256 priceInUsdt;
    }

    // ETH< WBTC < DAI < LINK -- AAVE TOKENS
    struct TreasuryAsset {
        bool isSupported;
        uint8 decimals;
        uint16 allotatedPercentange;
        uint256 priceInUsdt;
    }

bytes32 constant adminImplPosition =
        0xa161f5e5f89bcd6e5515698cf56639b955fbb2facc2be526b53b6fe50b4a8c27;

    address public _usdt;
    address public _usdc;

    address treasury_manager;
    /// @dev list of all assets supported by the treasury.
    mapping(address => TreasuryAsset) internal redeemBasketAssets;

    /// @dev list of all assets supported by the treasury in nonRedeemBasket.
    mapping(address => TreasuryAsset) internal unredeemBasketAssets;

    /// @dev list of all assets supported for swapping DRYP.
    mapping(address => ExchangeToken) internal mintTokens;

    /// @dev list of all assets supported for swapping DRYP.
    mapping(address => uint256) internal revenue;

    address[] public allAssets;

    bool public treasuryStarted;

    // Rebalancing Configs approved for use by the Vault
    struct Rebalancer {
        bool isSupported;
        uint256 _deprecated; // Deprecated storage slot
        uint256 _redeemBasketPercentage;
        uint256 _unredeemBasketPercentage;
    }

    /// @dev mapping of Rebalancing contracts to their configiration
    mapping(address => Rebalancer) internal rebalancing;

    /// @dev list of all treasury rebalancing
    address[] internal allRebalancingChanges;

    /// @notice pause rebasing if true
    bool public rebasePaused;

    /// @notice pause operations that change the DRYP supply.
    /// eg mint, redeem, allocate, mint/burn for rebalancing
    bool public capitalPaused;

    /// @notice Percentage of assets to kept in Vault to handle (most) withdrawals. 100% = 1e18. 10% by default
    uint256 public redeemBuffer;

    /// @notice Percentage of assets to kept in Vault to handle (most) withdrawals. 100% = 1e18. 90% by default
    uint256 public noredeemBuffer;

    /// @dev Address of the Dryp token.
    Dryp internal _dryp;

    /// @dev Address of the Dryp Pool Contract.
    address internal _drypPool;

    /// @dev Address of the Dryp Rebalancing only Redeem.
    Rebalancer internal _rebalancer;


    bytes32 public constant TREASURY_MANAGER = keccak256("TREASURY_MANAGER");

    uint256 public _totalValue;
    // constants
    uint256 constant MINT_MINIMUM_UNIT_PRICE = 0.998e18;
    uint256 constant MIN_UNIT_PRICE_DRIFT = 0.7e18;
    uint256 constant MAX_UNIT_PRICE_DRIFT = 1.3e18;

    // /**
    //  * @notice set the implementation for the admin, this needs to be in a base class else we cannot set it
    //  * @param newImpl address of the implementation
    //  */
    // function setAdminImpl(address newImpl) external onlyRole(TREASURY_MANAGER) {
    //     require(
    //         Address.isContract(newImpl),
    //         "new implementation is not a contract"
    //     );
    //     bytes32 position = keccak256(treasury_manager);
    //     assembly {
    //         sstore(position, newImpl)
    //     }
    // }
}
