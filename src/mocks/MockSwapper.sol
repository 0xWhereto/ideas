// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ISwapper} from "../interfaces/ISwapper.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockSwapper {
    address vault;

    constructor(address _vault) {
        vault = _vault;
    }

    function onSwapReceived(bytes calldata data) public {
        ERC20 token = abi.decode(data, (ERC20));
        token.transfer(vault, token.balanceOf(address(this)));
    }
}
