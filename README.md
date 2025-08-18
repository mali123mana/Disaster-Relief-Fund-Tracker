# 🚨 Disaster Relief Fund Tracker

A decentralized smart contract built on Stacks blockchain for transparent disaster relief fund management and donation tracking.

## ✨ Features

- 🎯 **Campaign Creation**: Create disaster relief campaigns with targets and deadlines
- 💰 **Direct Donations**: Donate STX directly to campaign creators
- 📊 **Progress Tracking**: Real-time tracking of fundraising progress
- ⏰ **Time Management**: Automatic campaign status updates based on deadlines
- 🏆 **Transparent Records**: All donations and campaigns stored on-chain
- 📈 **Statistics**: Track total donations and campaign metrics

## 🚀 Quick Start

### Creating a Campaign

```clarity
(contract-call? .disaster-relief-fund-tracker create-campaign 
  "Hurricane Relief Fund" 
  "Emergency fund for hurricane victims in affected areas" 
  u1000000 ;; Target: 1,000,000 microSTX
  u144 ;; Duration: 144 blocks (~24 hours)
)
```

### Making a Donation

```clarity
(contract-call? .disaster-relief-fund-tracker donate 
  u1 ;; Campaign ID
  u100000 ;; Amount: 100,000 microSTX
)
```

### Checking Campaign Status

```clarity
(contract-call? .disaster-relief-fund-tracker get-campaign u1)
```

## 📋 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-campaign` | Create a new relief campaign | title, description, target-amount, duration |
| `donate` | Donate to an active campaign | campaign-id, amount |
| `update-campaign-status` | Update campaign status based on time/target | campaign-id |
| `extend-campaign` | Extend campaign deadline (creator only) | campaign-id, additional-duration |

### Read-Only Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `get-campaign` | Get campaign details | campaign-id |
| `get-donation` | Get donation details | campaign-id, donor |
| `get-donor-stats` | Get donor statistics | donor |
| `get-campaign-progress` | Get campaign progress percentage | campaign-id |
| `is-campaign-active` | Check if campaign is active | campaign-id |
| `get-total-campaigns` | Get total number of campaigns | - |
| `get-total-donated` | Get total amount donated | - |
| `get-contract-stats` | Get overall contract statistics | - |

## 🏗️ Development

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet)
- Node.js and npm

### Setup

```bash
git clone <repository-url>
cd disaster-relief-fund-tracker
```

### Testing

```bash
clarinet check
npm install
npm test
```

## 📊 Campaign States

- **🟢 active**: Campaign is running and accepting donations
- **✅ completed**: Campaign reached its target amount  
- **⏰ expired**: Campaign deadline has passed

## 💡 Usage Examples

### 🆕 Create Emergency Fund Campaign

```clarity
;; Create a 7-day emergency fund campaign
(contract-call? .disaster-relief-fund-tracker create-campaign 
  "Earthquake Emergency Fund" 
  "Immediate relief for earthquake victims requiring shelter and medical aid" 
  u5000000 
  u1008) ;; ~7 days
```

### 🎯 Check Campaign Progress

```clarity
;; Get detailed progress of campaign #1
(contract-call? .disaster-relief-fund-tracker get-campaign-progress u1)
;; Returns: {progress-percentage: u25, raised: u250000, target: u1000000}
```

### 📊 View Donor Statistics

```clarity
;; Check your donation history
(contract-call? .disaster-relief-fund-tracker get-donor-stats 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
```

## 🔒 Security Features

- ✅ Input validation for all parameters
- ✅ Authorization checks for campaign management
- ✅ Automatic status updates prevent manipulation  
- ✅ Direct STX transfers to campaign creators
- ✅ Immutable donation records

## 🚨 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Only contract owner can perform this action |
| u101 | `err-not-found` | Campaign or resource not found |
| u102 | `err-unauthorized` | Unauthorized action |
| u103 | `err-invalid-amount` | Invalid donation amount |
| u104 | `err-campaign-expired` | Campaign has expired |
| u105 | `err-campaign-completed` | Campaign already completed |
| u106 | `err-insufficient-funds` | Insufficient funds for operation |
| u107 | `err-invalid-target` | Invalid target amount |
| u108 | `err-invalid-duration` | Invalid campaign duration |



## 📄 License

MIT License - see LICENSE file for details.

---

**🌟 Help make disaster relief transparent and efficient with blockchain technology!**
