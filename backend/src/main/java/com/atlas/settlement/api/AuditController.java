package com.atlas.settlement.api;

import com.atlas.settlement.domain.AuditEvent;
import com.atlas.settlement.repository.AuditEventRepository;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/audit-log")
public class AuditController {
    private final AuditEventRepository auditEvents;

    public AuditController(AuditEventRepository auditEvents) {
        this.auditEvents = auditEvents;
    }

    @GetMapping
    public List<AuditEvent> list() {
        return auditEvents.findAll();
    }
}

