// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";


contract STGN is ERC20Permit {
    uint internal constant SUPPLY = 1e23;
    uint internal constant IFO_SHARE = 50;
    uint internal constant VESTING_SHARE = 30;

    constructor(address governance, address ifo, address vesting) ERC20("Sturgeon", "STGN") ERC20Permit("Sturgeon") {
        uint ifoSupply = SUPPLY * IFO_SHARE / 100;
        uint vestingSupply = SUPPLY * VESTING_SHARE / 100;
        _mint(ifo, ifoSupply);
        _mint(vesting, vestingSupply);
        _mint(governance, SUPPLY - ifoSupply - vestingSupply);
    }
}
