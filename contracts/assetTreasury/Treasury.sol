// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  Treasury Contract
 * @author Ateet Tiwari
 */
import { TreasuryCore } from "./TreasuryCore.sol";
import { TreasuryController } from "./TreasuryControl.sol";
import { TreasuryBase } from "./TreasuryBase.sol";

contract Treasury is TreasuryCore, TreasuryController, TreasuryBase {}
