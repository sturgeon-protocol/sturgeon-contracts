// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {console} from "forge-std/Test.sol";
import "../script/lib/DeployLib.sol";
import "../test/mock/MockTetuLiquidator.sol";

library TestnetLib {
    address public constant TOKEN_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;

    function runDeploy(bool showLog) internal returns(address) {
        address governance = 0x3d0c177E035C30bb8681e5859EB98d114b48b935; // test deployer
        address[] memory vestingClaimant = new address[](3);
        uint[] memory vestingAmount = new uint[](3);
        vestingClaimant[0] = 0x520Ab98a23100369E5280d214799b1E1c0123045; // Claw
        vestingClaimant[1] = 0xe25e4df0432Ea55Fd76816fD8d4A21226dEE4bFF; // Minion
        vestingClaimant[2] = 0xcc16d636dD05b52FF1D8B9CE09B09BC62b11412B; // Tetu
        vestingAmount[0] = 375_000e18;
        vestingAmount[1] = 375_000e18;
        vestingAmount[1] = 250_000e18;

        MockTetuLiquidator l = new MockTetuLiquidator();

        Controller _c = Controller(
            DeployLib.deployPlatform(
                DeployLib.DeployParams({
                    governance: governance,
                    ifoRate: 12e17,
                    vestingClaimant: vestingClaimant,
                    vestingAmount: vestingAmount,
                    vestingPeriod: 365 days,
                    vestingCliff: 180 days,
                    rewardToken: TOKEN_WETH,
                    liquidator: address(l)
                })
            )
        );

        if (showLog) {
            console.log("Deployed. Controller:", address(_c));
        }

        return address(_c);
    }

    function testA() public {}
}
