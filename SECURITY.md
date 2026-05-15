# Security Model

Atlas Settlement is designed as an institutional digital asset lifecycle prototype. The security model focuses on the risks a financial client would care about most: unauthorized transfers, failed settlement, stale oracle data, compromised admin keys, custody policy failures, and incident response.

The short interview version:

> I treated this like a financial-market workflow, not a normal token demo. The main risks are reentrancy, access control failure, stale or manipulated oracle data, admin key compromise, settlement failure, custody-wallet misuse, and incident response. I mitigated those with reentrancy guards, role separation, KYC transfer restrictions, oracle freshness checks, circuit breakers, multi-sig-style custody approvals, emergency pause controls, and targeted Foundry tests.

## 1. Reentrancy

### Risk

Reentrancy happens when a contract makes an external call and the receiving contract calls back before the first function finishes. In a settlement or dividend flow, that could allow repeated claims, repeated settlement, or unexpected state changes.

### Mitigation

Settlement, custody, and dividend functions use `nonReentrant`. The settlement flow also updates the settlement status before transferring tokens, which follows the checks-effects-interactions pattern.

In `SettlementEscrow`, a trade is marked `SETTLED` before payment and asset transfers are made. That means a malicious callback cannot settle the same trade twice.

### Interview Explanation

> I used two layers of protection: a reentrancy guard and state updates before external calls. For example, the settlement status is changed before token transfers happen, so even if a malicious token or receiver tried to call back in, the trade would no longer be in a fundable state.

### Improvement

For production, I would use OpenZeppelin `ReentrancyGuard` and `SafeERC20`, and I would add a dedicated malicious-token reentrancy test.

## 2. Access Control

### Risk

If access control is weak, the wrong party could verify investors, issue assets, change oracle parameters, pause contracts, or move custody funds.

### Mitigation

The project separates responsibilities:

- Owner: administrative controls.
- Compliance officer: investor verification.
- Minter: asset issuance.
- Custody operator: routine wallet transfers within policy limits.
- Custody signer: approval for large transfers.

`AssetToken` requires verified wallets for transfers. `ComplianceRegistry` restricts investor verification to compliance officers. `SmartCustodyWallet` separates operators from signers.

### Interview Explanation

> I modeled the controls around institutional roles. The issuer should not be the only trust boundary. Compliance officers approve wallets, minters issue assets, custody operators can only perform limited transfers, and large custody movements require signer approval.

### Improvement

For production, I would replace the simple owner pattern with OpenZeppelin `AccessControl`, multi-sig admin ownership, role revocation procedures, and event monitoring for every privileged action.

## 3. Oracle Staleness

### Risk

Oracle data can be stale if the feed stops updating, the network is delayed, or the price source is unavailable. Settling against old prices can create incorrect or unfair trade outcomes.

### Mitigation

`OracleRiskModule` uses a Chainlink-style `latestRoundData()` interface and validates:

- `answer > 0`
- `updatedAt` is recent
- price is within the accepted circuit-breaker band

If `updatedAt` is older than `maxStaleness`, settlement reverts.

### Interview Explanation

> I do not blindly trust an oracle response just because it returns a value. I check that the price is positive and that `updatedAt` is inside a freshness window. If the price is stale, settlement is blocked.

### Improvement

For production, I would also check `answeredInRound`, feed decimals, feed identity, heartbeat expectations, and whether the selected feed actually matches the asset being settled.

## 4. Price Manipulation

### Risk

Even if oracle data is fresh, the price could move sharply, be incorrect, or reflect abnormal market conditions. A bad price could allow settlement at an unfair value.

### Mitigation

`OracleRiskModule` stores a reference price and a max deviation in basis points. If the latest oracle price is outside the allowed band, settlement reverts.

This acts as a circuit breaker. It does not prove the price is perfect, but it prevents settlement during abnormal movement.

### Interview Explanation

> I added a circuit breaker around the oracle. The platform checks the latest price against a reference price and rejects settlement if the deviation is too large. That gives the system a controlled failure mode instead of blindly settling during a price shock.

### Improvement

For production, I would use multiple data sources, time-weighted checks where appropriate, asset-specific thresholds, and human review for high-value exceptions.

## 5. Admin Key Compromise

### Risk

Admin keys can be dangerous because they may control verification, minting, pausing, signer configuration, and risk parameters. If an admin key is compromised, an attacker could damage the system even if the core settlement logic is correct.

### Mitigation

The prototype limits admin actions to explicit functions and emits events for role and parameter changes. Emergency pause exists so an admin can stop critical flows during an incident.

### Interview Explanation

> I treat admin keys as a major risk. The prototype uses owner-gated controls, but in production I would not leave those keys with one EOA. I would move ownership to a multi-sig, use hardware-backed keys, separate duties by role, and monitor privileged events.

### Improvement

Production controls should include:

- Multi-sig ownership.
- Timelocks for non-emergency parameter changes.
- Separate emergency pause authority.
- Hardware wallets or institutional custody for admin keys.
- Alerting for role, signer, oracle, and pause changes.

## 6. Settlement Failure

### Risk

A delivery-versus-payment workflow can fail if:

- Seller does not fund the asset side.
- Buyer does not approve payment.
- Either party is not verified.
- Oracle data is stale.
- Circuit breaker fails.
- Contract is paused.
- A token transfer fails.

Failure handling matters because funds can otherwise become stuck or settle partially.

### Mitigation

The escrow requires seller asset funding when the settlement is created. Final settlement only happens when the buyer calls `approveAndSettle()` and the oracle checks pass. If settlement cannot complete, the trade remains in `FUNDED` state and can be cancelled by the seller or owner.

### Interview Explanation

> I designed settlement to fail closed. The asset is escrowed first, payment happens only during final settlement, and the oracle checks run before assets move to the buyer. If risk checks fail, the trade does not partially settle. The seller or owner can cancel and return the escrowed asset.

### Improvement

Before production, I would add settlement expiration, dispute states, richer cancellation rules, failed-transfer handling with `SafeERC20`, and off-chain reconciliation against the backend ledger.

## 7. Smart Contract Wallet Risk

### Risk

A custody wallet can be misused if one operator can drain funds, if approval thresholds are wrong, or if emergency controls are missing. Custody is especially sensitive because financial clients care about operational controls as much as contract logic.

### Mitigation

`SmartCustodyWallet` includes:

- Operators for routine movement.
- Daily transfer limits.
- Signers for large transfers.
- Approval threshold for large transfers.
- Emergency pause.
- Events for transfer requests and approvals.

### Interview Explanation

> The custody wallet is intentionally policy-based. Operators can move funds only within a daily limit. Larger transfers require signer approval. That mirrors institutional custody controls where routine operations and high-risk approvals are separated.

### Improvement

For production, I would validate threshold configuration, prevent zero-address signers/operators, add signer rotation procedures, add transfer expiration, and consider using an audited Safe-style wallet rather than custom custody code.

## 8. Emergency Pause Procedure

### Risk

If a live incident occurs, such as oracle failure, suspicious settlement behavior, compromised roles, or custody misuse, the platform needs a way to stop damage quickly.

### Mitigation

`AssetToken`, `SettlementEscrow`, and `SmartCustodyWallet` include pause controls. Pausing blocks sensitive actions while preserving existing state for review.

### Procedure

1. Detect the incident through monitoring, failed checks, user reports, or abnormal events.
2. Pause the affected contract.
3. Identify impacted settlements, wallets, and investor addresses.
4. Preserve evidence from emitted events and backend audit logs.
5. Decide whether to cancel pending settlements, rotate roles, update oracle parameters, or redeploy.
6. Unpause only after the root cause is fixed and reviewed.

### Interview Explanation

> I added emergency pause because financial systems need controlled incident response. If oracle data becomes stale or a role is compromised, the safest response is to pause settlement or custody, inspect the state, cancel pending trades if needed, and then resume only after controls are restored.

### Improvement

Production should separate normal admin rights from emergency pause authority and add alerting around every pause and unpause action.

## 9. Testing Strategy

### Current Coverage

Foundry tests cover:

- Asset issuance.
- Verified-investor transfer restrictions.
- Delivery-versus-payment settlement.
- Stale oracle rejection.
- Circuit-breaker rejection.
- Unauthorized transfer rejection.
- Emergency pause blocking settlement.
- Dividend distribution.
- Custody daily limits and large-transfer approvals.
- Fuzz testing for settlement amounts.
- Fuzz testing for oracle price bounds.

### Interview Explanation

> I focused tests on the core invariants: unverified wallets cannot receive the asset, settlement cannot complete with stale oracle data, settlement transfers asset and payment atomically, pause blocks critical flows, and custody limits require additional approvals for larger transfers.

### Improvements

Before production or a deeper technical review, I would add:

- Malicious reentrancy test contract.
- Failed ERC-20 return-value tests.
- Zero amount and zero address validation.
- Invalid custody threshold tests.
- Dividend snapshot tests.
- Settlement expiration tests.
- Invariant tests for no partial settlement.
- Integration tests from backend API to local Anvil contracts.

## Known Security Limitations

This repository is an interview-grade prototype, not audited production code.

The main limitations are:

- Custom minimal ERC-20/security helpers should be replaced with audited OpenZeppelin contracts.
- Backend blockchain calls are currently simulated and should be wired to real deployed contracts.
- Dividend accounting should use snapshots or distribution records.
- Admin ownership should move to multi-sig governance.
- Oracle configuration should be asset-specific and validated against real Chainlink feed metadata.

## Final Interview Summary

> Atlas Settlement demonstrates the core security thinking for institutional digital assets: only verified investors can hold the asset, settlement fails closed, custody has operator limits and signer approvals, oracle data is checked for freshness and abnormal movement, privileged actions are role-gated, and emergency pause gives the institution an incident-response path. The next production steps would be audited OpenZeppelin primitives, multi-sig administration, real oracle feeds, backend-to-contract integration, and broader invariant testing.
