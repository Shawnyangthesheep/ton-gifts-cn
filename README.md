# Telegram Gifts Dune Dashboard — 中国市场定制版 🇨🇳

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![TON Society Footstep](https://img.shields.io/badge/TON%20Society-Footstep%20%231227-blue)](https://github.com/ton-society/grants-and-bounties/issues/1227)
[![Build Status](https://img.shields.io/badge/version-v1.1-blue.svg)]()

Telegram Collectible Gifts 链上数据仪表盘，**专为中国 TON 社区定制**。

## 🎯 与英文版（#1226）的差异化

| 维度 | 英文版 | **本版（中国市场）** |
|------|--------|-------------------|
| 语言 | 仅英文 | **中英双语** |
| 定价 | USD / 原生 TON | **CNY 叠加层（预留字段）** |
| 市场 | 5 大市场均衡展示 | **Getgems / Disintar（中国玩家主力）优先** |
| 鲸鱼追踪 | 通用排行榜 | **中文标注 + 社区鲸鱼可标注** |
| 套利分析 | — | **交易量异常 Z-score 检测** |
| 文档 | 英文 write-up | **中文教程 + GitHub Pages 文档站** |

## 📊 9 张图表

| # | 文件名 | 内容 | 可视化建议 |
|---|--------|------|-----------|
| 1 | `01_daily_volume_overview.sql` | 每日交易量 & 铸造量概览 | 柱状+折线组合图 |
| 2 | `02_marketplace_share.sql` | 五大市场份额对比 | 堆叠面积图 |
| 3 | `03_whale_leaderboard.sql` | 🐋 鲸鱼排行榜 & 状态监控 | 排行榜表格 |
| 4 | `04_holder_concentration.sql` | 持仓集中度分析（Gini 代理） | 水平条形图 |
| 5 | `05_conversion_funnel.sql` | 链上转化漏斗（铸造→交易） | 漏斗/双轴折线图 |
| 6 | `06_weekly_marketplace_trend.sql` | 周度市场趋势（CNY 叠加预留） | 堆叠柱状图 |
| 7 | `07_collection_floor_tracker.sql` | 合集热度追踪 & 流动性评分 | 颜色标注表格 |
| 8 | `08_whale_heatmap.sql` | 鲸鱼活动热力图（北京时间 UTC+8） | 热力图 |
| 9 | `09_arbitrage_monitor.sql` | 交易量异常检测（Z-score） | 面积+散点图 |

## 🚀 快速开始

### 在 Dune 上运行

1. 注册 [Dune Analytics](https://dune.com)（推荐 GitHub 登录）
2. 点击 **Create → Query**
3. 复制 `sql/` 目录下任意一个 `.sql` 文件，粘贴到编辑器
4. 点击 **Run** → 查看结果
5. 9 个查询全部运行后 → **Create Dashboard** → 拖入所有图表

### 参数说明

Dune 查询参数（可直接修改 WHERE 子句中的默认值）：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `{{start_date}}` | `2025-08-01` | 数据起始日期 |

> **提示**：每个 SQL 文件底部有 Dune 可视化配置建议（Chart Type、坐标轴设置等）

## 📖 文档

- 🇨🇳 [中文教程](docs/zh-CN/README.md) — TON Gifts 入门 & 仪表盘使用指南
- 🇬🇧 [English Write-up](docs/en/README.md) — TON Society 提案详情
- 🌐 [GitHub Pages 文档站](https://shawnyangthesheep.github.io/ton-gifts-cn/)

## ⚠️ 重要说明

1. **数据延迟**：Dune 数据有 1–24 小时延迟，非实时
2. **价格字段**：Dune TON spellbook 当前未暴露 NFT 成交价格，查询使用交易频率作为替代指标
3. **市场识别**：需配置各市场合约地址（CTE 中有说明占位符），配置后即可识别来源市场

## 🛠️ 市场合约地址配置

Query 2 / Query 6 中的 `marketplace_addresses` CTE 需要填入真实地址后使用：

| 市场 | 合约地址格式 | 备注 |
|------|------------|------|
| Fragment | `EQ...` | Telegram 官方市场 |
| Getgems | `EQ...` | TON 最大 NFT 市场 |
| Disintar | `EQ...` | 中国用户常用 |
| TONNEL | `EQ...` | — |
| Portals | `EQ...` | — |

> 如何查找：在 Dune 已有 TON NFT 看板中搜索，或查看各市场官网 About 页面。

## 🗺️ 后续扩展计划

- [ ] 接入 Dune API 自动获取 CNY/USD 实时汇率
- [ ] 解析 Telegram Gift NFT metadata 获取稀有度数据
- [ ] 构建社区共建鲸鱼地址标注板
- [ ] 添加 Telegram Bot 实时推送鲸鱼活动提醒

## 📄 许可证

Apache 2.0 — 详见 [LICENSE](LICENSE)

---

> 🦞 TON Society Footstep #1227
> 仓库：[github.com/Shawnyangthesheep/ton-gifts-cn](https://github.com/Shawnyangthesheep/ton-gifts-cn)
> 提案：[ton-society/grants-and-bounties#1227](https://github.com/ton-society/grants-and-bounties/issues/1227)
> TON 钱包：`UQDPYi4LKT_sqN3xJjkB4jC84ze3jzqaXtWWhHUGFvV5BfeA`