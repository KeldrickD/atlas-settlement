package com.atlas.settlement.chain;

import com.atlas.settlement.config.ChainProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.math.RoundingMode;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;
import org.web3j.abi.FunctionEncoder;
import org.web3j.abi.FunctionReturnDecoder;
import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.Address;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.Type;
import org.web3j.abi.datatypes.Utf8String;
import org.web3j.abi.datatypes.generated.Uint256;
import org.web3j.crypto.Credentials;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.DefaultBlockParameterName;
import org.web3j.protocol.core.methods.request.Transaction;
import org.web3j.protocol.core.methods.response.EthCall;
import org.web3j.protocol.core.methods.response.EthSendTransaction;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.tx.RawTransactionManager;
import org.web3j.tx.TransactionManager;
import org.web3j.tx.response.PollingTransactionReceiptProcessor;

@Component
public class BlockchainGateway {
    private static final String ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
    private static final BigInteger GAS_PRICE = BigInteger.valueOf(1_000_000_000L);
    private static final BigInteger GAS_LIMIT = BigInteger.valueOf(700_000L);

    private final Web3j web3j;
    private final ChainProperties properties;
    private final ObjectMapper objectMapper;

    public BlockchainGateway(Web3j web3j, ChainProperties properties, ObjectMapper objectMapper) {
        this.web3j = web3j;
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    public String submitInvestorVerification(String walletAddress, String kycReference) {
        return simulatedHash("kyc", walletAddress + kycReference);
    }

    public CreateSettlementResult createSettlement(
        String sellerWallet,
        String buyerWallet,
        BigDecimal assetAmount,
        BigDecimal paymentAmount,
        String tradeReference
    ) {
        try {
            Credentials sellerCredentials = Credentials.create(properties.sellerPrivateKey());
            if (!sellerCredentials.getAddress().equalsIgnoreCase(sellerWallet)) {
                throw new IllegalArgumentException("sellerWallet must match the configured Anvil seller account");
            }

            String escrowAddress = settlementEscrowAddress();
            BigInteger nextSettlementId = readNextSettlementId(sellerCredentials.getAddress(), escrowAddress);
            BigInteger assetBaseUnits = toBaseUnits(assetAmount, properties.assetDecimals());
            BigInteger paymentBaseUnits = toBaseUnits(paymentAmount, properties.paymentDecimals());

            Function createSettlement = new Function(
                "createSettlement",
                List.of(new Address(buyerWallet), new Uint256(assetBaseUnits), new Uint256(paymentBaseUnits), new Utf8String(tradeReference)),
                List.of(new TypeReference<Uint256>() {})
            );

            String data = FunctionEncoder.encode(createSettlement);
            TransactionManager transactionManager = new RawTransactionManager(web3j, sellerCredentials, properties.chainId());
            EthSendTransaction sentTransaction = transactionManager.sendTransaction(
                GAS_PRICE,
                GAS_LIMIT,
                escrowAddress,
                data,
                BigInteger.ZERO
            );

            if (sentTransaction.hasError()) {
                throw new IllegalStateException(sentTransaction.getError().getMessage());
            }

            TransactionReceipt receipt = new PollingTransactionReceiptProcessor(web3j, 1_000, 30)
                .waitForTransactionReceipt(sentTransaction.getTransactionHash());

            if (!receipt.isStatusOK()) {
                throw new IllegalStateException("Settlement transaction reverted: " + receipt.getTransactionHash());
            }

            return new CreateSettlementResult(nextSettlementId, receipt.getTransactionHash());
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to create settlement on local Anvil", exception);
        }
    }

    public String approveSettlement(Long settlementId) {
        return simulatedHash("approve-settlement", settlementId.toString());
    }

    public String health() {
        return web3j.getClass().getSimpleName();
    }

    private String simulatedHash(String operation, String seed) {
        return "simulated-" + operation + "-" + Integer.toHexString(seed.hashCode());
    }

    private BigInteger readNextSettlementId(String fromAddress, String escrowAddress) throws Exception {
        Function nextSettlementId = new Function("nextSettlementId", List.of(), List.of(new TypeReference<Uint256>() {}));
        EthCall call = web3j.ethCall(
            Transaction.createEthCallTransaction(fromAddress, escrowAddress, FunctionEncoder.encode(nextSettlementId)),
            DefaultBlockParameterName.LATEST
        ).send();

        if (call.hasError()) {
            throw new IllegalStateException(call.getError().getMessage());
        }

        List<Type> decoded = FunctionReturnDecoder.decode(call.getValue(), nextSettlementId.getOutputParameters());
        return (BigInteger) decoded.get(0).getValue();
    }

    private BigInteger toBaseUnits(BigDecimal amount, int decimals) {
        return amount.movePointRight(decimals).setScale(0, RoundingMode.UNNECESSARY).toBigIntegerExact();
    }

    private String settlementEscrowAddress() throws Exception {
        if (properties.settlementEscrow() != null && !ZERO_ADDRESS.equalsIgnoreCase(properties.settlementEscrow())) {
            return properties.settlementEscrow();
        }

        Path configuredPath = Path.of(properties.deploymentFile());
        Path fallbackPath = Path.of("deployments", "anvil.json");
        Path deploymentPath = Files.exists(configuredPath) ? configuredPath : fallbackPath;

        if (!Files.exists(deploymentPath)) {
            throw new IllegalStateException("Deployment file not found: " + properties.deploymentFile());
        }

        Map<String, Object> deployment = objectMapper.readValue(
            deploymentPath.toFile(),
            new com.fasterxml.jackson.core.type.TypeReference<>() {}
        );
        Object address = deployment.get("settlementEscrow");
        if (address == null) {
            throw new IllegalStateException("settlementEscrow missing from deployment file");
        }
        return address.toString();
    }

    public record CreateSettlementResult(BigInteger settlementId, String transactionHash) {
    }
}
