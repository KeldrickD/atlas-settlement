package com.atlas.settlement.api;

import com.atlas.settlement.chain.BlockchainGateway;
import com.atlas.settlement.domain.AuditEvent;
import com.atlas.settlement.domain.Investor;
import com.atlas.settlement.repository.AuditEventRepository;
import com.atlas.settlement.repository.InvestorRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/investors")
public class InvestorController {
    private final InvestorRepository investors;
    private final AuditEventRepository auditEvents;
    private final BlockchainGateway blockchainGateway;

    public InvestorController(InvestorRepository investors, AuditEventRepository auditEvents, BlockchainGateway blockchainGateway) {
        this.investors = investors;
        this.auditEvents = auditEvents;
        this.blockchainGateway = blockchainGateway;
    }

    @PostMapping("/verify")
    public Investor verify(@Valid @RequestBody VerifyInvestorRequest request) {
        Investor investor = new Investor(request.walletAddress(), request.legalName(), request.kycReference(), true);
        investors.save(investor);
        String txHash = blockchainGateway.submitInvestorVerification(request.walletAddress(), request.kycReference());
        auditEvents.save(new AuditEvent("COMPLIANCE_OFFICER", "INVESTOR_VERIFIED", request.walletAddress(), txHash));
        return investor;
    }

    public record VerifyInvestorRequest(@NotBlank String walletAddress, @NotBlank String legalName, @NotBlank String kycReference) {
    }
}

