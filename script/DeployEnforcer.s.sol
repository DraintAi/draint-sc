// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DraintCuratedTargetsEnforcer} from "../src/DraintCuratedTargetsEnforcer.sol";

/// @notice Deploy script for DraintCuratedTargetsEnforcer.
///
/// Reads from env:
///   PRIVATE_KEY                 — deployer key (fresh wallet, NOT your main one)
///   DRAINT_ENFORCER_OWNER       — initial owner (can manage allowlist post-deploy)
///                                 Default: deployer
///   DRAINT_INITIAL_TARGETS      — comma-separated 0x-addresses (no spaces)
///   DRAINT_INITIAL_LABELS       — comma-separated human-readable labels (no commas in labels)
///
/// Run (Sepolia):
///   forge script script/DeployEnforcer.s.sol \
///     --rpc-url ethereum_sepolia \
///     --broadcast \
///     --verify
contract DeployEnforcer is Script {
    function run() external returns (DraintCuratedTargetsEnforcer enforcer) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envOr("DRAINT_ENFORCER_OWNER", vm.addr(deployerKey));

        (address[] memory targets, string[] memory labels) = _readInitialTargets();

        console.log("Deploying DraintCuratedTargetsEnforcer...");
        console.log("  Owner:        ", owner);
        console.log("  Initial size: ", targets.length);

        vm.startBroadcast(deployerKey);
        enforcer = new DraintCuratedTargetsEnforcer(owner, targets, labels);
        vm.stopBroadcast();

        console.log("");
        console.log("DraintCuratedTargetsEnforcer deployed to:");
        console.log(address(enforcer));

        return enforcer;
    }

    /// @dev Parse comma-separated env vars. If unset, deploy with empty list
    ///      — owner can add targets post-deploy via `allow()`.
    function _readInitialTargets() internal view returns (address[] memory targets, string[] memory labels) {
        string memory rawTargets = vm.envOr("DRAINT_INITIAL_TARGETS", string(""));
        string memory rawLabels = vm.envOr("DRAINT_INITIAL_LABELS", string(""));

        if (bytes(rawTargets).length == 0) {
            targets = new address[](0);
            labels = new string[](0);
            return (targets, labels);
        }

        string[] memory targetStrs = vm.split(rawTargets, ",");
        string[] memory labelStrs = vm.split(rawLabels, ",");
        require(targetStrs.length == labelStrs.length, "targets/labels length mismatch");

        targets = new address[](targetStrs.length);
        labels = new string[](labelStrs.length);
        for (uint256 i; i < targetStrs.length; ++i) {
            targets[i] = vm.parseAddress(targetStrs[i]);
            labels[i] = labelStrs[i];
        }
    }
}
