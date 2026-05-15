package com.atlas.settlement.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;

@Entity
public class Investor {
    @Id
    private String walletAddress;
    private String legalName;
    private String kycReference;
    private boolean verified;
    private Instant verifiedAt;

    protected Investor() {
    }

    public Investor(String walletAddress, String legalName, String kycReference, boolean verified) {
        this.walletAddress = walletAddress;
        this.legalName = legalName;
        this.kycReference = kycReference;
        this.verified = verified;
        this.verifiedAt = verified ? Instant.now() : null;
    }

    public String getWalletAddress() {
        return walletAddress;
    }

    public String getLegalName() {
        return legalName;
    }

    public String getKycReference() {
        return kycReference;
    }

    public boolean isVerified() {
        return verified;
    }

    public Instant getVerifiedAt() {
        return verifiedAt;
    }
}

