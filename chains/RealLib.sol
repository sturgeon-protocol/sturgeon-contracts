// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {console} from "forge-std/Test.sol";
import "../script/lib/DeployLib.sol";

library RealLib {
    address public constant LIQUIDATOR = 0xE3f1d1B8ea9721FF0399cF6c2990A4bE5e4fc023;
    address public constant TOKEN_USTB = 0x83feDBc0B85c6e29B589aA6BdefB1Cc581935ECD;
    address public constant TOKEN_PEARL = 0xCE1581d7b4bA40176f0e219b2CaC30088Ad50C7A;
    address public constant TOKEN_WETH = 0x90c6E93849E06EC7478ba24522329d14A5954Df4; // reETH
    address public constant TOKEN_CVR = 0xB08F026f8a096E6d92eb5BcbE102c273A7a2d51C;
    address public constant GOVERNANCE = 0x6021e09b605F6423Fa348229255EeF79A25F35b8; // safe
    uint public constant VESTING_PERIOD = 365 days;
    uint public constant VESTING_CLIFF = 180 days;
    address public constant VESTING_CLAIMANT_1 = 0x520Ab98a23100369E5280d214799b1E1c0123045; // claw
    address public constant VESTING_CLAIMANT_2 = 0xe25e4df0432Ea55Fd76816fD8d4A21226dEE4bFF; // minion
    address public constant VESTING_CLAIMANT_3 = 0xc184a3ECcA684F2621c903A7943D85fA42F56671; // tetu
    uint public constant VESTING_AMOUNT_0 = 375_000e18;
    uint public constant VESTING_AMOUNT_1 = 375_000e18;
    uint public constant VESTING_AMOUNT_2 = 250_000e18;

    function runDeploy(bool showLog) internal returns(address) {
        address[] memory vestingClaimant = new address[](3);
        uint[] memory vestingAmount = new uint[](3);
        vestingClaimant[0] = VESTING_CLAIMANT_1;
        vestingClaimant[1] = VESTING_CLAIMANT_2;
        vestingClaimant[2] = VESTING_CLAIMANT_3;
        vestingAmount[0] = VESTING_AMOUNT_0;
        vestingAmount[1] = VESTING_AMOUNT_1;
        vestingAmount[2] = VESTING_AMOUNT_2;

        Controller _c = Controller(
            DeployLib.deployPlatform(
                DeployLib.DeployParams({
                    governance: GOVERNANCE,
                    ifoRate: 1e18,
                    vestingClaimant: vestingClaimant,
                    vestingAmount: vestingAmount,
                    vestingPeriod: VESTING_PERIOD,
                    vestingCliff: VESTING_CLIFF,
                    rewardToken: TOKEN_PEARL,
                    liquidator: LIQUIDATOR
                })
            )
        );

        if (showLog) {
            console.log("Deployed. Controller:", address(_c));
        }

        return address(_c);
    }

}
