package com.atlas.settlement.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "atlas.chain")
public record ChainProperties(
    String rpcUrl,
    String complianceRegistry,
    String settlementEscrow,
    String deploymentFile,
    String sellerPrivateKey,
    long chainId,
    int assetDecimals,
    int paymentDecimals
) {
}
