# Onchain Summer 2025 - Base Deployment

🚀 **Successfully deployed smart contract on Base Sepolia testnet!**

## 📋 Project Overview

This project demonstrates smart contract deployment on Base network as part of the Onchain Summer 2025 initiative. The contract showcases basic functionality including message storage, ownership management, and event emission.

## 🎯 Contract Details

- **Contract Name:** OnchainSummer2025
- **Contract Address:** `0x047Ff63fd6673E4bBFbc5e1938f6239587a5CaAf`
- **Network:** Base Sepolia Testnet (Chain ID: 84532)
- **Deployment Date:** January 2025
- **Status:** ✅ Verified on Sourcify

## 🔗 Contract Functions

### Public Functions
- `message()` - Returns the current stored message
- `owner()` - Returns the contract owner address
- `deploymentTime()` - Returns the deployment timestamp
- `getInfo()` - Returns comprehensive contract information
- `updateMessage(string)` - Updates the message (owner only)

### Events
- `MessageUpdated(string, address)` - Emitted when message is updated

## 🛠️ Technical Stack

- **Solidity:** ^0.8.19
- **Framework:** Foundry
- **Network:** Base Sepolia
- **Verification:** Sourcify

## 📁 Project Structure

```
base-contract/
├── src/
│   └── OnchainSummer2025.sol    # Main contract
├── script/
│   └── Deploy.s.sol            # Deployment script
├── test/
│   └── Counter.t.sol           # Test files
├── foundry.toml                # Foundry configuration
├── env.example                 # Environment variables template
└── .gitignore                  # Git ignore rules
```

## 🚀 Deployment Process

1. **Contract Creation:** Developed OnchainSummer2025.sol with basic functionality
2. **Environment Setup:** Configured Base Sepolia RPC endpoints
3. **Secure Deployment:** Used Foundry with environment variables for private key
4. **Verification:** Successfully verified contract on Sourcify
5. **Documentation:** Created comprehensive project documentation

## 🔒 Security Features

- ✅ **Owner-only functions** - Critical functions restricted to contract owner
- ✅ **Secure deployment** - Private keys managed via environment variables
- ✅ **Input validation** - Proper access control and error handling
- ✅ **Event logging** - Transparent activity tracking

## 🌐 View Contract

- **Base Sepolia Explorer:** [View Contract](https://sepolia.basescan.org/address/0x047Ff63fd6673E4bBFbc5e1938f6239587a5CaAf)

## 🎉 Base Guild Entry

This deployment serves as proof of building on Base network and qualifies for Base Guild membership. The verified contract demonstrates:

- Smart contract development skills
- Base network deployment experience
- Security best practices
- Onchain development workflow

## 📝 Next Steps

- [ ] Join Base Guild with deployment proof
- [ ] Explore additional Base ecosystem tools
- [ ] Build more complex onchain applications
- [ ] Contribute to Base developer community

---

**Built with ❤️ for Onchain Summer 2025**