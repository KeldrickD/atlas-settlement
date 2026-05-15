"use client";

import { useState } from "react";
import {
  Activity,
  AlertTriangle,
  BadgeCheck,
  Banknote,
  Blocks,
  CheckCircle2,
  FileCheck2,
  Landmark,
  LockKeyhole,
  PauseCircle,
  ShieldCheck,
  WalletCards
} from "lucide-react";

const metrics = [
  { label: "Tokenized AUM", value: "$48.7M", trend: "+3.8%", icon: Landmark },
  { label: "Pending Settlements", value: "12", trend: "4 high value", icon: Blocks },
  { label: "Verified Investors", value: "184", trend: "7 this week", icon: BadgeCheck },
  { label: "Oracle Health", value: "Fresh", trend: "18s updated", icon: Activity }
];

type SettlementRow = {
  ref: string;
  buyer: string;
  seller: string;
  asset: string;
  amount: string;
  payment: string;
  status: string;
  txHash?: string;
};

const ANVIL_SELLER = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
const ANVIL_BUYER = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:8080";
const HAS_CONFIGURED_API_BASE_URL = Boolean(process.env.NEXT_PUBLIC_API_BASE_URL);

const initialSettlements: SettlementRow[] = [
  { ref: "DVP-1049", buyer: "0x8E2...14C", seller: "0xA45...91F", asset: "ATF", amount: "125,000", payment: "$1,247,500", status: "Ready" },
  { ref: "DVP-1050", buyer: "0x9C1...E42", seller: "0x771...10D", asset: "ATF", amount: "40,000", payment: "$398,800", status: "Oracle Review" },
  { ref: "DVP-1051", buyer: "0xF16...B03", seller: "0x209...78A", asset: "PCN", amount: "72,500", payment: "$724,275", status: "Awaiting Buyer" }
];

const audit = [
  ["10:42:18", "Compliance Officer", "Investor verified", "KYC-2026-1842"],
  ["10:43:02", "Issuer", "Asset issued", "ATF-2026-A"],
  ["10:44:51", "Custodian", "Large transfer approved", "TX-2381"],
  ["10:46:15", "Risk Module", "Oracle staleness check passed", "ETH/USD"]
];

const riskFlags = [
  { label: "Oracle stale data", state: "Clear", icon: CheckCircle2 },
  { label: "Circuit breaker", state: "Within 5% band", icon: ShieldCheck },
  { label: "Emergency pause", state: "Armed", icon: PauseCircle },
  { label: "Large transfer policy", state: "2 of 2 approvals", icon: LockKeyhole }
];

export default function Dashboard() {
  const [settlements, setSettlements] = useState<SettlementRow[]>(initialSettlements);
  const [creating, setCreating] = useState(false);
  const [liveMessage, setLiveMessage] = useState("Ready for local Anvil settlement creation.");
  const [liveError, setLiveError] = useState<string | null>(null);

  async function createSettlement() {
    setCreating(true);
    setLiveError(null);
    const tradeReference = `DVP-${Date.now().toString().slice(-6)}`;

    try {
      if (!HAS_CONFIGURED_API_BASE_URL && !isLocalBrowserRuntime()) {
        setSettlements((current) => [
          {
            ref: tradeReference,
            buyer: compactAddress(ANVIL_BUYER),
            seller: compactAddress(ANVIL_SELLER),
            asset: "ATF",
            amount: "10",
            payment: "$1000",
            status: "LOCAL_PREVIEW",
            txHash: "local-only"
          },
          ...current
        ]);
        setLiveMessage("Cloud preview only. Run the local Anvil flow in the README for a real on-chain transaction.");
        return;
      }

      const response = await fetch(`${API_BASE_URL}/settlements/create`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          tradeReference,
          sellerWallet: ANVIL_SELLER,
          buyerWallet: ANVIL_BUYER,
          assetAmount: "10",
          paymentAmount: "1000"
        })
      });

      if (!response.ok) {
        throw new Error(await response.text());
      }

      const settlement = await response.json();
      setSettlements((current) => [
        {
          ref: settlement.tradeReference,
          buyer: compactAddress(settlement.buyerWallet),
          seller: compactAddress(settlement.sellerWallet),
          asset: "ATF",
          amount: settlement.assetAmount,
          payment: `$${settlement.paymentAmount}`,
          status: settlement.status,
          txHash: settlement.chainTransactionHash
        },
        ...current
      ]);
      setLiveMessage(`Created ${settlement.tradeReference} on Anvil: ${compactAddress(settlement.chainTransactionHash)}`);
    } catch (error) {
      setLiveError(error instanceof Error ? error.message : "Unable to create settlement");
    } finally {
      setCreating(false);
    }
  }

  return (
    <main className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brandMark"><Landmark size={20} /></div>
          <div>
            <strong>Atlas Settlement</strong>
            <span>Institutional Digital Assets</span>
          </div>
        </div>
        <nav>
          {["Dashboard", "Investors", "Assets", "Settlement", "Custody", "Audit Log", "Risk Monitor"].map((item) => (
            <a className={item === "Dashboard" ? "active" : ""} href="#" key={item}>{item}</a>
          ))}
        </nav>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p>Financial Client Operations</p>
            <h1>Tokenized asset lifecycle control center</h1>
          </div>
          <div className="actions">
            <button title="Review risk alerts"><AlertTriangle size={18} /> Risk</button>
            <button disabled={creating} onClick={createSettlement} title="Create settlement on local Anvil">
              <Banknote size={18} /> {creating ? "Creating..." : "New DVP"}
            </button>
          </div>
        </header>

        <section className={`liveFlow ${liveError ? "error" : ""}`}>
          <strong>Live Anvil Flow</strong>
          <span>{liveError ?? liveMessage}</span>
        </section>

        <section className="metrics">
          {metrics.map(({ label, value, trend, icon: Icon }) => (
            <article className="metric" key={label}>
              <Icon size={20} />
              <span>{label}</span>
              <strong>{value}</strong>
              <small>{trend}</small>
            </article>
          ))}
        </section>

        <section className="grid">
          <div className="panel wide">
            <div className="panelHeader">
              <div>
                <span>Settlement Desk</span>
                <h2>Delivery-versus-payment queue</h2>
              </div>
              <FileCheck2 size={20} />
            </div>
            <table>
              <thead>
                <tr>
                  <th>Trade</th>
                  <th>Buyer</th>
                  <th>Seller</th>
                  <th>Asset</th>
                  <th>Quantity</th>
                  <th>Payment</th>
                  <th>Status</th>
                  <th>Tx</th>
                </tr>
              </thead>
              <tbody>
                {settlements.map((row) => (
                  <tr key={row.ref}>
                    <td>{row.ref}</td>
                    <td>{row.buyer}</td>
                    <td>{row.seller}</td>
                    <td>{row.asset}</td>
                    <td>{row.amount}</td>
                    <td>{row.payment}</td>
                    <td><span className={`pill ${row.status === "Oracle Review" ? "warn" : ""}`}>{row.status}</span></td>
                    <td><code>{row.txHash ? compactAddress(row.txHash) : "demo"}</code></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="panel">
            <div className="panelHeader">
              <div>
                <span>Custody</span>
                <h2>Wallet policy</h2>
              </div>
              <WalletCards size={20} />
            </div>
            <div className="custody">
              <strong>$10,000</strong>
              <span>Daily operator limit</span>
              <strong>2 / 2</strong>
              <span>Large transfer approvals</span>
              <strong>Active</strong>
              <span>Emergency controls</span>
            </div>
          </div>

          <div className="panel">
            <div className="panelHeader">
              <div>
                <span>Risk Monitor</span>
                <h2>Oracle controls</h2>
              </div>
              <ShieldCheck size={20} />
            </div>
            <div className="riskList">
              {riskFlags.map(({ label, state, icon: Icon }) => (
                <div className="risk" key={label}>
                  <Icon size={18} />
                  <span>{label}</span>
                  <strong>{state}</strong>
                </div>
              ))}
            </div>
          </div>

          <div className="panel wide">
            <div className="panelHeader">
              <div>
                <span>Audit Trail</span>
                <h2>Recent control events</h2>
              </div>
              <Activity size={20} />
            </div>
            <div className="audit">
              {audit.map(([time, actor, action, ref]) => (
                <div className="auditRow" key={`${time}-${ref}`}>
                  <time>{time}</time>
                  <strong>{actor}</strong>
                  <span>{action}</span>
                  <code>{ref}</code>
                </div>
              ))}
            </div>
          </div>
        </section>
      </section>
    </main>
  );
}

function compactAddress(value: string) {
  if (!value || value.length <= 12) {
    return value;
  }
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

function isLocalBrowserRuntime() {
  if (typeof window === "undefined") {
    return true;
  }
  return ["localhost", "127.0.0.1", "::1"].includes(window.location.hostname);
}
