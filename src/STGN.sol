// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./interfaces/ISTGN.sol";

contract STGN is ERC20Permit, ISTGN {
    address[] internal _vesting;

    constructor(
        address governance,
        address ifo,
        uint supply,
        uint ifoSupply,
        address[] memory vesting_,
        uint[] memory vestingAmount
    ) ERC20("Sturgeon", "STGN") ERC20Permit("Sturgeon") {
        uint vestingSupply;
        _vesting = vesting_;
        _mint(ifo, ifoSupply);

        uint len = vesting_.length;
        for (uint i; i < len; ++i) {
            _mint(vesting_[i], vestingAmount[i]);
            vestingSupply += vestingAmount[i];
        }
        _mint(governance, supply - ifoSupply - vestingSupply);
    }

    function vesting() external view returns (address[] memory) {
        return _vesting;
    }
}
