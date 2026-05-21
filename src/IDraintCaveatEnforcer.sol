// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IDraintCaveatEnforcer
/// @notice Inline copy of MetaMask Delegation Framework's `ICaveatEnforcer`
///         shape, declared at our project's pragma so we can compile without
///         the framework's transitive deps + 0.8.23 exact pragma.
/// @dev Swap to `lib/delegation-framework/src/interfaces/ICaveatEnforcer.sol`
///      once we enable auto_detect_solc and bring in framework submodules.
///      The function signatures here match MM's exactly; behavior is contract-
///      compatible — DraintCuratedTargetsEnforcer's hooks will be invoked
///      identically by MM's DelegationManager once we cut over.
///
/// Source signature reference:
///   https://github.com/MetaMask/delegation-framework/blob/main/src/interfaces/ICaveatEnforcer.sol
///
/// The `ModeCode` is `bytes32` in MM's `Types.sol` — we use the same type
/// here for binary compatibility.
type ModeCode is bytes32;

interface IDraintCaveatEnforcer {
    function beforeAllHook(
        bytes calldata _terms,
        bytes calldata _args,
        ModeCode _mode,
        bytes calldata _executionCalldata,
        bytes32 _delegationHash,
        address _delegator,
        address _redeemer
    ) external;

    function beforeHook(
        bytes calldata _terms,
        bytes calldata _args,
        ModeCode _mode,
        bytes calldata _executionCalldata,
        bytes32 _delegationHash,
        address _delegator,
        address _redeemer
    ) external;

    function afterHook(
        bytes calldata _terms,
        bytes calldata _args,
        ModeCode _mode,
        bytes calldata _executionCalldata,
        bytes32 _delegationHash,
        address _delegator,
        address _redeemer
    ) external;

    function afterAllHook(
        bytes calldata _terms,
        bytes calldata _args,
        ModeCode _mode,
        bytes calldata _executionCalldata,
        bytes32 _delegationHash,
        address _delegator,
        address _redeemer
    ) external;
}
