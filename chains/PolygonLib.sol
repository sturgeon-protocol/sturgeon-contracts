// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {console} from "forge-std/Test.sol";
import "../script/lib/DeployLib.sol";

library PolygonLib {
    address public constant TOKEN_PEARL = 0x7238390d5f6F64e67c3211C343A410E2A3DEc142;

    function runDeploy(bool showLog) internal {
        address governance = 0x520Ab98a23100369E5280d214799b1E1c0123045;
        address[] memory vestingClaimant = new address[](3);
        uint[] memory vestingAmount = new uint[](3);
        vestingClaimant[0] = 0x520Ab98a23100369E5280d214799b1E1c0123045; // Claw
        vestingClaimant[1] = 0xe25e4df0432Ea55Fd76816fD8d4A21226dEE4bFF; // Minion
        vestingClaimant[2] = 0xcc16d636dD05b52FF1D8B9CE09B09BC62b11412B; // Tetu
        vestingAmount[0] = 375_000e18;
        vestingAmount[1] = 375_000e18;
        vestingAmount[1] = 250_000e18;

        Controller _c = Controller(DeployLib.deployPlatform(DeployLib.DeployParams({
            governance: governance,
            ifoRate: 12e17,
            vestingClaimant: vestingClaimant,
            vestingAmount:  vestingAmount,
            vestingPeriod: 365 days,
            vestingCliff: 180 days,
            rewardToken: TOKEN_PEARL
        })));

        if (showLog) {
            console.log('Deployed. Controller:', address(_c));
        }
    }
}
