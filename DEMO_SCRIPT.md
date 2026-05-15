# Five-Minute Demo Script

## 1. Problem

Financial institutions need tokenized assets with compliance, custody, settlement, servicing, and auditability. A normal token contract is not enough.

## 2. Architecture

Show the README diagram. Explain the Next.js dashboard, Spring Boot API, Web3j integration boundary, PostgreSQL/H2 persistence, and Ethereum contracts.

## 3. Smart Contract Flow

Open `SettlementEscrow.sol`. Explain seller-funded escrow, buyer payment approval, oracle risk check, and atomic asset/payment transfer.

## 4. Security Model

Open `SECURITY.md`. Call out reentrancy protection, verified investor transfers, oracle `updatedAt` freshness checks, circuit breakers, role controls, and emergency pause.

## 5. Live Demo

Run:

```bash
forge test
```

Then show the dashboard:

```bash
cd frontend
npm install
npm run dev
```

## 6. Production Improvements

Mention external audit, formal verification, real Chainlink feeds, real KYC provider integration, multi-sig admin ownership, monitoring, database migrations, and CI/CD.

