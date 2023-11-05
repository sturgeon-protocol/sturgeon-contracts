// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/Controller.sol";
import "../../src/ControllableProxy.sol";
import "../../src/IFO.sol";
import "../../src/STGN.sol";
import "../../src/VeSTGN.sol";
import "../../src/PerfFeeTreasury.sol";
import "../../src/VeDistributor.sol";
import "../../src/Vesting.sol";

abstract contract MockSetup is Test {
    Controller public controller;

    constructor() {
        controller = _init();
    }

    function _init() public returns (Controller) {
        address gov = address(this);

        Controller _c = new Controller(gov);
        IFO ifo = new IFO(12e17);
        Vesting vesting = new Vesting();
        STGN stgn = new STGN(gov, address(ifo), address(vesting));
        ifo.setup(address(stgn));

        // todo who is claimant?
        vesting.setup(address(stgn), 365 days, 30 days, gov);

        ControllableProxy proxy = new ControllableProxy();
        address impl = address(new VeSTGN());
        proxy.initProxy(impl);
        VeSTGN ve = VeSTGN(address(proxy));
        ve.init(address(stgn), 1e18, address(_c));
        assertEq(IProxyControlled(proxy).implementation(), impl);

        _c.setup(address(ifo), address(vesting), address(ve));

        return _c;
    }
}
