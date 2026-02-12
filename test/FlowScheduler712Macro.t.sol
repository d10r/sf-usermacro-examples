// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.23;

import { VmSafe } from "forge-std/Vm.sol";
import { IAccessControl } from "@openzeppelin-v5/contracts/access/IAccessControl.sol";
import { ISuperfluidToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { Only712MacroForwarder } from "@superfluid-finance/ethereum-contracts/contracts/utils/Only712MacroForwarder.sol";
import { FlowSchedulerMacroTest } from "./FlowSchedulerMacro.t.sol";
import { IFlowScheduler } from "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IFlowScheduler.sol";
import { FlowScheduler712Macro } from "../src/FlowSchedulerMacro.sol";
import { FlowSchedulerMacro } from "../src/FlowSchedulerMacro.sol";

bytes32 constant LANG_EN = bytes32("en");
string constant SECURITY_DOMAIN = "flowscheduler.xyz";
string constant SECURITY_PROVIDER = "macros.superfluid.eth";
uint256 constant DEFAULT_NONCE = uint256(1) << 64;

contract FlowScheduler712MacroTest is FlowSchedulerMacroTest {
    Only712MacroForwarder internal forwarder;
    FlowScheduler712Macro internal scheduler712Macro;

    function setUp() public override {
        super.setUp();
        scheduler712Macro = new FlowScheduler712Macro(IFlowScheduler(address(flowScheduler)));
        forwarder = new Only712MacroForwarder(sf.host);

        IAccessControl acl = IAccessControl(sf.host.getSimpleACL());
        vm.prank(address(sfDeployer));
        acl.grantRole(keccak256(bytes(SECURITY_PROVIDER)), address(this));

        vm.prank(address(sfDeployer));
        sf.governance.enableTrustedForwarder(sf.host, ISuperfluidToken(address(0)), address(forwarder));
    }

    function _encodePayload(
        FlowSchedulerMacro.CreateFlowScheduleParams memory cfsParams,
        uint256 nonce,
        uint256 validAfter,
        uint256 validBefore
    ) internal view returns (bytes memory) {
        return _encodePayloadWithLang(cfsParams, LANG_EN, nonce, validAfter, validBefore);
    }

    function _encodePayloadWithLang(
        FlowSchedulerMacro.CreateFlowScheduleParams memory cfsParams,
        bytes32 lang,
        uint256 nonce,
        uint256 validAfter,
        uint256 validBefore
    ) internal view returns (bytes memory) {
        (, bytes memory actionParams,) = scheduler712Macro.encodeCreateFlowScheduleParams(lang, cfsParams);
        return _encodePayloadWithRawActionParams(actionParams, nonce, validAfter, validBefore);
    }

    function _encodePayloadWithRawActionParams(
        bytes memory actionParams,
        uint256 nonce,
        uint256 validAfter,
        uint256 validBefore
    ) internal pure returns (bytes memory) {
        Only712MacroForwarder.PrimaryType memory payload = Only712MacroForwarder.PrimaryType({
            action: Only712MacroForwarder.ActionType({ actionParams: actionParams }),
            security: Only712MacroForwarder.SecurityType({
                domain: SECURITY_DOMAIN,
                provider: SECURITY_PROVIDER,
                validAfter: validAfter,
                validBefore: validBefore,
                nonce: nonce
            })
        });
        return abi.encode(payload);
    }

    function _sign(VmSafe.Wallet memory signer, bytes memory params)
        internal
        returns (bytes memory, bytes memory signatureVRS)
    {
        bytes32 digest = forwarder.getDigest(scheduler712Macro, params);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, digest);
        return (params, abi.encodePacked(r, s, v));
    }

    function _runMacroAs(address relayer, address signer, bytes memory params, bytes memory signatureVRS)
        internal
        returns (bool)
    {
        vm.prank(relayer);
        return forwarder.runMacro(scheduler712Macro, params, signer, signatureVRS);
    }

    function testRunMacroAndScheduleState() external {
        VmSafe.Wallet memory signer = vm.createWallet("signer");
        uint32 startDate = uint32(block.timestamp + 1);
        uint32 endDate = startDate + 3600;
        FlowSchedulerMacro.CreateFlowScheduleParams memory cfsParams =
            _makeCfsParams(startDate, 60, int96(1000), 0, endDate, "");

        bytes memory params = _encodePayload(cfsParams, DEFAULT_NONCE, 0, 0);
        (bytes memory paramsSigned, bytes memory sig) = _sign(signer, params);
        assertTrue(_runMacroAs(address(this), signer.addr, paramsSigned, sig));
        // Schedule sender SHALL BE THE SIGNER (not the relayer).
        _assertSchedule(signer.addr, cfsParams);
    }

    function testGetActionStructHashMatchesEncodeOutput() external view {
        uint32 startDate = uint32(block.timestamp + 1);
        uint32 endDate = startDate + 3600;
        FlowSchedulerMacro.CreateFlowScheduleParams memory cfsParams =
            _makeCfsParams(startDate, 60, int96(1000), 0, endDate, "");

        (, bytes memory actionParams, bytes32 expectedStructHash) =
            scheduler712Macro.encodeCreateFlowScheduleParams(LANG_EN, cfsParams);

        bytes32 result = scheduler712Macro.getActionStructHash(actionParams);
        assertEq(result, expectedStructHash);
    }

    /// @dev Mirrors FlowScheduler.createFlowSchedule time-window validation so we know when to expect success vs revert.
    function _isValidConfig(uint32 startDate, uint32 endDate, uint32 startMaxDelay) internal view returns (bool) {
        if (startDate == 0) {
            return startMaxDelay == 0 && endDate != 0 && endDate > block.timestamp;
        }
        return startDate > block.timestamp
            && (endDate == 0 || endDate > startDate);
    }

    function testRunMacroRoundTrip(
        uint256 signerKey,
        uint256 startDateRaw,
        uint256 endDateRaw,
        int96 flowRate,
        uint32 startMaxDelay,
        uint256 startAmount
    ) external {
        // Loose bounds so we get both valid and invalid combinations; upper bound keeps many valid (future start/end).
        uint256 t = block.timestamp;
        uint32 startDate = uint32(_bound(uint256(startDateRaw), 0, t + 2e9));
        uint32 endDate = uint32(_bound(uint256(endDateRaw), 0, t + 2e9));
        vm.assume(flowRate > 0);

        bool valid = _isValidConfig(startDate, endDate, startMaxDelay);

        VmSafe.Wallet memory signer = vm.createWallet(string(abi.encodePacked("signer_", signerKey)));
        uint256 nonce = forwarder.getNonce(signer.addr, 0);

        FlowSchedulerMacro.CreateFlowScheduleParams memory cfsParams =
            _makeCfsParams(startDate, startMaxDelay, flowRate, startAmount, endDate, "");

        bytes memory params = _encodePayload(cfsParams, nonce, 0, 0);
        (bytes memory paramsSigned, bytes memory sig) = _sign(signer, params);

        if (valid) {
            assertTrue(_runMacroAs(address(this), signer.addr, paramsSigned, sig));
            // Schedule sender SHALL BE THE SIGNER (not the relayer).
            _assertSchedule(signer.addr, cfsParams);
        } else {
            vm.expectRevert(IFlowScheduler.TimeWindowInvalid.selector);
            _runMacroAs(address(this), signer.addr, paramsSigned, sig);
        }
    }

    function testUnsupportedLangReverts(bytes32 lang) external {
        uint32 startDate = uint32(block.timestamp + 1);
        uint32 endDate = startDate + 3600;
        FlowSchedulerMacro.CreateFlowScheduleParams memory cfsParams =
            _makeCfsParams(startDate, 60, int96(1000), 0, endDate, "");
        VmSafe.Wallet memory signer = vm.createWallet("signer");
        uint256 nonce = forwarder.getNonce(signer.addr, 0);

        if (lang == LANG_EN) {
            bytes memory params = _encodePayloadWithLang(cfsParams, lang, nonce, 0, 0);
            (, bytes memory sig) = _sign(signer, params);
            assertTrue(_runMacroAs(address(this), signer.addr, params, sig));
            // Schedule sender SHALL BE THE SIGNER (not the relayer).
            _assertSchedule(signer.addr, cfsParams);
        } else {
            // Build payload with unsupported lang without calling macro (macro reverts in encodeCreateFlowScheduleParams).
            bytes memory actionParams = abi.encode(lang, cfsParams);
            bytes memory params = _encodePayloadWithRawActionParams(actionParams, nonce, 0, 0);
            vm.expectRevert(FlowScheduler712Macro.UnsupportedLanguage.selector);
            forwarder.getDigest(scheduler712Macro, params);
        }
    }
}
