# Maldo Contracts

Smart contracts for the Maldo decentralized marketplace

## Core Components

### Registry Contract (`Registry.sol`)

**User Management:**
- `setProfile(string)` - Profile management (IPFS hash or string)

**Service Management:**
- `addService(string)` - Create service listings
- `updateService(uint40, string)` - Update service descriptions (tasker only)

**Deal & Rating System:**
- `createDeal(uint40, uint256, address, uint256, string)` - Create deals with escrow integration (serviceId, price, beneficiary, duration, agreementURI)
- `rate(uint40, uint8, string)` - Dual-party rating system (1-5 scale)
- `dispute(uint40)` - Dispute resolution system

## Architecture

**Data Structures:**
- **Users:** Profile mapping
- **Services:** ID, tasker, description
- **Deals:** ID, service reference, beneficiary, escrow agreement ID, price
- **DealReviews:** Tasker rating/review + customer rating/review per deal (1-5 scale)

**External Dependencies:**
- Kleros' escrow-2: https://github.com/kleros/escrow-v2/

**Commands:**
```bash
forge build                    # Compile contracts
forge test                     # Run test suite
forge coverage                 # Generate coverage report
forge test --gas-report        # Gas usage analysis
```