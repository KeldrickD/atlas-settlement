package com.atlas.settlement.repository;

import com.atlas.settlement.domain.Investor;
import org.springframework.data.jpa.repository.JpaRepository;

public interface InvestorRepository extends JpaRepository<Investor, String> {
}

