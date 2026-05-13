# TON NFT Marketplace Contract Addresses
> Last updated: 2026-05-13
> Status: Active research — update as addresses are confirmed

## Verified Addresses

### ✅ Getgems (getgems.io)
**Source**: https://github.com/getgems-io/nft-contracts (official)

| Role | Address | Notes |
|------|---------|-------|
| Marketplace (nft-fixprice-sale-v4r1) | `EQBYTuYbLf8INxFtD8tQeNk5ZLy-nAX9ahQbG_yl1qQ-GEMS` | Main marketplace contract |
| Marketplace Fee Collector (5%) | `EQCjk1hh952vWaE9bRguFkAhDAL5jj3xj9p0uPWrFBq-GEMS` | Royalty receiver |
| NFT Auction v4r1 code hash | `ce5a78534eaaa6ceed8dafd486d076eb60a9b0d6dbfb53676f662649c0689956` (hex) | Alternative match |
| NFT FixPrice Sale v4r1 code hash | `6B95A6418B9C9D2359045D1E7559B8D549AE0E506F24CAAB58FA30C8FB1FEB86` (hex) | Alternative match |

**Marketplace fee**: 5% (marketplaceFeeFactor: 5, marketplaceFeeBase: 100)

---

## Unverified (TODO)

### 🔴 Fragment (fragment.com)
- Telegram's official marketplace for usernames and phone numbers
- Also handles Collectible Gift (NFT) trades
- **How to verify**: Check fragment.com/about or use TON Explorer to look up any known Fragment transaction
- Alternative: Search Dune for transactions involving Fragment's known contract patterns

### 🔴 Disintar (disintar.io)
- Popular among Chinese TON NFT users
- **How to verify**: Look at a sample transaction from disintar.io on tonwhales.com or tonviewer.com
- Need a real Disintar transaction hash to extract contract address

### 🔴 TONNEL (tonnel.network)
- TON NFT marketplace
- **How to verify**: Check their GitHub or docs for contract addresses

### 🔴 Portals
- NFT marketplace aggregator
- **How to verify**: Check portals.io/about or GitHub

---

## Verification Methods

1. **Ton Explorer**: https://tonviewer.com — look at any NFT trade from the marketplace
2. **Dune existing dashboards**: Search for existing TON NFT dashboards that reference these addresses
3. **Official GitHub repos**: Check each marketplace's open-source contract repo
4. **TON Whales**: https://tonwhales.com — explorer with contract metadata

---

## Dune Query Strategy

In Dune `ton.messages`, addresses are stored in **user-friendly format** (EQ/EQC prefix).
To match a marketplace by contract address:

```sql
-- Match via source or destination of the trade transaction
LEFT JOIN ton.messages m ON m.tx_hash = e.tx_hash
WHERE m.source LIKE 'EQBYTuYbLf8%'  -- Getgems marketplace
   OR m.destination LIKE 'EQBYTuYbLf8%'
```

**Alternative approach** (code hash matching if addresses don't work):
```sql
-- Match by contract code hash instead of address
WHERE m.code_hash = '6B95A6418B9C9D2359045D1E7559B8D549AE0E506F24CAAB58FA30C8FB1FEB86'
```

---

## Market Coverage (per #1227 proposal)
- Fragment: Telegram usernames + Collectible Gifts
- Getgems: ✅ Address confirmed
- Disintar: Chinese user base, high volume
- Portals: Aggregator
- TONNEL: Secondary market