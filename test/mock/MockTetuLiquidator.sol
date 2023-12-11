// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "../../src/interfaces/ITetuLiquidator.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockTetuLiquidator is ITetuLiquidator {
    function getPrice(address tokenIn, address tokenOut, uint amount) external view returns (uint) {}

    function getPriceForRoute(PoolData[] memory route, uint amount) external view returns (uint) {}

    function isRouteExist(address tokenIn, address tokenOut) external view returns (bool) {}

    function buildRoute(
        address tokenIn,
        address tokenOut
    ) external view returns (PoolData[] memory route, string memory errorMessage) {}

    function liquidate(
        address tokenIn,
        address tokenOut,
        uint amount,
        uint /*priceImpactTolerance*/
    ) external {
        uint amountOut = amount / 10;
        require(IERC20(tokenOut).balanceOf(address(this)) >= amountOut, "MockLiquidator: not enough balance");
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenOut).transfer(msg.sender, amountOut);
    }

    function liquidateWithRoute(
        PoolData[] memory route,
        uint amount,
        uint priceImpactTolerance
    ) external {}
}