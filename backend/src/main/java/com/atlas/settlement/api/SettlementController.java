package com.atlas.settlement.api;

import com.atlas.settlement.chain.BlockchainGateway;
import com.atlas.settlement.domain.AuditEvent;
import com.atlas.settlement.domain.SettlementOrder;
import com.atlas.settlement.repository.AuditEventRepository;
import com.atlas.settlement.repository.SettlementOrderRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import java.math.BigDecimal;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@CrossOrigin(origins = {"http://127.0.0.1:3000", "http://localhost:3000"})
@RequestMapping("/settlements")
public class SettlementController {
    private final SettlementOrderRepository settlements;
    private final AuditEventRepository auditEvents;
    private final BlockchainGateway blockchainGateway;

    public SettlementController(SettlementOrderRepository settlements, AuditEventRepository auditEvents, BlockchainGateway blockchainGateway) {
        this.settlements = settlements;
        this.auditEvents = auditEvents;
        this.blockchainGateway = blockchainGateway;
    }

    @PostMapping("/create")
    public SettlementOrder create(@Valid @RequestBody CreateSettlementRequest request) {
        SettlementOrder order = new SettlementOrder(
            request.tradeReference(),
            request.sellerWallet(),
            request.buyerWallet(),
            request.assetAmount(),
            request.paymentAmount()
        );
        settlements.save(order);
        BlockchainGateway.CreateSettlementResult chainResult = blockchainGateway.createSettlement(
            request.sellerWallet(),
            request.buyerWallet(),
            request.assetAmount(),
            request.paymentAmount(),
            request.tradeReference()
        );
        order.markCreatedOnChain(chainResult.settlementId().toString(), chainResult.transactionHash());
        settlements.save(order);
        auditEvents.save(new AuditEvent("TRANSFER_AGENT", "SETTLEMENT_CREATED", request.tradeReference(), chainResult.transactionHash()));
        return order;
    }

    @PostMapping("/{id}/approve")
    public SettlementOrder approve(@PathVariable Long id) {
        SettlementOrder order = settlements.findById(id).orElseThrow();
        String txHash = blockchainGateway.approveSettlement(id);
        order.markApproved(txHash);
        settlements.save(order);
        auditEvents.save(new AuditEvent("INVESTOR_WALLET", "SETTLEMENT_APPROVED", id.toString(), txHash));
        return order;
    }

    @GetMapping("/{id}")
    public SettlementOrder get(@PathVariable Long id) {
        return settlements.findById(id).orElseThrow();
    }

    public record CreateSettlementRequest(
        @NotBlank String tradeReference,
        @NotBlank String sellerWallet,
        @NotBlank String buyerWallet,
        @DecimalMin("0.000000000000000001") BigDecimal assetAmount,
        @DecimalMin("0.01") BigDecimal paymentAmount
    ) {
    }
}
