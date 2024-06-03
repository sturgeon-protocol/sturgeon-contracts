// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

//import {console} from "forge-std/Test.sol";
import "../../src/interfaces/ITetuLiquidator.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract MockTetuLiquidator is ITetuLiquidator {
    address public controller = address(0);

    mapping(address tokenIn => mapping(address tokenOut => uint price)) public prices;

    function addLargestPools(PoolData[] memory _pools, bool rewrite) external {}

    function setPrice(address tokenIn, address tokenOut, uint price) external {
        prices[tokenIn][tokenOut] = price;
    }

    function getPrice(address tokenIn, address tokenOut, uint amount) external view returns (uint) {
        if (amount == 0) {
            amount = 10 ** IERC20Metadata(tokenIn).decimals();
        }
        return prices[tokenIn][tokenOut] * amount / 10 ** IERC20Metadata(tokenIn).decimals();
    }

    function getPriceForRoute(PoolData[] memory route, uint amount) external view returns (uint) {}

    function isRouteExist(address tokenIn, address tokenOut) external view returns (bool) {}

    function buildRoute(
        address tokenIn,
        address tokenOut
    ) external view returns (PoolData[] memory route, string memory errorMessage) {}

    function liquidate(address tokenIn, address tokenOut, uint amount, uint /*priceImpactTolerance*/ ) external {
        //        console.log('liquidate tokenIn', IERC20Metadata(tokenIn).symbol());
        //        console.log('liquidate tokenOut', IERC20Metadata(tokenOut).symbol());
        if (amount == 0) {
            amount = 10 ** IERC20Metadata(tokenIn).decimals();
        }
        uint amountOut = prices[tokenIn][tokenOut] * amount / 10 ** IERC20Metadata(tokenIn).decimals();
        require(IERC20(tokenOut).balanceOf(address(this)) >= amountOut, "MockLiquidator: not enough balance");
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenOut).transfer(msg.sender, amountOut);
    }

    function liquidateWithRoute(PoolData[] memory route, uint amount, uint priceImpactTolerance) external {}
}
