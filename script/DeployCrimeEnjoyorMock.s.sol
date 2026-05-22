// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {CrimeEnjoyorMock} from "../src/CrimeEnjoyorMock.sol";

/// @notice Deploy a CrimeEnjoyor-class drainer to a testnet for live
///         classifier demos. The deployed contract is the exact shape
///         that drain't&apos;s heuristic flags (tiny bytecode, fallback-
///         dominant, auto-forwards ETH).
///
///         FOR DEMO/TESTING ONLY. Never deploy to mainnet — the contract
///         is functional and will drain any ETH sent to it.
///
/// Env:
///   PRIVATE_KEY                 — deployer key (with or without 0x prefix)
///   CRIME_ENJOYOR_ATTACKER      — optional, defaults to 0x...dEaD sink
///
/// Run (Sepolia):
///   forge script script/DeployCrimeEnjoyorMock.s.sol \
///     --rpc-url ethereum_sepolia \
///     --broadcast \
///     --verify
contract DeployCrimeEnjoyorMock is Script {
    /// Default sink — burn address. Drained funds go here, never recoverable.
    address payable constant DEFAULT_ATTACKER = payable(0x000000000000000000000000000000000000dEaD);

    function run() external returns (CrimeEnjoyorMock drainer) {
        uint256 deployerKey = _loadPrivateKey();
        address payable attacker = payable(vm.envOr("CRIME_ENJOYOR_ATTACKER", address(DEFAULT_ATTACKER)));

        console.log("WARNING: deploying a functional EIP-7702 drainer for testing");
        console.log("  Attacker sink: ", attacker);
        console.log("");

        vm.startBroadcast(deployerKey);
        drainer = new CrimeEnjoyorMock(attacker);
        vm.stopBroadcast();

        console.log("CrimeEnjoyorMock (drain't test fixture) deployed to:");
        console.log(address(drainer));
        console.log("");
        console.log("Now use this address in drain't&apos;s honeypot to demo the snap firing.");
    }

    function _loadPrivateKey() internal view returns (uint256) {
        string memory raw = vm.envString("PRIVATE_KEY");
        bytes memory rawBytes = bytes(raw);
        if (rawBytes.length >= 2 && rawBytes[0] == "0" && (rawBytes[1] == "x" || rawBytes[1] == "X")) {
            return vm.parseUint(raw);
        }
        return vm.parseUint(string.concat("0x", raw));
    }
}
