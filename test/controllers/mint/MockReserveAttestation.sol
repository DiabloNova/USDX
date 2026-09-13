// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IReserveAttestation} from "../../../src/interfaces/reserve/IReserveAttestation.sol";

contract MockReserveAttestation is IReserveAttestation {
    ReserveData private _data;
    bool public shouldRevert;

    constructor(uint256 amount, uint256 timestamp, bool isAvailable, bool isStale) {
        _data = ReserveData({
            amount: amount,
            timestamp: timestamp,
            isAvailable: isAvailable,
            isStale: isStale
        });
    }

    function setReserveData(uint256 amount, uint256 timestamp, bool isAvailable, bool isStale) external {
        _data = ReserveData({
            amount: amount,
            timestamp: timestamp,
            isAvailable: isAvailable,
            isStale: isStale
        });
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function getAcceptedEligibleReserves() external view override returns (ReserveData memory) {
        if (shouldRevert) {
            revert("Oracle contract failure");
        }
        return _data;
    }
}
