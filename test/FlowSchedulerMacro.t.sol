// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.23;

import { FoundrySuperfluidTester } from "@superfluid-finance/ethereum-contracts/test/foundry/FoundrySuperfluidTester.t.sol";
import { FlowSchedulerMacro } from "../src/FlowSchedulerMacro.sol";
import { FlowScheduler } from "@superfluid-finance/automation-contracts/scheduler/contracts/FlowScheduler.sol";
import { IFlowScheduler } from "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IFlowScheduler.sol";
import { ISuperfluid, BatchOperation } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract FlowSchedulerMacroTest is FoundrySuperfluidTester {
    FlowScheduler internal flowScheduler;
    FlowSchedulerMacro internal schedulerMacro;

    constructor() FoundrySuperfluidTester(3) {}

    function setUp() public virtual override {
        super.setUp();
        flowScheduler = new FlowScheduler(sf.host);
        schedulerMacro = new FlowSchedulerMacro(IFlowScheduler(address(flowScheduler)));
    }

    function _makeCfsParams(
        uint32 startDate,
        uint32 startMaxDelay,
        int96 flowRate,
        uint256 startAmount,
        uint32 endDate,
        bytes memory userData
    ) internal view returns (FlowSchedulerMacro.CreateFlowScheduleParams memory) {
        return FlowSchedulerMacro.CreateFlowScheduleParams({
            superToken: superToken,
            receiver: bob,
            startDate: startDate,
            startMaxDelay: startMaxDelay,
            flowRate: flowRate,
            startAmount: startAmount,
            endDate: endDate,
            userData: userData
        });
    }

    function _assertSchedule(address sender, FlowSchedulerMacro.CreateFlowScheduleParams memory cfsParams)
        internal
        view
    {
        IFlowScheduler.FlowSchedule memory schedule =
            flowScheduler.getFlowSchedule(address(superToken), sender, bob);
        assertEq(schedule.flowRate, cfsParams.flowRate, "flowRate mismatch");
        assertEq(schedule.startDate, cfsParams.startDate, "startDate mismatch");
        assertEq(schedule.endDate, cfsParams.endDate, "endDate mismatch");
        assertEq(schedule.startMaxDelay, cfsParams.startMaxDelay, "startMaxDelay mismatch");
        assertEq(schedule.startAmount, cfsParams.startAmount, "startAmount mismatch");
        bytes32 expectedUserData =
            cfsParams.userData.length != 0 ? keccak256(cfsParams.userData) : bytes32(0);
        assertEq(schedule.userData, expectedUserData, "userData mismatch");
    }

    function _encodeParams(
        uint32 startDate,
        uint32 startMaxDelay,
        int96 flowRate,
        uint256 startAmount,
        uint32 endDate,
        bytes memory userData
    ) internal view returns (bytes memory) {
        return abi.encode(_makeCfsParams(startDate, startMaxDelay, flowRate, startAmount, endDate, userData));
    }

    function testBuildBatchOperationsSmoke() public view {
        uint32 startDate = uint32(block.timestamp + 1);
        uint32 endDate = startDate + 3600;
        bytes memory params = _encodeParams(startDate, 60, int96(1000), 0, endDate, "");

        ISuperfluid.Operation[] memory operations = schedulerMacro.buildBatchOperations(sf.host, params, alice);

        assertEq(operations.length, 1);
        assertEq(operations[0].operationType, BatchOperation.OPERATION_TYPE_SUPERFLUID_CALL_APP_ACTION);
        assertEq(operations[0].target, address(flowScheduler));
    }

    function testScheduleViaBatchSmoke() public {
        uint32 startDate = uint32(block.timestamp + 1);
        uint32 endDate = startDate + 3600;
        FlowSchedulerMacro.CreateFlowScheduleParams memory cfsParams =
            _makeCfsParams(startDate, 60, int96(1000), 0, endDate, "");

        ISuperfluid.Operation[] memory operations =
            schedulerMacro.buildBatchOperations(sf.host, abi.encode(cfsParams), alice);
        vm.prank(alice);
        sf.host.batchCall(operations);

        _assertSchedule(alice, cfsParams);
    }
}
