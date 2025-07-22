# 🏥 Pharmaceutical Supply Chain Verification Smart Contract

A Clarity smart contract for verifying authenticity and tracking pharmaceutical products through the supply chain.

## 🎯 Purpose

This smart contract helps combat counterfeit drugs by:
- ✅ Tracking drug batches from manufacturer to pharmacy
- 🏢 Managing authorized manufacturers and distributors
- 📦 Recording supply chain checkpoints
- 🔍 Enabling public verification of drug authenticity

## 🚀 Features

- Manufacturer and distributor registry with verification
- Drug batch creation and tracking
- Supply chain event logging
- Public verification interface
- Transfer management between authorized entities

## 📋 Contract Functions

### Entity Management
- `register-manufacturer`: Register a new pharmaceutical manufacturer
- `register-distributor`: Register a new distributor
- `verify-entity`: Verify a manufacturer or distributor (owner only)

### Drug Batch Operations
- `create-drug-batch`: Create a new drug batch with unique identifier
- `transfer-batch`: Transfer batch ownership between entities
- `verify-drug-batch`: Verify a drug batch's authenticity
- `get-supply-chain-history`: Get batch transfer history

## 🔧 Usage

1. Deploy the contract to Stacks blockchain
2. Register manufacturers and distributors
3. Verify registered entities
4. Create and track drug batches
5. Verify products using batch IDs

## 🔒 Security

- Only contract owner can verify entities
- Only registered entities can participate
- Batch transfers restricted to authorized parties
```

Git commit message:
```
feat: Implement pharmaceutical supply chain verification smart contract MVP
```

PR Title:
```
✨ Add Pharmaceutical Supply Chain Verification Smart Contract
```

PR Description:
```
This PR introduces a new Clarity smart contract for pharmaceutical supply chain verification:

Key additions:
- Entity registry for manufacturers and distributors
- Drug batch creation and tracking system
- Supply chain event logging
- Public verification interface
- Transfer management between authorized entities

The implementation focuses on core functionality needed for a minimum viable product while maintaining security and auditability.

Testing completed:
- Contract deployment
- Entity registration flows
- Batch creation and transfers
- Verification functionality