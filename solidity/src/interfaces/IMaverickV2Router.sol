// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {ICallbackOperations} from "./ICallbackOperations.sol";
import {IPushOperations} from "./IPushOperations.sol";
import {IPayment} from "./IPayment.sol";
import {IChecks} from "./IChecks.sol";

/* solhint-disable no-empty-blocks */
interface IMaverickV2Router is
    IPayment,
    IChecks,
    ICallbackOperations,
    IPushOperations
{}
