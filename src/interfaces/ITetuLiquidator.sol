// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {ILiquidatorControllable} from "./ILiquidatorControllable.sol";

interface ITetuLiquidator is ILiquidatorControllable {
    struct PoolData {
        address pool;
        address swapper;
        address tokenIn;
        address tokenOut;
    }

    function addLargestPools(PoolData[] memory _pools, bool rewrite) external;

    function getPrice(address tokenIn, address tokenOut, uint amount) external view returns (uint);

    function getPriceForRoute(PoolData[] memory route, uint amount) external view returns (uint);

    function isRouteExist(address tokenIn, address tokenOut) external view returns (bool);

    function buildRoute(
        address tokenIn,
        address tokenOut
    ) external view returns (PoolData[] memory route, string memory errorMessage);

    function liquidate(address tokenIn, address tokenOut, uint amount, uint priceImpactTolerance) external;

    function liquidateWithRoute(PoolData[] memory route, uint amount, uint priceImpactTolerance) external;
}
