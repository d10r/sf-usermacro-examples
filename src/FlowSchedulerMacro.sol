// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.23;

import { ISuperfluid, BatchOperation } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IUserDefinedMacro, IUserDefined712Macro } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/utils/IUserDefinedMacro.sol";
import { IFlowScheduler } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IFlowScheduler.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { FlowRateFormatter, AmountFormatter, RelativeTimeFormatter } from "./utils/FormattingLibs.sol";
import { Strings } from "@openzeppelin-v5/contracts/utils/Strings.sol";

using FlowRateFormatter for int96;

/**
 * Macro that schedules a flow via a FlowScheduler (createFlowSchedule).
 * The FlowScheduler address is fixed at deployment (constructor). All other
 * arguments are user-provided via params.
 */
contract FlowSchedulerMacro is IUserDefinedMacro {

    struct CreateFlowScheduleParams {
        ISuperToken superToken;
        address receiver;
        uint32 startDate;
        uint32 startMaxDelay;
        int96 flowRate;
        uint256 startAmount;
        uint32 endDate;
        bytes userData;
    }

    IFlowScheduler public immutable FLOW_SCHEDULER;

    constructor(IFlowScheduler flowScheduler_) {
        FLOW_SCHEDULER = flowScheduler_;
    }

    // invoked by the MacroForwarder to build the batch operations from the encoded params
    function buildBatchOperations(
        ISuperfluid /* host */,
        bytes memory params,
        address /*msgSender*/
    ) external view override returns (ISuperfluid.Operation[] memory operations) {
        CreateFlowScheduleParams memory cfsParams = _decodeCreateFlowScheduleParams(params);

        bytes memory callData = abi.encodeCall(
            IFlowScheduler.createFlowSchedule,
            (
                cfsParams.superToken,
                cfsParams.receiver,
                cfsParams.startDate,
                cfsParams.startMaxDelay,
                cfsParams.flowRate,
                cfsParams.startAmount,
                cfsParams.endDate,
                cfsParams.userData,
                new bytes(0) // ctx placeholder; host replaces with actual ctx
            )
        );

        operations = new ISuperfluid.Operation[](1);
        operations[0] = ISuperfluid.Operation({
            operationType: BatchOperation.OPERATION_TYPE_SUPERFLUID_CALL_APP_ACTION,
            target: address(FLOW_SCHEDULER),
            data: callData
        });
    }

    function _decodeCreateFlowScheduleParams(bytes memory params)
        internal virtual pure
        returns (CreateFlowScheduleParams memory cfsParams)
    {
        cfsParams = abi.decode(params, (CreateFlowScheduleParams));
    }

    function postCheck(ISuperfluid, bytes memory params, address msgSender) external view override {
        // verify that the schedule exists
        CreateFlowScheduleParams memory cfsParams = _decodeCreateFlowScheduleParams(params);
        IFlowScheduler.FlowSchedule memory schedule =
            FLOW_SCHEDULER.getFlowSchedule(address(cfsParams.superToken), msgSender, cfsParams.receiver);
        require(schedule.flowRate == cfsParams.flowRate, "schedule not created");
    }
}

/*
* The EIP712 variant additionally has a language parameter in front of the params.
* The description string which is part of the signed data is not part of the params, but deterministically derived from it.
*/
contract FlowScheduler712Macro is FlowSchedulerMacro, IUserDefined712Macro {
    error UnsupportedLanguage();

    bytes internal constant _ACTION_TYPE_DEFINITION =
        "Action(string description,address superToken,address receiver,uint32 startDate,uint32 startMaxDelay,int96 flowRate,uint256 startAmount,uint32 endDate,bytes userData)";

    constructor(IFlowScheduler flowScheduler_) FlowSchedulerMacro(flowScheduler_) {}

    // IUserDefined712Macro.getPrimaryTypeName
    function getPrimaryTypeName(bytes memory /* params */) external pure override returns (string memory) {
        return "ScheduleFlow";
    }

    // IUserDefined712Macro.getActionTypeDefinition
    function getActionTypeDefinition(bytes memory /* params */) external pure override returns (string memory) {
        return string(_ACTION_TYPE_DEFINITION);
    }

    // IUserDefined712Macro.getActionStructHash
    function getActionStructHash(bytes memory params) public view override returns (bytes32) {
        (
            bytes32 lang,
            CreateFlowScheduleParams memory cfsParams
        ) = abi.decode(
            params,
            (bytes32, CreateFlowScheduleParams)
        );
        (, bytes32 structHash) = _getCreateFlowScheduleStructDescriptionAndHash(lang, cfsParams);
        return structHash;
    }

    function _getCreateFlowScheduleStructDescriptionAndHash(bytes32 lang, CreateFlowScheduleParams memory cfsParams)
        internal view returns (string memory description, bytes32 structHash)
    {
        // the message is constructed based on the selected language and action arguments
        if (lang == "en") {
            string memory timeFragment;
            if (cfsParams.startDate != 0 && cfsParams.endDate != 0) {
                timeFragment = string.concat(
                    " starting ",
                    RelativeTimeFormatter.formatFromNow(cfsParams.startDate),
                    " and stopping ",
                    RelativeTimeFormatter.formatFromNow(cfsParams.endDate)
                );
            } else if (cfsParams.startDate != 0) {
                timeFragment = string.concat(" starting ", RelativeTimeFormatter.formatFromNow(cfsParams.startDate));
            } else if (cfsParams.endDate != 0) {
                timeFragment = string.concat(" stopping ", RelativeTimeFormatter.formatFromNow(cfsParams.endDate));
            } else {
                timeFragment = "";
            }
            string memory amountFragment = cfsParams.startAmount == 0
                ? ""
                : string.concat(
                    " with an initial transfer of ",
                    AmountFormatter.formatTokenAmount(cfsParams.startAmount, 5),
                    " ",
                    cfsParams.superToken.symbol()
                );
            description = string.concat(
                "Create flow schedule of ",
                cfsParams.flowRate.toDailyFlowRateString(),
                " ",
                cfsParams.superToken.symbol(),
                "/day to ",
                Strings.toHexString(cfsParams.receiver),
                timeFragment,
                amountFragment
            );
        } else {
            revert UnsupportedLanguage();
        }

        structHash = keccak256(abi.encode(
            keccak256(_ACTION_TYPE_DEFINITION),
            keccak256(bytes(description)),
            address(cfsParams.superToken),
            cfsParams.receiver,
            cfsParams.startDate,
            cfsParams.startMaxDelay,
            cfsParams.flowRate,
            cfsParams.startAmount,
            cfsParams.endDate,
            keccak256(cfsParams.userData)
        ));
    }

    function encodeCreateFlowScheduleParams(bytes32 lang, CreateFlowScheduleParams memory cfsParams)
        external view
        returns(string memory description, bytes memory params, bytes32 structHash)
    {
        params = abi.encode(lang, cfsParams);
        (description, structHash) = _getCreateFlowScheduleStructDescriptionAndHash(lang, cfsParams);
    }

    function _decodeCreateFlowScheduleParams(bytes memory params)
        internal override pure
        returns (CreateFlowScheduleParams memory cfsParams)
    {
        (,cfsParams) = abi.decode(params, (bytes32, CreateFlowScheduleParams));
    }
}