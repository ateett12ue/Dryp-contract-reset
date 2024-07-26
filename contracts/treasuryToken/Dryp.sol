// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title DRYP Token Contract
 * @dev ERC20 compatible contract for DRYP
 * @dev Implements an elastic supply
 * @author Ateet Tiwari
 */
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UtilMath } from "../utils/UtilMath.sol";
// import {ReentrancyGuard} from "../../utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Dryp is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using UtilMath for uint256;

    event TotalSupplyMinted(
        uint256 totalSupply,
        address account
    );

    event LockedSupplyUpdated(
        uint256 totalLockedSupply,
        uint256 updatedSupply,
        address account
    );

    event PoolTransfer(
        uint256 totalSupply,
        uint256 totalLockedSupply,
        uint256 amount,
        address account
    );

    struct TokenCredit{
        uint256 value;
        uint256 epocTime;
    }

    event PausableStateUpdated(bool updatedState, bool lastState, address account);

    event TreasuryDataUpdated(address admin, uint8 updateType, address account);

    uint256 private constant MAX_SUPPLY = ~uint128(0); // (2^128) - 1
    uint256 private constant RESOLUTION_INCREASE = 1e9;

    uint256 public _totalSupply;
    uint256 public _mintTreshold;
    uint256 private _redeemCreditBalance;
    uint256 private _nonredeemCreditBalance;
    address public treasuryAddress;
    address public treasuryManagerAddress;
    address public admin;
    uint256 public totalLockedSupply;
    

    mapping(address => TokenCredit) private _redeemCreditBalancesUpdated;
    mapping(address => TokenCredit) private _nonredeemCreditBalancesUpdated;
    mapping(address => uint256) private _creditBalances;
    mapping(address => uint256) public isUpgraded;
    // constructor() {
    //     _disableInitializers();
    // }
    
    function initialize(
        string calldata _nameArg,
        string calldata _symbolArg
    ) initializer public {
        __ERC20_init(_nameArg, _symbolArg);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        treasuryManagerAddress = msg.sender;
        admin = msg.sender;
        _totalSupply = 1000000 * (10 ** uint256(18));
        _mintTreshold = 10000 * (10 ** uint256(18));
        treasuryAddress = address(0);
        _redeemCreditBalance = 1;
        _nonredeemCreditBalance = 0;
        totalLockedSupply = 0;
        _mint(msg.sender, 1000 * 10 ** decimals());
    }

    /**
     * @dev Verifies that the caller is the Treasury Manager Contract
     */
    modifier onlyTreasuryManager() {
        require(treasuryManagerAddress == msg.sender, "Caller is not the Treasury Manager");
        _;
    }
    /**
     * @dev Verifies that the caller is the Treasury Manager Contract
     */
    modifier onlyAdmin() {
        require(admin == msg.sender, "Caller is not the Admin");
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @return The total supply of DRYP.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function lockSupply() public view returns (uint256) {
        return totalLockedSupply;
    }

    function mint(address to, uint256 amount) public onlyTreasuryManager {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20PausableUpgradeable,ERC20Upgradeable)
    {
        require(_totalSupply > amount, "amount more than total supply");
        require(_mintTreshold >= amount, "amount more than mint thresold supply");
        _totalSupply -= amount;
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Burns tokens, decreasing totalSupply.
     */
    function burn(address account, uint256 amount) external onlyTreasuryManager {
        _burn(account, amount);
    }



    /**
     * @dev Modify the supply without minting new tokens. This uses a change in
     *      the exchange rate between "credits" and OUSD tokens to change balances.
     * @param _newTotalSupply New total supply of OUSD.
     */
    function changeSupply(uint256 _newTotalSupply)
        external
        onlyTreasuryManager
        nonReentrant
    {
        require(_totalSupply > 0, "Cannot increase 0 supply");

        _totalSupply = _newTotalSupply > MAX_SUPPLY
            ? MAX_SUPPLY
            : _newTotalSupply;

        emit TotalSupplyMinted(
                _totalSupply,
                msg.sender
        );
            
    }

    function updateTreasuryAddress(address newTreasuryAddress)
        external
        onlyTreasuryManager
        nonReentrant

    {
        require(!paused(), "Cannot update in pause state");

        treasuryAddress = newTreasuryAddress;

        emit TreasuryDataUpdated(
                msg.sender,
                0,
                newTreasuryAddress
        );  
    }

     function updateTreasuryManagerAddress(address newAddress)
        external
        onlyTreasuryManager
        nonReentrant
    {
        require(!paused(), "Cannot update in pause state");

        treasuryManagerAddress = newAddress;

        emit TreasuryDataUpdated(
                msg.sender,
                1,
                newAddress
        );  
    }

     function updateAdmin(address newAddress)
        external
        onlyTreasuryManager
        nonReentrant
    {
        admin = newAddress;
        emit TreasuryDataUpdated(
                msg.sender,
                2,
                newAddress
        );  
    }

    function getRedeemCredit()
        public
        view
        returns(uint256)
    {
       return _redeemCreditBalance;
    }

    function getNonRedeemCredit(address newAddress)
        public
        view
        returns(uint256)
    {
       return _nonredeemCreditBalance;
    }

    function updateRedeemCredit(uint256 newValue)
        external
        nonReentrant
        onlyTreasuryManager
    {
        _redeemCreditBalancesUpdated[msg.sender]= TokenCredit({
            value: newValue,
            epocTime: block.timestamp
        });
       _redeemCreditBalance = newValue;
    }

    function updateNonRedeemCredit(uint256 newValue)
        external
        nonReentrant
        onlyTreasuryManager
    {
        _nonredeemCreditBalancesUpdated[msg.sender]= TokenCredit({
            value: newValue,
            epocTime: block.timestamp
        });
       _nonredeemCreditBalance = newValue;
    }
}
