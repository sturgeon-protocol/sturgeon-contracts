// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {console} from "forge-std/Test.sol";
import "../script/lib/DeployLib.sol";

library UnrealLib {
    // Unreal tokens
    address public constant TOKEN_USDC = 0xabAa4C39cf3dF55480292BBDd471E88de8Cc3C97;
    address public constant TOKEN_DAI = 0x665D4921fe931C0eA1390Ca4e0C422ba34d26169;
    address public constant TOKEN_PEARL = 0xCE1581d7b4bA40176f0e219b2CaC30088Ad50C7A;
    address public constant TOKEN_CVR = 0xC0Fd0e8d5c3Bdc2C06b2Ee9FfE81ceCbE1B59364;

    // Pearl DeX
    address public constant POOL_PEARL_CVR_3000 = 0x6592E84E1903B990C5015F1Ff1A6cc27405EABfB;
    address public constant POOL_DAI_USDC_1000 = 0x1933cB66cB5A2b47A93753773C556ab6CA825831;
    address public constant POOL_DAI_PEARL_3000 = 0xeC491B6bC5554f76348FB40eEfbf0Ed60cd22Bd2;
    address public constant POOL_PEARL_USDC_3000 = 0xd7e172f7e2F60B6438ffC2e52434150878644469;
    // Trident TDT-DAI-USDC
    address public constant LIQUID_BOX_DAI_USDC = 0xAB5a4189e947E0e3EbEc25637f73deb55f6CEEA9;

    // IGaugeV2ALM
    address public constant ALM_GAUGE_DAI_USDC = 0x54CbD289B263CD14E6707EcbDa01161c4385DFe3;

    // Sturgeon infrastructure
    address public constant LIQUIDATOR = 0xE0D142466d1BF88FE23D5D265d76068077E4D6F0;

    function runDeploy(bool showLog) internal returns(address) {
        address governance = 0x3d0c177E035C30bb8681e5859EB98d114b48b935; // test deployer
        address[] memory vestingClaimant = new address[](3);
        uint[] memory vestingAmount = new uint[](3);
        vestingClaimant[0] = 0x520Ab98a23100369E5280d214799b1E1c0123045; // Claw
        vestingClaimant[1] = 0xe25e4df0432Ea55Fd76816fD8d4A21226dEE4bFF; // Minion
        vestingClaimant[2] = 0xcc16d636dD05b52FF1D8B9CE09B09BC62b11412B; // Tetu
        vestingAmount[0] = 375_000e18;
        vestingAmount[1] = 375_000e18;
        vestingAmount[2] = 250_000e18;

        Controller _c = Controller(
            DeployLib.deployPlatform(
                DeployLib.DeployParams({
                    governance: governance,
                    ifoRate: 12e17,
                    vestingClaimant: vestingClaimant,
                    vestingAmount: vestingAmount,
                    vestingPeriod: 365 days,
                    vestingCliff: 180 days,
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

    function testA() public {}
}
