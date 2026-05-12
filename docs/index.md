# Telegram Gifts Dune 看板 — 中国市场定制版 🇨🇳

专为中国 TON 玩家打造的 Telegram Collectible Gifts 链上数据分析仪表盘。

---

## 🎯 9 张图，看透 Gifts 市场

| # | 图表 | 有什么用 |
|---|------|---------|
| 1 | [每日交易量概览](sql/01_daily_volume_overview.sql) | 今天市场热不热？ |
| 2 | [市场份额对比](sql/02_marketplace_share.sql) | Getgems/Disintar 谁更强？ |
| 3 | [🐋 鲸鱼排行榜](sql/03_whale_leaderboard.sql) | 大佬在买什么？ |
| 4 | [持仓集中度](sql/04_holder_concentration.sql) | 市场被少数人控制了吗？ |
| 5 | [转化漏斗](sql/05_conversion_funnel.sql) | 铸造后几人真卖过？ |
| 6 | [周度市场趋势](sql/06_weekly_marketplace_trend.sql) | 本周比上周热还是冷？ |
| 7 | [合集地板价追踪](sql/07_collection_floor_tracker.sql) | 哪个系列正在起飞？ |
| 8 | [鲸鱼热力图](sql/08_whale_heatmap.sql) | 大佬几点出来扫货？ |
| 9 | [套利监测](sql/09_arbitrage_monitor.sql) | 有跨市场价差吗？ |

---

## 🚀 快速上手

### 1. 去 Dune 注册账号（2 分钟）

👉 [dune.com](https://dune.com) → Sign Up → GitHub 登录

### 2. 复制 SQL 跑一下

👉 [GitHub 仓库](https://github.com/Shawnyangthesheep/ton-gifts-cn) → `sql/` 目录 → 复制粘贴到 Dune Query → Run

### 3. 组装 Dashboard（5 分钟）

9 张图全部保存后 → Create Dashboard → 全部拖进去

---

## 📖 文档

- **[中文教程](zh-CN/README.md)** — TON Gifts 入门 + 看板使用指南
- **[English Write-up](en/README.md)** — For TON Society submission

---

## ⚠️ 须知

- 数据有 1-24 小时延迟，不是实时的
- 当前 Dune spellbook 未直接暴露成交价格，使用交易频率做替代指标
- 部分交易可能因市场标签不完整识别为 "Other"

---

> 🦞 TON Society Footstep #1227 | [GitHub](https://github.com/Shawnyangthesheep/ton-gifts-cn)
> TON 钱包：`UQDPYi4LKT_sqN3xJjkB4jC84ze3jzqaXtWWhHUGFvV5BfeA`