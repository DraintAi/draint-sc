// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDraintCaveatEnforcer, ModeCode} from "./IDraintCaveatEnforcer.sol";

/// @title DraintCuratedTargetsEnforcer
/// @notice MetaMask Delegation Framework caveat enforcer that restricts the
///         redeemer (drain't agent) to calling targets on a curated allowlist.
/// @dev Differs from MM's stock `AllowedTargetsEnforcer` in one key way: the
///      allowlist is **stored on this contract and managed by an owner**
///      (typically a multisig or DAO), not encoded in per-delegation terms.
///      Net effect:
///        - Adding a newly-audited delegation target benefits every existing
///          drain't user immediately (no re-delegation needed).
///        - Compromised target can be revoked from one place in an emergency.
///        - Per-delegation flexibility is sacrificed (use MM's enforcer for
///          custom allowlists per user).
///
/// Threat model: drain't agent gets delegated execution permission on the
/// user's Smart Account via ERC-7710. This enforcer is attached as a caveat,
/// ensuring that any executed tx targets a delegation destination drain't
/// has vetted (MM Hybrid Delegator, Safe singleton, etc.).
contract DraintCuratedTargetsEnforcer is IDraintCaveatEnforcer {
    // ─── Errors ─────────────────────────────────────────────────────

    error NotOwner();
    error TargetNotAllowed(address target);
    error InvalidExecutionCalldata();

    // ─── Events ─────────────────────────────────────────────────────

    event TargetAllowed(address indexed target, string label);
    event TargetRevoked(address indexed target);
    event OwnerTransferred(address indexed previous, address indexed next);

    // ─── Storage ────────────────────────────────────────────────────

    address public owner;
    mapping(address target => bool) public allowed;
    /// Optional human-readable label per target. Off-chain UI / explorers
    /// can show "MetaMask Hybrid Delegator" instead of raw addresses.
    mapping(address target => string) public label;

    // ─── Constructor ────────────────────────────────────────────────

    constructor(address _owner, address[] memory _initialTargets, string[] memory _initialLabels) {
        require(_initialTargets.length == _initialLabels.length, "length mismatch");
        owner = _owner;
        emit OwnerTransferred(address(0), _owner);
        for (uint256 i; i < _initialTargets.length; ++i) {
            allowed[_initialTargets[i]] = true;
            label[_initialTargets[i]] = _initialLabels[i];
            emit TargetAllowed(_initialTargets[i], _initialLabels[i]);
        }
    }

    // ─── Owner management ───────────────────────────────────────────

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert NotOwner();
    }

    function allow(address _target, string calldata _label) external onlyOwner {
        allowed[_target] = true;
        label[_target] = _label;
        emit TargetAllowed(_target, _label);
    }

    function revoke(address _target) external onlyOwner {
        allowed[_target] = false;
        delete label[_target];
        emit TargetRevoked(_target);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        address prev = owner;
        owner = _newOwner;
        emit OwnerTransferred(prev, _newOwner);
    }

    // ─── ICaveatEnforcer hooks ──────────────────────────────────────

    /// @notice The hot path. Called by MM's DelegationManager before every
    ///         execution scoped to a delegation with this enforcer attached.
    /// @dev We parse the target address from `_executionCalldata` and revert
    ///      if it isn't on the curated allowlist. Targets the standard
    ///      ERC-7579 single-call mode (20-byte target | 32-byte value | bytes calldata).
    function beforeHook(
        bytes calldata, /* _terms */
        bytes calldata, /* _args */
        ModeCode, /* _mode */
        bytes calldata _executionCalldata,
        bytes32, /* _delegationHash */
        address, /* _delegator */
        address /* _redeemer */
    ) external view override {
        address target = _decodeTarget(_executionCalldata);
        if (!allowed[target]) revert TargetNotAllowed(target);
    }

    // Unused hooks — leave as no-ops. Override only if needed later.
    function beforeAllHook(bytes calldata, bytes calldata, ModeCode, bytes calldata, bytes32, address, address)
        external
        pure
        override
    {}

    function afterHook(bytes calldata, bytes calldata, ModeCode, bytes calldata, bytes32, address, address)
        external
        pure
        override
    {}

    function afterAllHook(bytes calldata, bytes calldata, ModeCode, bytes calldata, bytes32, address, address)
        external
        pure
        override
    {}

    // ─── Internal helpers ───────────────────────────────────────────

    /// @dev Decode ERC-7579 single-call layout: address (20) | value (32) | calldata (...).
    /// MM's stock enforcer uses `ExecutionLib.decodeSingle` from the erc7579
    /// lib; we inline the slice to avoid the dep.
    function _decodeTarget(bytes calldata _executionCalldata) internal pure returns (address) {
        if (_executionCalldata.length < 20) revert InvalidExecutionCalldata();
        return address(bytes20(_executionCalldata[0:20]));
    }
}
