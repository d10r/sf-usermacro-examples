// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { FlowSchedulerMacro, FlowScheduler712Macro } from "../src/FlowSchedulerMacro.sol";
import { IFlowScheduler } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IFlowScheduler.sol";

/**
 * Deploy FlowSchedulerMacro and FlowScheduler712Macro.
 *
 * Set FLOW_SCHEDULER_ADDRESS for the target chain, e.g.:
 *   OP Sepolia: 0x73B1Ce21d03ad389C2A291B1d1dc4DAFE7B5Dc68
 *
 * Run:
 *   forge script script/DeployFlowSchedulerMacro.s.sol --rpc-url <RPC_URL> --broadcast --chain-id <CHAIN_ID>
 */
contract DeployFlowSchedulerMacro is Script {
    function run() external {
        address flowSchedulerAddress = vm.envAddress("FLOW_SCHEDULER_ADDRESS");
        IFlowScheduler flowScheduler = IFlowScheduler(flowSchedulerAddress);

        vm.startBroadcast();

        FlowSchedulerMacro schedulerMacro = new FlowSchedulerMacro(flowScheduler);
        FlowScheduler712Macro scheduler712Macro = new FlowScheduler712Macro(flowScheduler);

        vm.stopBroadcast();

        console.log("FlowSchedulerMacro    deployed at:", address(schedulerMacro));
        console.log("FlowScheduler712Macro deployed at:", address(scheduler712Macro));
    }
}
