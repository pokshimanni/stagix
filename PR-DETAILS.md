# Stagix: Community Theater Funding Smart Contracts

## Overview

This pull request introduces **Stagix**, a comprehensive community theater funding system built with Clarity smart contracts on the Stacks blockchain. The system enables transparent ticket pooling where supporters can contribute funds to theater productions and receive tickets based on their contribution levels.

## Features Implemented

### 🎭 Production Management (`production-manager.clar`)
- **Campaign Creation**: Theater organizers can create funding campaigns with customizable goals and deadlines
- **Transparent Funding**: Community members contribute STX tokens with full transparency  
- **Automatic Goal Tracking**: System automatically tracks funding progress and completion
- **Secure Fund Release**: Funds are released to organizers only when goals are met
- **Refund Protection**: Automatic refunds if campaigns fail to meet goals by deadline
- **Contributor Management**: Tracks all contributors and their contribution amounts

### 🎟️ Ticket Allocation (`ticket-allocator.clar`)
- **Tiered Ticketing**: Three ticket types (General, VIP, Premium) based on contribution levels
- **Fair Distribution**: Tickets allocated proportionally to contribution amounts
- **Transfer System**: Tickets can be transferred between holders when allowed
- **Usage Tracking**: Tracks ticket usage and redemption status
- **Contribution Tiers**: Bronze (0.5 STX), Silver (1 STX), Gold (2 STX), Platinum (5+ STX)

## Smart Contract Architecture

### Contract 1: Production Manager (308 lines)
- Manages theater production campaigns and funding
- Handles STX token transfers and escrow
- Implements secure fund release mechanisms
- Tracks production status and contributor metrics

### Contract 2: Ticket Allocator (413 lines)
- Manages ticket distribution based on contributions
- Implements tiered ticket allocation system
- Handles ticket transfers and usage tracking
- Provides comprehensive ticket availability queries

**Total Implementation**: 721 lines of clean, well-documented Clarity code

## Security Features

✅ **Fund Escrow**: All contributions held securely until goals are met  
✅ **Time-locked Campaigns**: Automatic expiration and refund mechanisms  
✅ **Authorization Checks**: Strict access controls for sensitive operations  
✅ **Input Validation**: Comprehensive validation of all user inputs  
✅ **State Management**: Immutable production records and funding history  

## Technical Validation

- ✅ **Syntax Check**: All contracts pass `clarinet check` validation
- ✅ **Test Suite**: Complete test coverage with passing test cases  
- ✅ **CI/CD Pipeline**: Automated GitHub workflow for continuous validation
- ✅ **Type Safety**: Full Clarity type system compliance
- ✅ **Error Handling**: Comprehensive error codes and handling

## Use Cases Supported

1. **Community Theater Funding** - Local theater groups raising production funds
2. **Performance Art Crowdfunding** - Artists securing funding for performances
3. **Venue Support** - Community-driven venue maintenance funding  
4. **Educational Theater** - Schools funding drama programs

## Contract Interaction Flow

1. **Campaign Creation** → Organizer creates production campaign
2. **Community Funding** → Supporters contribute STX tokens  
3. **Ticket Allocation** → System allocates tickets based on contribution tiers
4. **Goal Achievement** → When funded, tickets become valid for use
5. **Fund Release** → Organizer can claim funds for production costs
6. **Ticket Usage** → Contributors redeem tickets for performances

## Project Structure

```
stagix/
├── contracts/
│   ├── production-manager.clar    # Campaign and funding management
│   └── ticket-allocator.clar      # Ticket distribution system
├── tests/                         # Comprehensive test suite
├── .github/workflows/ci.yml       # CI/CD automation
└── README.md                      # Project documentation
```

## Impact & Innovation

Stagix brings **transparency** and **decentralization** to community theater funding, enabling:
- Direct community support without intermediaries
- Transparent fund tracking and allocation
- Automated ticket distribution based on contribution levels
- Secure, blockchain-based fund management
- Community-driven arts support ecosystem

This implementation demonstrates advanced Clarity programming with complex state management, secure token handling, and comprehensive business logic for real-world community funding use cases.
