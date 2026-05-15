package com.atlas.settlement.api;

import com.atlas.settlement.domain.AuditEvent;
import com.atlas.settlement.repository.AuditEventRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import java.math.BigDecimal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/assets")
public class AssetController {
    private final AuditEventRepository auditEvents;

    public AssetController(AuditEventRepository auditEvents) {
        this.auditEvents = auditEvents;
    }

    @PostMapping("/issue")
    public IssueAssetResponse issue(@Valid @RequestBody IssueAssetRequest request) {
        auditEvents.save(new AuditEvent("ISSUER", "ASSET_ISSUED", request.instrumentId(), request.investorWallet()));
        return new IssueAssetResponse(request.instrumentId(), request.investorWallet(), request.amount(), "PENDING_CHAIN_CONFIRMATION");
    }

    public record IssueAssetRequest(@NotBlank String instrumentId, @NotBlank String investorWallet, @DecimalMin("0.000000000000000001") BigDecimal amount) {
    }

    public record IssueAssetResponse(String instrumentId, String investorWallet, BigDecimal amount, String status) {
    }
}

