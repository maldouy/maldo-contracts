# Maldo Contracts Deployment Guide

## Known Addresses (Arbitrum Sepolia)

| Contract | Address |
|----------|---------|
| **Registry** | `0xf80Ff52Db1ffF61477aada8D0E8249bAD8D9ad5F` |
| **MaldoToken** | `0x6cB0C7D81f82fb3153e2F8da55c7Ae29F96e4f53` |
| **Escrow (Kleros)** | `0xA01e6B988aeDae1fD4a748D6bfBcB8A438601DeE` |

**Explorer:** https://sepolia.arbiscan.io/address/0xf80Ff52Db1ffF61477aada8D0E8249bAD8D9ad5F

---

## Prerequisites

### 1. Install Foundry (if needed)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Set environment variables

```bash
export DEPLOYER_PRIVATE_KEY=0x<your-private-key>
export ARBITRUM_SEPOLIA_RPC=https://arb-sepolia.g.alchemy.com/v2/toYGSDKJ-o_pUOX5ovHrOKGwS78c5VaH
export ETHERSCAN_API_KEY=<your-etherscan-api-key>
```

> **Note:** Use an API key from https://etherscan.io (not Arbiscan). Etherscan API v2 uses a unified key for all chains.

### 3. Verify your deployer address

```bash
cast wallet address $DEPLOYER_PRIVATE_KEY
```

### 4. Check deployer balance

```bash
cast balance $(cast wallet address $DEPLOYER_PRIVATE_KEY) --rpc-url $ARBITRUM_SEPOLIA_RPC
```

> Need testnet ETH? Get it from https://faucet.quicknode.com/arbitrum/sepolia

---

## Deploy Registry

### Dry Run (Simulation)

```bash
forge script script/Hestia.s.sol:MaldoScript \
  --sig "fullDeploy(address)" \
  0x6cB0C7D81f82fb3153e2F8da55c7Ae29F96e4f53 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC
```

### Deploy for Real

```bash
forge script script/Hestia.s.sol:MaldoScript \
  --sig "fullDeploy(address)" \
  0x6cB0C7D81f82fb3153e2F8da55c7Ae29F96e4f53 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC \
  --broadcast \
  --verify
```

**Save the Registry address from the output!**

---

## Verify Deployment

Replace `<REGISTRY_ADDRESS>` with your deployed address:

```bash
# Check owner
cast call <REGISTRY_ADDRESS> "owner()(address)" --rpc-url $ARBITRUM_SEPOLIA_RPC

# Check token
cast call <REGISTRY_ADDRESS> "token()(address)" --rpc-url $ARBITRUM_SEPOLIA_RPC

# Check escrow
cast call <REGISTRY_ADDRESS> "escrow()(address)" --rpc-url $ARBITRUM_SEPOLIA_RPC

# Check services count
cast call <REGISTRY_ADDRESS> "servicesCount()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC

# Check deals count
cast call <REGISTRY_ADDRESS> "dealsCount()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC
```

---

## Post-Deployment: Set Dispute Resolver

```bash
cast send <REGISTRY_ADDRESS> \
  "setDisputeResolver(address)" \
  <DISPUTE_RESOLVER_ADDRESS> \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC
```

---

## Alternative: Deploy with Custom Escrow

```bash
forge script script/Hestia.s.sol:MaldoScript \
  --sig "deployRegistry(address,address)" \
  0x6cB0C7D81f82fb3153e2F8da55c7Ae29F96e4f53 \
  0xA01e6B988aeDae1fD4a748D6bfBcB8A438601DeE \
  --rpc-url $ARBITRUM_SEPOLIA_RPC \
  --broadcast \
  --verify
```

---

## Alternative: Deploy New Token

Only if you need a fresh MaldoToken:

```bash
forge script script/Hestia.s.sol:MaldoScript \
  --sig "deployTokenMaldo()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC \
  --broadcast \
  --verify
```

---

## Troubleshooting

### "Insufficient funds"
```bash
# Check balance
cast balance $(cast wallet address $DEPLOYER_PRIVATE_KEY) --rpc-url $ARBITRUM_SEPOLIA_RPC
```
Get testnet ETH from https://faucet.quicknode.com/arbitrum/sepolia

### "Contract verification failed"
```bash
forge verify-contract <REGISTRY_ADDRESS> src/contracts/Registry.sol:Registry \
  --chain 421614 \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x6cB0C7D81f82fb3153e2F8da55c7Ae29F96e4f53 0xA01e6B988aeDae1fD4a748D6bfBcB8A438601DeE <OWNER_ADDRESS>) \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch
```

### "Nonce too low"
Your wallet has pending transactions. Wait or speed them up.

### Check if contract exists
```bash
cast code <ADDRESS> --rpc-url $ARBITRUM_SEPOLIA_RPC | head -c 20
```

---

## Quick Reference

```bash
# Set env vars (run once per session)
export DEPLOYER_PRIVATE_KEY=0x<your-key>
export ARBITRUM_SEPOLIA_RPC=https://arb-sepolia.g.alchemy.com/v2/toYGSDKJ-o_pUOX5ovHrOKGwS78c5VaH
export ETHERSCAN_API_KEY=<your-etherscan-api-key>

# Deploy Registry
forge script script/Hestia.s.sol:MaldoScript --sig "fullDeploy(address)" 0x6cB0C7D81f82fb3153e2F8da55c7Ae29F96e4f53 --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast

# Verify contract (after deployment)
forge verify-contract <REGISTRY_ADDRESS> src/contracts/Registry.sol:Registry --chain 421614 --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x6cB0C7D81f82fb3153e2F8da55c7Ae29F96e4f53 0xA01e6B988aeDae1fD4a748D6bfBcB8A438601DeE <OWNER_ADDRESS>) --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY --watch
```
