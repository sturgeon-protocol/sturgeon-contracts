// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/Controller.sol";
import "../../src/IFO.sol";
import "../../src/Vesting.sol";
import "../../src/STGN.sol";
import "../../src/ControllableProxy.sol";
import "../../src/VeSTGN.sol";
import "../../src/MultiGauge.sol";
import "../../src/Factory.sol";
import "../../src/PerfFeeTreasury.sol";

library DeployLib {
    struct DeployParams {
        address governance;
        uint ifoRate;
        address[] vestingClaimant;
        uint[] vestingAmount;
        uint vestingPeriod;
        uint vestingCliff;
        address rewardToken; // PEARL
        address liquidator;
    }

    struct DeployPlatformVars {
        Controller c;
        IFO ifo;
        uint len;
        address[] vesting;
        STGN stgn;
        Factory factory;
        address perfFeeTreasury;
    }

    function deployPlatform(DeployParams memory params) internal returns (address controller) {
        DeployPlatformVars memory v;
        v.c = new Controller(params.governance);
        v.ifo = new IFO(params.ifoRate); // 12e17

        v.len = params.vestingClaimant.length;
        v.vesting = new address[](v.len);
        for (uint i; i < v.len; ++i) {
            v.vesting[i] = address(new Vesting());
        }

        v.stgn = new STGN(params.governance, address(v.ifo), 1e26, 5e25, v.vesting, params.vestingAmount);
        v.ifo.setup(address(v.c), address(v.stgn), params.rewardToken);

        for (uint i; i < v.len; ++i) {
            Vesting(v.vesting[i]).setup(
                address(v.stgn), params.vestingPeriod, params.vestingCliff, params.vestingClaimant[i]
            );
        }

        ControllableProxy proxy = new ControllableProxy();
        address impl = address(new VeSTGN());
        proxy.initProxy(impl);
        VeSTGN ve = VeSTGN(address(proxy));
        ve.init(address(v.stgn), 1e18, address(v.c));
        // assertEq(IProxyControlled(proxy).implementation(), impl);

        proxy = new ControllableProxy();
        impl = address(new MultiGauge());
        proxy.initProxy(impl);
        MultiGauge multigauge = MultiGauge(address(proxy));
        multigauge.init(address(v.c), /* address(ve),*/ address(v.stgn));

        proxy = new ControllableProxy();
        impl = address(new Factory());
        proxy.initProxy(impl);
        v.factory = Factory(address(proxy));
        v.factory.init(address(v.c));

        v.perfFeeTreasury = address(new PerfFeeTreasury(params.governance));

        v.c.setup(
            v.perfFeeTreasury, address(v.factory), address(v.ifo), address(ve), address(v.stgn), address(multigauge), params.liquidator
        );

        return address(v.c);
    }

    function testDeployLib() external {}
}
