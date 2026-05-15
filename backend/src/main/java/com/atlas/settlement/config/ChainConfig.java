package com.atlas.settlement.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.http.HttpService;

@Configuration
@EnableConfigurationProperties(ChainProperties.class)
public class ChainConfig {
    @Bean
    Web3j web3j(ChainProperties properties) {
        return Web3j.build(new HttpService(properties.rpcUrl()));
    }
}

