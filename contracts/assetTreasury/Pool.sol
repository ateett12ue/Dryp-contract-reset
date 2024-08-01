// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPancakeswapV2PositionManager} from "../interfaces/IPancakeSwap.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
contract PancakeswapHelpers is Initializable {
    IPancakeswapV2PositionManager
        public _drypPoolPositionManager;
    function __Pool_init(address __nonFungiblePositionManager) internal onlyInitializing {
        _drypPoolPositionManager = IPancakeswapV2PositionManager(
                    __nonFungiblePositionManager
                );
    }

    function _getDrypDollar(uint256 inAmount, address from) public view returns(uint256 outAmount){
        (uint112 reserve0, uint112 reserve1,) = _drypPoolPositionManager.getReserves();
        address token0 = _drypPoolPositionManager.token0();
        uint256 reserve0_256 = uint256(reserve0);
        uint256 reserve1_256 = uint256(reserve1);
        if (from == token0) {
            require(reserve0_256 > 0, "No liquidity for token0");
            outAmount = (inAmount * reserve1_256) / reserve0_256;
        } else {
            require(reserve1_256 > 0, "No liquidity for token1");
            outAmount = (inAmount * reserve0_256) / reserve1_256;
        }
    }
}
