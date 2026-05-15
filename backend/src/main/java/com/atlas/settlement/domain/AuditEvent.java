package com.atlas.settlement.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;

@Entity
public class AuditEvent {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private Instant occurredAt = Instant.now();
    private String actor;
    private String action;
    private String reference;
    private String details;

    protected AuditEvent() {
    }

    public AuditEvent(String actor, String action, String reference, String details) {
        this.actor = actor;
        this.action = action;
        this.reference = reference;
        this.details = details;
    }

    public Long getId() {
        return id;
    }

    public Instant getOccurredAt() {
        return occurredAt;
    }

    public String getActor() {
        return actor;
    }

    public String getAction() {
        return action;
    }

    public String getReference() {
        return reference;
    }

    public String getDetails() {
        return details;
    }
}

