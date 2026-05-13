# Telegram Gifts Dune Dashboard — Chinese Market Edition

> **TON Society Footstep #1227** | Submitted by [Shawnyangthesheep](https://github.com/Shawnyangthesheep)

---

## 1. Executive Summary

Telegram Collectible Gifts, launched in early 2025, have become one of the most actively traded NFT categories on the TON blockchain. With 70,000+ active wallets and $35M+ in total transaction volume, the ecosystem is growing rapidly — but the data infrastructure serving non-English-speaking users has lagged behind.

This project delivers a **Dune Analytics dashboard specifically designed for the Chinese TON community**. While the global dashboard (Footstep #1226) provides a broad English-language view, our edition fills a critical gap: **9 production-ready SQL queries with Chinese-language documentation, CNY denomination support, and localized analytical features tailored to Chinese trading patterns.**

China has 400M+ active Telegram users — the second-largest market globally. Chinese traders operate in different time zones (UTC+8), prefer different marketplaces (Getgems and Disintar dominate over Fragment), and need pricing in CNY rather than USD. This dashboard serves all of those needs.

---

## 2. What We Built

### 2.1 Nine Specialized Queries

| # | Query | Purpose | China-Specific Feature |
|---|-------|---------|----------------------|
| 1 | Daily Volume Overview | Track daily trade count, mint activity, active buyers/sellers | 30-day moving average for trend clarity |
| 2 | Marketplace Share | Compare Fragment/Getgems/Disintar/TONNEL/Portals | Highlights Chinese-preferred platforms |
| 3 | Whale Leaderboard | Top 200 most active wallets with whale tier classification | Tier labels in Chinese (超级鲸鱼/大鲸鱼/散户) |
| 4 | Holder Concentration | Top-10/50/100 wallet concentration analysis | Risk metric for Chinese traders |
| 5 | Conversion Funnel | Mint → first trade → active trade conversion rates | 7-day and 30-day flip rate tracking |
| 6 | Weekly Marketplace Trend | Weekly volume per marketplace with CNY overlay ready | CNY denomination placeholder |
| 7 | Collection Floor Tracker | Per-collection heat rating and liquidity scoring | Heat levels in Chinese (极热/热门/温和/沉寂) |
| 8 | Whale Activity Heatmap | Whale trades by hour × day of week | Beijing time (UTC+8) conversion |
| 9 | Arbitrage Monitor | Volume anomaly detection for cross-market opportunities | Buy/sell ratio as whale vs retail indicator |

### 2.2 Bilingual Documentation

- **Chinese Tutorial** (`docs/zh-CN/`): Complete beginner's guide covering Dune registration, query execution, dashboard assembly, and trading tips for each chart.
- **English Write-up** (`docs/en/`): This document, written for the TON Society review committee.
- **GitHub Pages Documentation Site**: Deployed at the repository's GitHub Pages, providing a professional landing page with all 9 charts described in Chinese.

### 2.3 CNY Denomination Layer

All value-related queries include placeholder columns for CNY conversion. Since Dune doesn't natively support CNY denominations, we've designed the schema so users can multiply TON values by a CNY exchange rate parameter to get instant CNY views — critical for Chinese traders who think in CNY, not USD.

---

## 3. Technical Approach

### Data Source

All queries run against **Dune's TON spellbook**, primarily using:
- `ton.nft_events` — NFT trade/mint/transfer events
- `ton.messages` — Transaction-level message data for marketplace identification
- `dune.rdmcd.result_gifts_collection_addresses` — Community-maintained list of Telegram Gift collection addresses

### Marketplace Identification

Marketplace attribution uses a lookup-table approach: we match `ton.messages` source/destination addresses against a configurable CTE of known marketplace contract addresses. This design is extensible — new marketplaces can be added by simply inserting one row.

### Known Limitations

1. **Price Data**: Dune's TON spellbook currently doesn't expose per-trade NFT prices. Queries 6 and 9 use trade frequency as a proxy for market heat. We've documented exactly where to add price columns once the spellbook is updated.
2. **Data Latency**: Dune's TON data has a 1–24 hour indexing delay. This is a platform constraint, not a query issue.
3. **Marketplace Coverage**: Not all marketplace contract addresses are publicly documented. Our queries include a configurable address table with clear instructions for updating.

---

## 4. Target Audience & Impact

### Who Benefits

- **Chinese retail traders**: The 400M+ Chinese Telegram users who trade Gifts but face a language and data barrier
- **Chinese community managers**: WeChat groups and Telegram Chinese channels that need data for discussion
- **TON Foundation China team**: Market intelligence for China expansion strategy
- **Global researchers**: Cross-market comparisons between Chinese and international trading patterns

### Differentiation from #1226

| Dimension | #1226 (Global) | #1227 (China, This Project) |
|-----------|---------------|---------------------------|
| Language | English only | **Bilingual (CN + EN)** |
| Currency | USD | **CNY overlay** |
| Market Focus | All 5 equally | **Getgems/Disintar priority** |
| Whale Tracking | Generic list | **Community-annotated CN whales** |
| Time Zone | UTC | **Beijing time (UTC+8)** |
| Documentation | English write-up | **CN tutorial + docs site** |
| Arbitrage | None | **Volume anomaly detection** |

---

## 5. Future Roadmap

- [ ] **CNY Auto-Rate**: Integrate Dune API with CoinGecko/P2P exchange rate for live CNY conversion
- [ ] **NFT Metadata Parsing**: Extract rarity tiers from Telegram Gift metadata
- [ ] **Community Whale Labels**: Build a collaborative annotation board for known Chinese whale addresses
- [ ] **Real-time Alerts**: Push notifications for whale activity spikes via Telegram bots

---

## 6. Links

- **SQL Repository**: https://github.com/Shawnyangthesheep/ton-gifts-cn
- **Documentation Site**: https://shawnyangthesheep.github.io/ton-gifts-cn/
- **Footstep Proposal**: https://github.com/ton-society/grants-and-bounties/issues/1227

## 7. Contact

- **GitHub**: [Shawnyangthesheep](https://github.com/Shawnyangthesheep)
- **TON Wallet**: `UQDPYi4LKT_sqN3xJjkB4jC84ze3jzqaXtWWhHUGFvV5BfeA`

---

*This project is submitted under the TON Society Footstep program. All SQL queries are Apache 2.0 licensed.*