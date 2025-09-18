# Stagix - Community Theater Funding Smart Contract

## Overview

Stagix is a transparent ticket pooling system built on the Stacks blockchain using Clarity smart contracts. It enables community theaters to raise funds through a decentralized ticketing system where supporters can pool funds for theater productions.

## Features

### Core Functionality
- **Transparent Fund Pooling**: Community members can contribute funds to theater productions
- **Production Management**: Theater organizers can create and manage production campaigns
- **Ticket Allocation**: Contributors receive tickets based on their funding contributions
- **Fund Distribution**: Secure release of pooled funds to theater productions
- **Refund Mechanism**: Automatic refunds if funding goals aren't met

### Smart Contract Components
1. **Production Registry**: Manages theater production campaigns
2. **Contribution Tracking**: Tracks individual and total contributions
3. **Ticket Distribution**: Handles ticket allocation based on contribution levels
4. **Fund Management**: Secure escrow and distribution of pooled funds

## How It Works

1. **Campaign Creation**: Theater groups create funding campaigns for their productions
2. **Community Funding**: Supporters contribute STX tokens to support productions
3. **Ticket Allocation**: Contributors receive tickets proportional to their contributions
4. **Goal Achievement**: When funding goals are met, productions can proceed
5. **Fund Release**: Pooled funds are released to theater groups for production costs
6. **Refund Protection**: If goals aren't met by deadline, contributors get refunds

## Technical Architecture

- **Blockchain**: Stacks (STX)
- **Language**: Clarity
- **Contract Files**: 
  - `production-manager.clar` - Handles production campaigns and funding
  - `ticket-allocator.clar` - Manages ticket distribution and allocation

## Smart Contract Security

- Funds are held in secure escrow until funding goals are met
- Time-locked campaigns with automatic refund mechanisms
- Transparent contribution tracking on-chain
- Immutable production records and funding history

## Use Cases

- **Community Theater Funding**: Local theater groups raising production funds
- **Performance Art Crowdfunding**: Artists securing funding for performances  
- **Venue Support**: Community-driven venue maintenance and improvement
- **Educational Theater**: Schools and educational institutions funding drama programs

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd stagix
npm install
```

### Testing
```bash
clarinet check
npm test
```

### Deployment
Follow Stacks documentation for mainnet deployment

## Contributing

This project welcomes contributions from the community. Please ensure all contracts pass `clarinet check` before submitting.

## License

This project is open-source and available under standard open-source licensing.

---

**Stagix** - Bringing communities together to support the arts through transparent, decentralized funding.
