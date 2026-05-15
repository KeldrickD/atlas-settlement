package com.atlas.settlement.repository;

import com.atlas.settlement.domain.SettlementOrder;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SettlementOrderRepository extends JpaRepository<SettlementOrder, Long> {
}

