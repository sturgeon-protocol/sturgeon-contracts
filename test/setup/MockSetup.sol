// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Controller.sol";
import "../../src/ControllableProxy.sol";
import "../../src/IFO.sol";
import "../../src/STGN.sol";
import "../../src/VeSTGN.sol";
import "../../src/PerfFeeTreasury.sol";
import "../../src/VeDistributor.sol";
import "../../src/Vesting.sol";
import "../../script/lib/DeployLib.sol";
import "../mock/MockERC20.sol";

abstract contract MockSetup is Test {
    Controller public controller;
    address public tokenA;
    address public tokenB;
    address public tokenC;

    constructor() {
        tokenA = address(new MockERC20('Mock Token A', 'MOCK_A', 18));
        tokenB = address(new MockERC20('Mock Token B', 'MOCK_B', 6));
        tokenC = address(new MockERC20('Mock Token C', 'MOCK_C', 18));
        controller = _init();
    }

    function _init() public returns (Controller) {
        address[] memory vestingClaimant = new address[](2);
        uint[] memory vestingAmount = new uint[](2);
        vestingClaimant[0] = address(1);
        vestingClaimant[1] = address(2);
        vestingAmount[0] = 1e24;
        vestingAmount[1] = 2e24;

        Controller _c = Controller(
            DeployLib.deployPlatform(
                DeployLib.DeployParams({
                    governance: address(this),
                    ifoRate: 12e17,
                    vestingClaimant: vestingClaimant,
                    vestingAmount: vestingAmount,
                    vestingPeriod: 365 days,
                    vestingCliff: 30 days,
                    rewardToken: tokenC
                })
            )
        );

        return _c;
    }

    function testMockSetup() public {}
}
