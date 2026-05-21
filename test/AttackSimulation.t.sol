// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {CrimeEnjoyorMock} from "../src/CrimeEnjoyorMock.sol";
import {DraintAllowlistGuard} from "../src/DraintAllowlistGuard.sol";

/// @notice End-to-end attack simulation for drain't's classifier dataset.
///
/// What this proves:
///   1. CrimeEnjoyor-class drainer matches the canonical bytecode shape
///      that drain't's heuristic classifier targets (tiny, fallback-only).
///   2. The simulated attack drains a victim wallet to attacker in one
///      transaction — establishing the threat model drain't defends against.
///   3. Captures the runtime bytecode + keccak256 hash so we can plug them
///      into draint-be's `known-drainers.ts` dataset for exact-match
///      detection (severity = critical with risk score 1.0).
///
/// Run: `forge test --match-contract AttackSimulation -vv`
contract AttackSimulationTest is Test {
    CrimeEnjoyorMock internal drainer;
    address payable internal attacker;
    address payable internal victim;

    function setUp() public {
        attacker = payable(makeAddr("attacker"));
        victim = payable(makeAddr("victim"));
        drainer = new CrimeEnjoyorMock(attacker);
        vm.deal(victim, 10 ether);
    }

    // ─── 1. Bytecode signature matches CrimeEnjoyor family ───────────

    function test_runtime_bytecode_is_tiny() public view {
        bytes memory code = address(drainer).code;
        console.log("CrimeEnjoyorMock runtime bytecode size (bytes):", code.length);
        // Canonical CrimeEnjoyor variants compile to < 200 bytes.
        assertLt(code.length, 500, "bytecode larger than expected for drainer");
    }

    function test_runtime_bytecode_has_no_function_selectors() public view {
        // No public functions = no 4-byte selectors in the dispatch table.
        // Drainers rely solely on fallback/receive to keep bytecode minimal.
        bytes memory code = address(drainer).code;
        // Crude heuristic: count PUSH4 (0x63) opcodes — drainers should have few or none.
        uint256 push4Count;
        for (uint256 i; i < code.length; ++i) {
            if (uint8(code[i]) == 0x63) push4Count++;
        }
        console.log("PUSH4 opcode count:", push4Count);
        assertLt(push4Count, 5, "too many selectors for a drainer signature");
    }

    function test_print_bytecode_hash_for_dataset() public view {
        bytes memory code = address(drainer).code;
        bytes32 hash = keccak256(code);
        console.log("=== drain't classifier dataset entry ===");
        console.log("name:        CrimeEnjoyorMock (test fixture)");
        console.log("bytecodeHash:", vm.toString(hash));
        console.log("runtimeCode: ");
        console.logBytes(code);
        console.log("=== end ===");
    }

    // ─── 2. Attack drains victim in one tx ───────────────────────────

    function test_attack_drains_victim_in_single_tx() public {
        uint256 victimBefore = victim.balance;
        uint256 attackerBefore = attacker.balance;
        assertEq(victimBefore, 10 ether, "victim should start with 10 ETH");
        assertEq(attackerBefore, 0, "attacker should start empty");

        // Simulated scenario: victim's EOA has been EIP-7702 delegated to
        // the drainer. When ETH arrives at the EOA (e.g., a gas-funding
        // sweep attack), the fallback fires and forwards to attacker.
        //
        // We mimic this by calling the drainer directly with ETH.
        vm.prank(victim);
        (bool ok, ) = address(drainer).call{value: 5 ether}("");
        assertTrue(ok, "drainer fallback should accept ETH");

        // Drainer forwarded the ETH out — its balance is zero, attacker is
        // funded. In a real EIP-7702 attack this happens inside the victim's
        // own EOA address space.
        assertEq(address(drainer).balance, 0, "drainer should not hold residual");
        assertEq(attacker.balance, 5 ether, "attacker should be funded");
    }

    function test_receive_path_also_drains() public {
        // Plain ETH transfers (no calldata) hit `receive()` not `fallback()`.
        // Both routes drain.
        vm.prank(victim);
        (bool ok, ) = address(drainer).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(attacker.balance, 2 ether);
    }

    // ─── 3. Defense PoC: DraintAllowlistGuard prevents the attack ────

    function test_defense_blocks_drainer_delegation() public {
        // Owner sets up the guard with only one trusted target — a
        // hypothetical MetaMask Hybrid Delegator. Drainer is NOT in the list.
        address mockSafeDelegator = makeAddr("MockSafeDelegator");
        address[] memory initial = new address[](1);
        initial[0] = mockSafeDelegator;

        DraintAllowlistGuard guard = new DraintAllowlistGuard(
            address(this),
            initial
        );

        // Legit delegation passes.
        guard.checkDelegation(mockSafeDelegator);

        // Drainer delegation reverts BEFORE the user signs anything.
        vm.expectRevert(
            abi.encodeWithSelector(
                DraintAllowlistGuard.TargetNotAllowed.selector,
                address(drainer)
            )
        );
        guard.checkDelegation(address(drainer));
    }

    function test_defense_owner_can_allow_new_targets() public {
        address[] memory empty = new address[](0);
        DraintAllowlistGuard guard = new DraintAllowlistGuard(
            address(this),
            empty
        );

        address newTarget = makeAddr("NewAuditedDelegator");

        // Before adding: reverts.
        vm.expectRevert(
            abi.encodeWithSelector(
                DraintAllowlistGuard.TargetNotAllowed.selector,
                newTarget
            )
        );
        guard.checkDelegation(newTarget);

        // Owner adds the new target.
        guard.allow(newTarget);

        // After adding: passes.
        guard.checkDelegation(newTarget);

        // Non-owner cannot add.
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(DraintAllowlistGuard.NotOwner.selector);
        guard.allow(makeAddr("MaliciousTarget"));
    }
}
