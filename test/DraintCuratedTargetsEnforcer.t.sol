// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {DraintCuratedTargetsEnforcer} from "../src/DraintCuratedTargetsEnforcer.sol";
import {ModeCode} from "../src/IDraintCaveatEnforcer.sol";

contract DraintCuratedTargetsEnforcerTest is Test {
    DraintCuratedTargetsEnforcer internal enforcer;
    address internal owner = makeAddr("owner");
    address internal mmDelegator = makeAddr("MetaMaskHybridDelegator");
    address internal safeDelegator = makeAddr("SafeSingleton");
    address internal drainerContract = makeAddr("CrimeEnjoyorDrainer");

    function setUp() public {
        address[] memory initialTargets = new address[](2);
        initialTargets[0] = mmDelegator;
        initialTargets[1] = safeDelegator;

        string[] memory labels = new string[](2);
        labels[0] = "MetaMask Hybrid Delegator";
        labels[1] = "Safe singleton";

        vm.prank(owner);
        enforcer = new DraintCuratedTargetsEnforcer(owner, initialTargets, labels);
    }

    // ─── Constructor + initial state ────────────────────────────────

    function test_constructor_sets_owner() public view {
        assertEq(enforcer.owner(), owner);
    }

    function test_constructor_seeds_initial_targets() public view {
        assertTrue(enforcer.allowed(mmDelegator));
        assertTrue(enforcer.allowed(safeDelegator));
        assertFalse(enforcer.allowed(drainerContract));
        assertEq(enforcer.label(mmDelegator), "MetaMask Hybrid Delegator");
    }

    function test_constructor_reverts_on_length_mismatch() public {
        address[] memory targets = new address[](2);
        targets[0] = mmDelegator;
        targets[1] = safeDelegator;
        string[] memory labels = new string[](1);
        labels[0] = "only one";
        vm.expectRevert("length mismatch");
        new DraintCuratedTargetsEnforcer(owner, targets, labels);
    }

    // ─── beforeHook: the hot path ───────────────────────────────────

    function _callBeforeHook(address target) internal view {
        // Build minimal ERC-7579 single-call execution: target(20) | value(32) | data
        bytes memory exec = abi.encodePacked(bytes20(uint160(target)), uint256(0), bytes(""));
        enforcer.beforeHook("", "", ModeCode.wrap(bytes32(0)), exec, bytes32(0), address(0), address(0));
    }

    function test_beforeHook_passes_for_allowed_target() public view {
        _callBeforeHook(mmDelegator);
        _callBeforeHook(safeDelegator);
    }

    function test_beforeHook_reverts_for_disallowed_target() public {
        vm.expectRevert(abi.encodeWithSelector(DraintCuratedTargetsEnforcer.TargetNotAllowed.selector, drainerContract));
        _callBeforeHook(drainerContract);
    }

    function test_beforeHook_reverts_on_invalid_calldata() public {
        // Too short to contain a 20-byte target
        vm.expectRevert(DraintCuratedTargetsEnforcer.InvalidExecutionCalldata.selector);
        enforcer.beforeHook("", "", ModeCode.wrap(bytes32(0)), hex"deadbeef", bytes32(0), address(0), address(0));
    }

    // ─── Owner-managed allowlist ────────────────────────────────────

    function test_owner_can_allow_new_target() public {
        address newTarget = makeAddr("AuditedDelegatorV2");

        vm.prank(owner);
        enforcer.allow(newTarget, "Audited Delegator v2");

        assertTrue(enforcer.allowed(newTarget));
        assertEq(enforcer.label(newTarget), "Audited Delegator v2");
        _callBeforeHook(newTarget);
    }

    function test_owner_can_revoke_target() public {
        vm.prank(owner);
        enforcer.revoke(mmDelegator);

        assertFalse(enforcer.allowed(mmDelegator));
        assertEq(enforcer.label(mmDelegator), "");

        vm.expectRevert(abi.encodeWithSelector(DraintCuratedTargetsEnforcer.TargetNotAllowed.selector, mmDelegator));
        _callBeforeHook(mmDelegator);
    }

    function test_nonowner_cannot_allow() public {
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(DraintCuratedTargetsEnforcer.NotOwner.selector);
        enforcer.allow(drainerContract, "Bad target");
    }

    function test_nonowner_cannot_revoke() public {
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(DraintCuratedTargetsEnforcer.NotOwner.selector);
        enforcer.revoke(mmDelegator);
    }

    function test_owner_transfer() public {
        address newOwner = makeAddr("newOwner");
        vm.prank(owner);
        enforcer.transferOwnership(newOwner);
        assertEq(enforcer.owner(), newOwner);

        // Old owner no longer has access
        vm.prank(owner);
        vm.expectRevert(DraintCuratedTargetsEnforcer.NotOwner.selector);
        enforcer.allow(drainerContract, "any");

        // New owner does
        vm.prank(newOwner);
        enforcer.allow(makeAddr("OK"), "ok");
    }
}
