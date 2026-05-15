package com.atlas.settlement.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
public class SettlementOrder {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String tradeReference;
    private String sellerWallet;
    private String buyerWallet;
    private BigDecimal assetAmount;
    private BigDecimal paymentAmount;
    private String status;
    private String chainSettlementId;
    private String chainTransactionHash;
    private Instant createdAt = Instant.now();

    protected SettlementOrder() {
    }

    public SettlementOrder(String tradeReference, String sellerWallet, String buyerWallet, BigDecimal assetAmount, BigDecimal paymentAmount) {
        this.tradeReference = tradeReference;
        this.sellerWallet = sellerWallet;
        this.buyerWallet = buyerWallet;
        this.assetAmount = assetAmount;
        this.paymentAmount = paymentAmount;
        this.status = "PENDING_CHAIN_FUNDING";
    }

    public void markApproved(String chainTransactionHash) {
        this.status = "SETTLED";
        this.chainTransactionHash = chainTransactionHash;
    }

    public void markCreatedOnChain(String chainSettlementId, String chainTransactionHash) {
        this.status = "FUNDED_ON_CHAIN";
        this.chainSettlementId = chainSettlementId;
        this.chainTransactionHash = chainTransactionHash;
    }

    public Long getId() {
        return id;
    }

    public String getTradeReference() {
        return tradeReference;
    }

    public String getSellerWallet() {
        return sellerWallet;
    }

    public String getBuyerWallet() {
        return buyerWallet;
    }

    public BigDecimal getAssetAmount() {
        return assetAmount;
    }

    public BigDecimal getPaymentAmount() {
        return paymentAmount;
    }

    public String getStatus() {
        return status;
    }

    public String getChainTransactionHash() {
        return chainTransactionHash;
    }

    public String getChainSettlementId() {
        return chainSettlementId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
