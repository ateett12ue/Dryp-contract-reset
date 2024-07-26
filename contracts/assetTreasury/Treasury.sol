// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  Treasury Contract
 * @author Ateet Tiwari
 */
import { TreasuryInitializer } from "./TreasuryInitializer.sol";
import { TreasuryController } from "./TreasuryControl.sol";

contract Treasury is TreasuryInitializer, TreasuryController {}
