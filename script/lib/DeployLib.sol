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

library DeployLib {
    struct DeployParams {
        address governance;
        uint ifoRate;
        address[] vestingClaimant;
        uint[] vestingAmount;
        uint vestingPeriod;
        uint vestingCliff;
        address rewardToken; // PEARL
    }

    function deployPlatform(DeployParams memory params) external returns (address controller) {
        Controller _c = new Controller(params.governance);
        IFO ifo = new IFO(params.ifoRate); // 12e17

        uint len = params.vestingClaimant.length;
        address[] memory vesting = new address[](len);
        for (uint i; i < len; ++i) {
            vesting[i] = address(new Vesting());
        }

        STGN stgn = new STGN(params.governance, address(ifo), 1e26, 5e25, vesting, params.vestingAmount);
        ifo.setup(address(_c), address(stgn), params.rewardToken);

        for (uint i; i < len; ++i) {
            Vesting(vesting[i]).setup(
                address(stgn), params.vestingPeriod, params.vestingCliff, params.vestingClaimant[i]
            );
        }

        ControllableProxy proxy = new ControllableProxy();
        address impl = address(new VeSTGN());
        proxy.initProxy(impl);
        VeSTGN ve = VeSTGN(address(proxy));
        ve.init(address(stgn), 1e18, address(_c));
        //        assertEq(IProxyControlled(proxy).implementation(), impl);

        proxy = new ControllableProxy();
        impl = address(new MultiGauge());
        proxy.initProxy(impl);
        MultiGauge multigauge = MultiGauge(address(proxy));
        multigauge.init(address(_c), address(ve), address(stgn));

        _c.setup(address(ifo), address(ve), address(stgn), address(multigauge));

        return address(_c);
    }
}
