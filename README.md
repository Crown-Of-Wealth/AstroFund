# AstroFund Mission Escrow

A decentralized escrow and milestone payment system for space missions, enabling transparent funding and verifiable progress through Stacks smart contracts.

## 🚀 Overview

AstroFund Mission Escrow is a blockchain-based crowdfunding platform specifically designed for space missions. It provides a trustless system where:

- **Mission Proposers** can create funding campaigns for space exploration projects
- **Funders** can contribute STX tokens with confidence that funds are held securely
- **Committee Members** verify milestone achievements before releasing funds
- **Transparent Operations** ensure all actions are recorded on-chain

## ✨ Key Features

### 🎯 Mission Management
- **Propose Missions**: Anyone can propose a space mission with a funding target
- **Fund Missions**: Community members can contribute STX to support missions
- **Milestone Tracking**: Break missions into verifiable milestones
- **Status Monitoring**: Track mission progress from proposal to completion

### 🔐 Secure Escrow
- **Smart Contract Custody**: Funds held securely in the contract
- **Multi-Signature Approvals**: Committee consensus required for fund releases
- **Proportional Refunds**: Fair distribution if missions are canceled
- **Transparent Accounting**: All contributions and disbursements tracked on-chain

### 👥 Decentralized Governance
- **Committee-Based Approval**: Multiple validators must approve milestones
- **Configurable Thresholds**: Adjustable approval requirements
- **Role-Based Access**: Clear separation of responsibilities
- **Community Oversight**: Public verification of all actions

## 📋 Contract Specifications

### Version
- **Contract Version**: 1.0
- **Clarity Version**: Compatible with Clarinet 0.31.1
- **Language**: Clarity

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `ERR-NOT-AUTHORIZED` | Caller lacks permission for this action |
| 101 | `ERR-INVALID-MISSION-ID` | Mission ID does not exist |
| 102 | `ERR-MISSION-NOT-PROPOSED` | Mission is not in proposed state |
| 103 | `ERR-MISSION-NOT-ACTIVE` | Mission is not active |
| 104 | `ERR-MISSION-ALREADY-FUNDED` | Mission has already been funded |
| 105 | `ERR-MISSION-ALREADY-CANCELED` | Mission has been canceled |
| 106 | `ERR-INSUFFICIENT-FUNDS` | Insufficient funds for operation |
| 107 | `ERR-INVALID-MILESTONE-ID` | Milestone ID does not exist |
| 108 | `ERR-MILESTONE-ALREADY-ACHIEVED` | Milestone already marked as achieved |
| 109 | `ERR-MILESTONE-ALREADY-PAID` | Milestone payment already processed |
| 110 | `ERR-MILESTONE-NOT-APPROVED` | Milestone not yet approved |
| 111 | `ERR-INSUFFICIENT-APPROVERS` | Not enough committee approvals |
| 112 | `ERR-ALREADY-APPROVED` | Already approved by this committee member |
| 113 | `ERR-COMMITTEE-MEMBER-ALREADY-REGISTERED` | Member already in committee |
| 114 | `ERR-COMMITTEE-MEMBER-NOT-REGISTERED` | Member not in committee |
| 115 | `ERR-INVALID-INPUT` | Invalid input parameter |
| 116 | `ERR-ZERO-ADDRESS` | Zero address not allowed |
| 117 | `ERR-MISSION-NAME-TOO-LONG` | Mission name exceeds 100 characters |
| 118 | `ERR-MILESTONE-DESCRIPTION-TOO-LONG` | Milestone description exceeds 256 characters |
| 119 | `ERR-PAYOUT-AMOUNT-EXCEEDS-REMAINING-FUNDS` | Payout exceeds available funds |
| 120 | `ERR-REFUND-ALREADY-PROCESSED` | Refund already claimed |
| 121 | `ERR-MISSION-NOT-CANCELED` | Mission must be canceled for this action |
| 122 | `ERR-CANNOT-SET-ZERO-APPROVALS` | Approval threshold must be > 0 |
| 123 | `ERR-MILESTONE-AMOUNT-EXCEEDS-MISSION-TARGET` | Milestone exceeds mission target |
| 124 | `ERR-TRANSFER-FAILED` | STX transfer failed |

### Mission Status Values

- **Proposed**: Mission created but not yet funded
- **Active**: Mission has received funding and is in progress
- **Canceled**: Mission has been canceled by owner or committee
- **Completed**: All milestones achieved (future implementation)

## 🔧 Public Functions

### Administration Functions

#### `add-committee-member`
```clarity
(define-public (add-committee-member (new-member principal)))
```
Adds a new principal to the committee. Only contract owner can call.

**Parameters:**
- `new-member`: Principal address to add

**Returns:** `(ok true)` on success

---

#### `remove-committee-member`
```clarity
(define-public (remove-committee-member (existing-member principal)))
```
Removes a principal from the committee. Only contract owner can call.

**Parameters:**
- `existing-member`: Principal address to remove

**Returns:** `(ok true)` on success

---

#### `set-required-approvals`
```clarity
(define-public (set-required-approvals (num-approvals uint)))
```
Sets the number of committee approvals required for milestone releases.

**Parameters:**
- `num-approvals`: Number of approvals required (must be > 0)

**Returns:** `(ok true)` on success

---

### Mission Management Functions

#### `propose-mission`
```clarity
(define-public (propose-mission (mission-name (string-ascii 100)) (funding-target uint)))
```
Creates a new mission proposal.

**Parameters:**
- `mission-name`: Name of the mission (max 100 characters)
- `funding-target`: Total STX needed for the mission

**Returns:** `(ok mission-id)` with the new mission ID

**Example:**
```clarity
(contract-call? .astrofund-mission-escrow propose-mission "Mars Sample Return" u1000000)
```

---

#### `fund-mission`
```clarity
(define-public (fund-mission (mission-id uint) (amount uint)))
```
Contributes STX to a mission. Automatically activates mission on first funding.

**Parameters:**
- `mission-id`: ID of the mission to fund
- `amount`: Amount of STX to contribute

**Returns:** `(ok true)` on success

**Example:**
```clarity
(contract-call? .astrofund-mission-escrow fund-mission u1 u50000)
```

---

#### `add-milestone`
```clarity
(define-public (add-milestone (mission-id uint) (description (string-ascii 256)) (amount-to-release uint)))
```
Adds a new milestone to a mission. Only mission proposer can call.

**Parameters:**
- `mission-id`: ID of the mission
- `description`: Milestone description (max 256 characters)
- `amount-to-release`: STX to release when milestone is achieved

**Returns:** `(ok milestone-id)` with the new milestone ID

**Example:**
```clarity
(contract-call? .astrofund-mission-escrow add-milestone u1 "Launch vehicle ready" u100000)
```

---

#### `approve-milestone`
```clarity
(define-public (approve-milestone (milestone-id uint)))
```
Approves a milestone as achieved. Only committee members can call.

**Parameters:**
- `milestone-id`: ID of the milestone to approve

**Returns:** `(ok true)` on success

---

#### `release-milestone-funds`
```clarity
(define-public (release-milestone-funds (milestone-id uint)))
```
Releases funds for an approved milestone. Only mission proposer can call.

**Parameters:**
- `milestone-id`: ID of the milestone to release funds for

**Returns:** `(ok true)` on success

**Requirements:**
- Milestone must have sufficient committee approvals
- Mission must have sufficient funds
- Milestone must not already be paid

---

#### `cancel-mission`
```clarity
(define-public (cancel-mission (mission-id uint)))
```
Cancels a mission. Only contract owner or committee members can call.

**Parameters:**
- `mission-id`: ID of the mission to cancel

**Returns:** `(ok true)` on success

---

#### `withdraw-from-canceled-mission`
```clarity
(define-public (withdraw-from-canceled-mission (mission-id uint)))
```
Allows funders to withdraw their proportional share from a canceled mission.

**Parameters:**
- `mission-id`: ID of the canceled mission

**Returns:** `(ok refund-amount)` with the amount refunded

**Calculation:**
```
refund = (your_contribution / total_target) × remaining_funds
```

---

## 📖 Read-Only Functions

### `get-mission-details`
```clarity
(define-read-only (get-mission-details (mission-id uint)))
```
Returns all details for a mission.

**Returns:**
```clarity
{
  mission-name: (string-ascii 100),
  proposer: principal,
  total-funding-target: uint,
  current-funds-held: uint,
  status: (string-ascii 50)
}
```

---

### `get-milestone-details`
```clarity
(define-read-only (get-milestone-details (milestone-id uint)))
```
Returns all details for a milestone.

**Returns:**
```clarity
{
  mission-id: uint,
  description: (string-ascii 256),
  amount-to-release: uint,
  is-achieved: bool,
  is-paid: bool
}
```

---

### `get-milestone-approval-count`
```clarity
(define-read-only (get-milestone-approval-count (milestone-id uint)))
```
Returns the current number of approvals for a milestone.

---

### `is-account-committee-member`
```clarity
(define-read-only (is-account-committee-member (account principal)))
```
Checks if an account is a committee member.

---

### `get-required-approvals-count`
```clarity
(define-read-only (get-required-approvals-count))
```
Returns the current approval threshold.

---

### `get-funder-contribution`
```clarity
(define-read-only (get-funder-contribution (mission-id uint) (funder principal)))
```
Returns total contributions by a funder to a specific mission.

---

### `has-funder-refunded`
```clarity
(define-read-only (has-funder-refunded (mission-id uint) (funder principal)))
```
Checks if a funder has already claimed their refund for a canceled mission.

---

### `get-contract-owner`
```clarity
(define-read-only (get-contract-owner))
```
Returns the contract owner's principal.

---

### `get-next-mission-id` / `get-next-milestone-id`
Returns the next available ID for missions/milestones.

---

## 🎯 Usage Examples

### Complete Mission Lifecycle

```clarity
;; 1. Propose a mission
(contract-call? .astrofund-mission-escrow propose-mission "Lunar Observatory" u5000000)
;; Returns: (ok u1) - Mission ID 1 created

;; 2. Fund the mission
(contract-call? .astrofund-mission-escrow fund-mission u1 u1000000)
(contract-call? .astrofund-mission-escrow fund-mission u1 u2000000)
;; Mission now has 3M STX funded

;; 3. Add milestones (by proposer)
(contract-call? .astrofund-mission-escrow add-milestone u1 "Site selection complete" u500000)
(contract-call? .astrofund-mission-escrow add-milestone u1 "Equipment deployed" u1500000)
(contract-call? .astrofund-mission-escrow add-milestone u1 "First observations" u2000000)

;; 4. Committee approves milestone
(contract-call? .astrofund-mission-escrow approve-milestone u1)
;; Multiple committee members approve...

;; 5. Release milestone funds (by proposer)
(contract-call? .astrofund-mission-escrow release-milestone-funds u1)
;; 500K STX transferred to proposer

;; 6. If mission needs to be canceled
(contract-call? .astrofund-mission-escrow cancel-mission u1)

;; 7. Funders can withdraw remaining funds
(contract-call? .astrofund-mission-escrow withdraw-from-canceled-mission u1)
;; Returns proportional refund
```

## 🔒 Security Features

### Input Validation
- All user inputs are validated before use
- String length limits enforced
- Amount validation (no zero or negative values)
- Mission/milestone existence checks

### Access Control
- **Contract Owner**: Can manage committee members and settings
- **Mission Proposer**: Can add milestones and release funds
- **Committee Members**: Can approve milestones
- **Funders**: Can contribute and withdraw from canceled missions

### Fund Safety
- Funds held in contract custody using `as-contract`
- Multi-signature approval required for releases
- Proportional refund mechanism for canceled missions
- Prevents double-spending with status checks

### Static Analysis
- Zero warnings from Clarinet static analyzer
- No unchecked data warnings
- Validated local variables for all map operations
- Proper error handling throughout

## 🧪 Testing

### Prerequisites
```bash
clarinet --version
# Should be 0.31.1 or compatible
```

### Run Tests
```bash
# Check contract syntax and security
clarinet check

# Run unit tests (create test file first)
clarinet test

# Start local devnet
clarinet integrate
```

### Test Coverage Checklist
- [ ] Mission proposal creation
- [ ] Multiple funders contributing
- [ ] Milestone creation by proposer
- [ ] Committee approval process
- [ ] Fund release with sufficient approvals
- [ ] Mission cancellation
- [ ] Proportional refund calculation
- [ ] Access control enforcement
- [ ] Error handling for all edge cases

## 📊 Data Structures

### Mission Data
```clarity
{
  mission-name: (string-ascii 100),
  proposer: principal,
  total-funding-target: uint,
  current-funds-held: uint,
  status: (string-ascii 50)
}
```

### Milestone Data
```clarity
{
  mission-id: uint,
  description: (string-ascii 256),
  amount-to-release: uint,
  is-achieved: bool,
  is-paid: bool
}
```

### Maps
- `mission-data`: mission-id → Mission Data
- `milestones`: milestone-id → Milestone Data
- `milestone-approvals`: (milestone-id, approver) → bool
- `committee-members`: principal → bool
- `funder-contributions`: (mission-id, funder) → uint
- `funder-refunds`: (mission-id, funder) → bool

## 🚧 Known Limitations

1. **Approval Counting**: Current implementation uses a simplified approval count. In production, maintain a list of committee members for accurate counting.

2. **Milestone Sum Check**: The contract validates individual milestones against mission target but doesn't track cumulative milestone amounts across all milestones.

3. **Time-Based Features**: No automatic expiration or time-locked milestones (requires oracle integration).

4. **Partial Refunds**: Refund calculation assumes proportional distribution based on remaining funds. Complex spending patterns may require more sophisticated calculations.

## 🛣️ Roadmap

- [ ] Add mission completion status when all milestones are paid
- [ ] Implement time-based milestone deadlines
- [ ] Add milestone evidence/proof submission system
- [ ] Create dispute resolution mechanism
- [ ] Add mission categories and search functionality
- [ ] Implement reputation system for proposers
- [ ] Add optional milestone voting by funders
- [ ] Create emergency pause functionality

## 📝 License

This smart contract is provided as-is for educational and demonstration purposes. Please conduct thorough audits before using in production with real funds.

## 🤝 Contributing

Contributions are welcome! Please ensure:
1. All changes pass `clarinet check` with zero warnings
2. Comprehensive test coverage for new features
3. Updated documentation for API changes
4. Security considerations documented

## 📞 Support

For issues, questions, or contributions:
- Open an issue on the repository
- Review existing documentation
- Check Stacks/Clarity documentation: https://docs.stacks.co/

## ⚠️ Disclaimer

This smart contract handles financial transactions. Users should:
- Understand the risks of blockchain transactions
- Verify contract code before interacting
- Use test networks for experimentation
- Conduct security audits before production deployment
- Never invest more than you can afford to lose

**This contract has not been professionally audited. Use at your own risk.**

---

Built with ❤️ for the decentralized space exploration community