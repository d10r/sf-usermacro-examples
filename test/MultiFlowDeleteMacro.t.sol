// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { FoundrySuperfluidTester } from "@superfluid-finance/ethereum-contracts/test/foundry/FoundrySuperfluidTester.t.sol";
import { MultiFlowDeleteMacro } from "../src/MultiFlowDeleteMacro.sol";

contract MultiFlowDeleteMacroTest is FoundrySuperfluidTester {
    MultiFlowDeleteMacro internal multiFlowDeleteMacro;

    constructor() FoundrySuperfluidTester(3) {}

    function setUp() public override {
        super.setUp();
        multiFlowDeleteMacro = new MultiFlowDeleteMacro();
    }

    function test_buildBatchOperations_smoke() public view {
        address[] memory receivers = new address[](2);
        receivers[0] = bob;
        receivers[1] = carol;
        bytes memory params = multiFlowDeleteMacro.getParams(superToken, receivers);
        assertEq(multiFlowDeleteMacro.buildBatchOperations(sf.host, params, admin).length, 2);
    }
}
