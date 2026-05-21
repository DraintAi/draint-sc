// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title DraintAllowlistGuard
/// @notice Minimal PoC for drain't's pre-delegation safety check.
///         Day 7 simplification — Day 8 ships the full ICaveatEnforcer
///         that plugs into MetaMask's Delegation Framework.
/// @dev Threat model: an EOA is about to sign an EIP-7702 authorization
///      delegating its code to `target`. dApps / wallets / agents call
///      `checkDelegation(target)` BEFORE prompting the user; if target is
///      not in the allowlist, the operation reverts.
contract DraintAllowlistGuard {
    error TargetNotAllowed(address target);
    error NotOwner();

    event TargetAllowed(address indexed target);
    event TargetRevoked(address indexed target);
    event OwnerTransferred(address indexed previous, address indexed next);

    address public owner;
    mapping(address => bool) public allowed;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _owner, address[] memory _initialAllowed) {
        owner = _owner;
        emit OwnerTransferred(address(0), _owner);
        for (uint256 i; i < _initialAllowed.length; ++i) {
            allowed[_initialAllowed[i]] = true;
            emit TargetAllowed(_initialAllowed[i]);
        }
    }

    /// @notice Reverts unless `target` is an allowed delegation destination.
    function checkDelegation(address target) external view {
        if (!allowed[target]) revert TargetNotAllowed(target);
    }

    function allow(address target) external onlyOwner {
        allowed[target] = true;
        emit TargetAllowed(target);
    }

    function revoke(address target) external onlyOwner {
        allowed[target] = false;
        emit TargetRevoked(target);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        address prev = owner;
        owner = newOwner;
        emit OwnerTransferred(prev, newOwner);
    }
}
