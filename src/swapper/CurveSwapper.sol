// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {ISwapper} from "../interfaces/ISwapper.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract CurveSwapper is ISwapper {
    using SafeTransferLib for ERC20;
    ICurvePool public STGPOOL;
    ERC20 public STG;
    ERC20 public USDC;
    address public vault;

    constructor(
        address _vault,
        address _STGPOOL,
        ERC20 _STG,
        ERC20 _USDC
    ) {
        vault = _vault;
        STGPOOL = ICurvePool(_STGPOOL);
        STG = _STG;
        USDC = _USDC;
        ERC20(_STG).safeApprove(address(STGPOOL), type(uint256).max);
    }

    function onSwapReceived(bytes calldata) public {
        uint256 received = STGPOOL.exchange(
            0,
            1,
            STG.balanceOf(address(this)),
            0
        );
        USDC.safeTransfer(vault, received);
    }
}
