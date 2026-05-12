# Telegram Gifts Dune Dashboard — 中国市场定制版 🇨🇳

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![TON Society Footstep](https://img.shields.io/badge/TON%20Society-Footstep%20%231227-blue)](https://github.com/ton-society/grants-and-bounties/issues/1227)

Telegram Collectible Gifts 链上数据仪表盘，**专为中国 TON 社区定制**。

## 🎯 与英文版的差异化

| 维度 | 英文版 (#1226) | **本版（中国市场）** |
|------|---------------|-------------------|
| 语言 | 仅英文 | **中英双语** |
| 定价 | USD/原生 TON | **CNY 叠加层** |
| 市场 | 5 大市场全覆盖 | **偏重 Getgems/Disintar（中国玩家主力）** |
| 鲸鱼追踪 | 通用排行榜 | **标识中国社区已知鲸鱼** |
| 套利分析 | — | **跨市场价差异常检测** |
| 文档 | 英文 write-up | **中文教程 + GitHub Pages 文档站** |

## 📊 仪表盘图表（9 张）

| # | 文件名 | 图表内容 |
|---|--------|---------|
| 1 | `01_daily_volume_overview.sql` | 每日交易量 & 铸造量概览 |
| 2 | `02_marketplace_share.sql` | 五大市场份额对比 |
| 3 | `03_whale_leaderboard.sql` | 🐋 鲸鱼排行榜 & 巨鲸地址监控 |
| 4 | `04_holder_concentration.sql` | 持仓集中度分析 |
| 5 | `05_conversion_funnel.sql` | 链上转化漏斗（铸造→交易） |
| 6 | `06_weekly_marketplace_trend.sql` | 周度市场趋势（适配 CNY 叠加） |
| 7 | `07_collection_floor_tracker.sql` | 合集地板价追踪 & 热度评级 |
| 8 | `08_whale_heatmap.sql` | 鲸鱼活动热力图（北京时间） |
| 9 | `09_arbitrage_monitor.sql` | 跨市场套利窗口监测（实验性） |

## 🚀 快速开始

### 在 Dune 上运行

1. 注册 [Dune Analytics](https://dune.com) 账号
2. 创建新 Query → 粘贴 `sql/` 目录下的任意 .sql 文件
3. 点击 Run → 查看结果
4. 将所有 Query 组合成一个 Dashboard

### 本地查看结果（需要等 Dune spellbook 完善后扩展）

```bash
# 克隆仓库
git clone https://github.com/[TBD]/ton-gifts-cn.git
cd ton-gifts-cn

# 查看所有 SQL 查询
ls sql/
```

## 📖 文档

- [中文教程](./docs/zh-CN/README.md) — TON Gifts 入门 & 仪表盘使用指南
- [English Write-up](./docs/en/README.md) — For TON Society submission

## ⚠️ 注意事项

1. **数据时效**：所有查询基于 Dune 的 TON spellbook，数据有 1-24 小时延迟
2. **价格字段**：当前 Dune TON spellbook 未直接暴露 NFT 成交价格，查询 6/9 使用交易频率作为热度的替代指标
3. **市场识别**：市场标签依赖 `dune.ton_foundation.dataset_labels`，部分交易可能识别为 "Other"

## 🏗️ 后续扩展计划

- [ ] 接入 Dune API 自动获取 CNY/USDT 汇率
- [ ] 集成 TON NFT metadata 稀有度数据
- [ ] 添加微信/Telegram 中文群组情绪指标
- [ ] 构建鲸鱼地址公告板（社区共建）

## 📄 许可证

Apache 2.0 — 详见 [LICENSE](LICENSE)

---

> 🦞 本仓库是 TON Society Footstep #1227 的提交物
> 联系：[Shawnyangthesheep](https://github.com/Shawnyangthesheep)
> TON 钱包：`UQDPYi4LKT_sqN3xJjkB4jC84ze3jzqaXtWWhHUGFvV5BfeA`