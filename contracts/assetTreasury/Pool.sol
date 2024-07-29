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

    function _getDrypDollar(uint256 inAmount, address from) public view returns(uint256){
        (uint256 reserve0, uint256 reserve1,) = _drypPoolPositionManager.getReserves();
        address token0 = _drypPoolPositionManager.token0();
        uint outAmount = 0;
        if(from == token0)
        {
            outAmount = _drypPoolPositionManager.quote(inAmount, reserve0, reserve1);
        }
        else {
            outAmount = _drypPoolPositionManager.quote(inAmount, reserve1, reserve0);
        }
        return outAmount;
    }
}
