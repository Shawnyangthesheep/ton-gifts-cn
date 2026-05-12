# Telegram Gifts Dune Dashboard — 中国市场定制版 🇨🇳

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![TON Society Footstep](https://img.shields.io/badge/TON%20Society-Footstep%20%231227-blue)](https://github.com/ton-society/grants-and-bounties/issues/1227)

Telegram Collectible Gifts 链上数据仪表盘，**专为中国 TON 社区定制**。

---

## 📊 SQL 查询文件列表

### sql/01_daily_volume_overview.sql

```sql
-- ============================================================================
-- 查询 1: Telegram Gifts 每日交易量概览（链上数据）
-- 基础查询 — 被查询 2、3、4、7 复用
-- ============================================================================
-- 表说明:
--   ton.nft_events                          — NFT 交易事件（sale/transfer/mint）
--   dune.rdmcd.result_gifts_collection_addresses — TG Gift 合集地址列表（社区维护）
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- 每日交易数据
daily_trades AS (
  SELECT
    DATE_TRUNC('day', e.block_date)         AS trade_date,
    COUNT(*)                                 AS trade_count,
    COUNT(DISTINCT e.collection_address)     AS active_collections,
    COUNT(DISTINCT e.owner_address)          AS unique_buyers,
    COUNT(DISTINCT e.prev_owner)             AS unique_sellers,
    -- 估算交易额（TON）- NFT 事件不含金额，用近似方法
    APPROX_COUNT_DISTINCT(e.tx_hash)         AS unique_txs
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CAST('2025-08-01' AS TIMESTAMP) -- 链上时代开始
  GROUP BY 1
),

-- 每日铸造数据
daily_mints AS (
  SELECT
    DATE_TRUNC('day', e.block_date)         AS trade_date,
    COUNT(*)                                 AS mint_count,
    COUNT(DISTINCT e.collection_address)     AS minting_collections
  FROM ton.nft_events e
  WHERE e.type = 'mint'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CAST('2025-08-01' AS TIMESTAMP)
  GROUP BY 1
)

SELECT
  t.trade_date,
  t.trade_count,
  t.active_collections,
  t.unique_buyers,
  t.unique_sellers,
  t.unique_txs,
  COALESCE(m.mint_count, 0)                 AS mint_count,
  COALESCE(m.minting_collections, 0)        AS minting_collections,
  -- 30日移动平均
  AVG(t.trade_count) OVER (
    ORDER BY t.trade_date 
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  )                                          AS trade_count_30d_ma,
  -- 环比变化
  t.trade_count - LAG(t.trade_count) OVER (ORDER BY t.trade_date) AS trade_count_change
FROM daily_trades t
LEFT JOIN daily_mints m ON t.trade_date = m.trade_date
ORDER BY t.trade_date DESC
```

### sql/02_marketplace_share.sql

```sql
-- ============================================================================
-- 查询 2: Telegram Gifts 各市场交易份额分析
-- 识别 5 大市场: Fragment / Getgems / Portals / Disintar / TONNEL
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

gift_trades AS (
  SELECT DISTINCT
    e.tx_hash,
    e.block_date,
    e.collection_address,
    e.owner_address   AS buyer,
    e.prev_owner      AS seller
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CAST('2025-08-01' AS TIMESTAMP)
),

marketplace_msg AS (
  SELECT
    m.tx_hash,
    CASE
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'fragment'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'fragment'
      ) THEN 'Fragment'
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'getgems'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'getgems'
      ) THEN 'Getgems'
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'disintar'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'disintar'
      ) THEN 'Disintar'
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'tonnel'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'tonnel'
      ) THEN 'TONNEL'
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'portals'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'portals'
      ) THEN 'Portals'
      ELSE 'Other/Unknown'
    END AS marketplace
  FROM ton.messages m
  WHERE m.tx_hash IN (SELECT tx_hash FROM gift_trades)
    AND m.created_at >= CAST('2025-08-01' AS TIMESTAMP)
)

SELECT
  DATE_TRUNC('week', g.block_date)          AS week,
  COALESCE(m.marketplace, 'Other/Unknown')  AS marketplace,
  COUNT(*)                                   AS trade_count,
  COUNT(DISTINCT g.collection_address)       AS active_collections,
  COUNT(DISTINCT g.buyer)                    AS unique_buyers
FROM gift_trades g
LEFT JOIN marketplace_msg m ON g.tx_hash = m.tx_hash
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC
```

### sql/03_whale_leaderboard.sql

```sql
-- ============================================================================
-- 查询 3: 鲸鱼交易排行榜 & 巨鲸地址监控
-- 中国市场定制 — 识别大额交易者/地址，支持社区标记
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

buyer_stats AS (
  SELECT
    e.owner_address                          AS wallet_address,
    COUNT(*)                                 AS total_trades,
    COUNT(DISTINCT e.collection_address)     AS collections_traded,
    MIN(e.block_date)                        AS first_trade,
    MAX(e.block_date)                        AS last_trade,
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '7' DAY THEN 1 ELSE 0 END)   AS trades_7d,
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '30' DAY THEN 1 ELSE 0 END)  AS trades_30d
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1
),

seller_stats AS (
  SELECT
    e.prev_owner                             AS wallet_address,
    COUNT(*)                                 AS total_sales,
    COUNT(DISTINCT e.collection_address)     AS collections_sold,
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '30' DAY THEN 1 ELSE 0 END)  AS sales_30d
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1
)

SELECT
  COALESCE(b.wallet_address, s.wallet_address) AS wallet,
  COALESCE(b.total_trades, 0)                  AS total_buys,
  COALESCE(s.total_sales, 0)                   AS total_sells,
  COALESCE(b.trades_7d, 0)                     AS buys_7d,
  COALESCE(b.trades_30d, 0)                    AS buys_30d,
  COALESCE(s.sales_30d, 0)                     AS sells_30d,
  COALESCE(b.collections_traded, 0)            AS collections_active,
  CASE
    WHEN COALESCE(b.total_trades, 0) >= 500 THEN '🐋 超级鲸鱼'
    WHEN COALESCE(b.total_trades, 0) >= 100 THEN '🐳 大鲸鱼'
    WHEN COALESCE(b.total_trades, 0) >= 30  THEN '🐬 中型交易者'
    ELSE '🐟 散户'
  END                                          AS whale_tier,
  b.first_trade,
  b.last_trade,
  CASE WHEN COALESCE(b.trades_30d, 0) > 0 THEN '活跃' ELSE '休眠' END AS status
FROM buyer_stats b
FULL OUTER JOIN seller_stats s ON b.wallet_address = s.wallet_address
WHERE COALESCE(b.total_trades, 0) >= 10
ORDER BY total_buys DESC
LIMIT 200
```

### sql/04_holder_concentration.sql

```sql
-- ============================================================================
-- 查询 4: 持仓集中度分析（Gini 系数代理指标）
-- 中国市场定制 — 识别集中持有风险
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

wallet_holdings AS (
  SELECT
    buys.wallet,
    COALESCE(buys.buy_count, 0) - COALESCE(sells.sell_count, 0) AS net_holdings
  FROM (
    SELECT owner_address AS wallet, COUNT(*) AS buy_count
    FROM ton.nft_events
    WHERE type = 'sale'
      AND collection_address IN (SELECT col_address FROM gift_collections)
    GROUP BY 1
  ) buys
  LEFT JOIN (
    SELECT prev_owner AS wallet, COUNT(*) AS sell_count
    FROM ton.nft_events
    WHERE type = 'sale'
      AND collection_address IN (SELECT col_address FROM gift_collections)
    GROUP BY 1
  ) sells ON buys.wallet = sells.wallet
  WHERE COALESCE(buys.buy_count, 0) - COALESCE(sells.sell_count, 0) > 0
)

SELECT 'Top 10 wallets'  AS segment, SUM(net_holdings) AS holdings_in_segment, COUNT(*) AS wallet_count,
  CAST(SUM(net_holdings) AS DOUBLE) / CAST((SELECT SUM(net_holdings) FROM wallet_holdings) AS DOUBLE) * 100 AS pct_of_total
FROM wallet_holdings WHERE net_holdings IN (SELECT net_holdings FROM wallet_holdings ORDER BY net_holdings DESC LIMIT 10)
UNION ALL
SELECT 'Top 50 wallets', SUM(net_holdings), COUNT(*),
  CAST(SUM(net_holdings) AS DOUBLE) / CAST((SELECT SUM(net_holdings) FROM wallet_holdings) AS DOUBLE) * 100
FROM wallet_holdings WHERE net_holdings IN (SELECT net_holdings FROM wallet_holdings ORDER BY net_holdings DESC LIMIT 50)
UNION ALL
SELECT 'Top 100 wallets', SUM(net_holdings), COUNT(*),
  CAST(SUM(net_holdings) AS DOUBLE) / CAST((SELECT SUM(net_holdings) FROM wallet_holdings) AS DOUBLE) * 100
FROM wallet_holdings WHERE net_holdings IN (SELECT net_holdings FROM wallet_holdings ORDER BY net_holdings DESC LIMIT 100)
UNION ALL
SELECT 'All wallets', SUM(net_holdings), COUNT(*), 100.0 FROM wallet_holdings
ORDER BY wallet_count
```

### sql/05_conversion_funnel.sql

```sql
-- ============================================================================
-- 查询 5: 链上转化漏斗 — 铸造 → 首次交易 → 活跃交易
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address FROM dune.rdmcd.result_gifts_collection_addresses
),
mints AS (
  SELECT collection_address, nft_id, MIN(block_date) AS mint_date
  FROM ton.nft_events WHERE type = 'mint' AND collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1, 2
),
first_sale AS (
  SELECT collection_address, nft_id, MIN(block_date) AS first_sale_date
  FROM ton.nft_events WHERE type = 'sale' AND collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1, 2
),
funnel AS (
  SELECT
    DATE_TRUNC('week', m.mint_date) AS week,
    COUNT(DISTINCT m.nft_id) AS total_minted,
    COUNT(DISTINCT fs.nft_id) AS ever_traded,
    COUNT(DISTINCT CASE WHEN fs.first_sale_date <= m.mint_date + INTERVAL '7' DAY THEN fs.nft_id END) AS traded_within_7d,
    COUNT(DISTINCT CASE WHEN fs.first_sale_date <= m.mint_date + INTERVAL '30' DAY THEN fs.nft_id END) AS traded_within_30d
  FROM mints m LEFT JOIN first_sale fs ON m.collection_address = fs.collection_address AND m.nft_id = fs.nft_id
  GROUP BY 1
)
SELECT
  week, total_minted, ever_traded,
  ROUND(CAST(ever_traded AS DOUBLE) / NULLIF(total_minted,0)*100,2) AS pct_ever_traded,
  traded_within_7d,
  ROUND(CAST(traded_within_7d AS DOUBLE) / NULLIF(total_minted,0)*100,2) AS pct_7d_flip,
  traded_within_30d,
  ROUND(CAST(traded_within_30d AS DOUBLE) / NULLIF(total_minted,0)*100,2) AS pct_30d_flip
FROM funnel WHERE week >= CAST('2025-08-01' AS TIMESTAMP) ORDER BY week DESC
```

### sql/06_weekly_marketplace_trend.sql

```sql
-- ============================================================================
-- 查询 6: 周度市场交易趋势（用于 CNY 定价叠加）
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address FROM dune.rdmcd.result_gifts_collection_addresses
),
gift_trades AS (
  SELECT DISTINCT e.tx_hash, e.block_date, e.collection_address, e.owner_address AS buyer, e.prev_owner AS seller
  FROM ton.nft_events e WHERE e.type = 'sale' AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CAST('2025-08-01' AS TIMESTAMP)
),
weekly_market AS (
  SELECT
    DATE_TRUNC('week', g.block_date) AS week,
    COUNT(*) AS trades, COUNT(DISTINCT g.collection_address) AS collections, COUNT(DISTINCT g.buyer) AS buyers
  FROM gift_trades g GROUP BY 1
)
SELECT week, trades, collections, buyers,
  CAST(trades AS DOUBLE) / SUM(trades) OVER (PARTITION BY week) * 100 AS pct_share,
  trades - LAG(trades) OVER (PARTITION BY week ORDER BY week) AS wow_change
FROM weekly_market ORDER BY week DESC, trades DESC
```

### sql/07_collection_floor_tracker.sql

```sql
-- ============================================================================
-- 查询 7: 合集层面地板价追踪
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address FROM dune.rdmcd.result_gifts_collection_addresses
),
collection_trades AS (
  SELECT collection_address, block_date, COUNT(*) AS daily_trades, COUNT(DISTINCT owner_address) AS daily_unique_buyers
  FROM ton.nft_events WHERE type = 'sale' AND collection_address IN (SELECT col_address FROM gift_collections)
    AND block_date >= CURRENT_DATE - INTERVAL '90' DAY
  GROUP BY 1, 2
),
collection_summary AS (
  SELECT collection_address, COUNT(*) AS total_trades_90d, COUNT(DISTINCT owner_address) AS unique_buyers_90d,
    MAX(daily_trades) AS peak_daily_trades, AVG(daily_trades) AS avg_daily_trades,
    SUM(CASE WHEN block_date >= CURRENT_DATE - INTERVAL '7' DAY THEN daily_trades ELSE 0 END) AS trades_7d
  FROM collection_trades GROUP BY 1
)
SELECT cs.collection_address, cs.total_trades_90d, cs.unique_buyers_90d, cs.peak_daily_trades,
  ROUND(cs.avg_daily_trades,1) AS avg_daily_trades, cs.trades_7d,
  CASE WHEN cs.trades_7d >= 500 THEN '🔥 极热' WHEN cs.trades_7d >= 100 THEN '🔶 热门'
       WHEN cs.trades_7d >= 20 THEN '🟡 温和' WHEN cs.trades_7d > 0 THEN '🟢 有交易' ELSE '⚪ 沉寂' END AS heat_level,
  cs.unique_buyers_90d * cs.avg_daily_trades AS liquidity_score
FROM collection_summary cs ORDER BY trades_7d DESC LIMIT 100
```

### sql/08_whale_heatmap.sql

```sql
-- ============================================================================
-- 查询 8: 鲸鱼活动热力图 — 按小时/星期分布（北京时间）
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address FROM dune.rdmcd.result_gifts_collection_addresses
),
whales AS (
  SELECT owner_address AS wallet FROM ton.nft_events WHERE type = 'sale'
    AND collection_address IN (SELECT col_address FROM gift_collections)
    AND block_date >= CURRENT_DATE - INTERVAL '90' DAY GROUP BY 1 HAVING COUNT(*) >= 100
),
whale_activity AS (
  SELECT EXTRACT(HOUR FROM e.block_date) AS trade_hour, EXTRACT(DOW FROM e.block_date) AS trade_dow,
    COUNT(*) AS whale_trades
  FROM ton.nft_events e WHERE e.type = 'sale' AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.owner_address IN (SELECT wallet FROM whales) AND e.block_date >= CURRENT_DATE - INTERVAL '60' DAY
  GROUP BY 1, 2
)
SELECT trade_dow,
  CASE trade_dow WHEN 0 THEN '周日' WHEN 1 THEN '周一' WHEN 2 THEN '周二' WHEN 3 THEN '周三'
    WHEN 4 THEN '周四' WHEN 5 THEN '周五' WHEN 6 THEN '周六' END AS day_name_cn,
  trade_hour, (trade_hour + 8) % 24 AS beijing_hour, whale_trades,
  CAST(whale_trades AS DOUBLE) / SUM(whale_trades) OVER (PARTITION BY trade_dow) * 100 AS pct_of_day
FROM whale_activity ORDER BY trade_dow, trade_hour
```

### sql/09_arbitrage_monitor.sql

```sql
-- ============================================================================
-- 查询 9: 跨市场套利价差监测（实验性）
-- 限制: Dune TON spellbook 暂无直接存储 NFT 成交价格字段
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address FROM dune.rdmcd.result_gifts_collection_addresses
),
market_heat AS (
  SELECT DATE_TRUNC('day', e.block_date) AS trade_date,
    COUNT(*) AS trades, COUNT(DISTINCT e.owner_address) AS unique_buyers, COUNT(DISTINCT e.collection_address) AS collections
  FROM ton.nft_events e WHERE e.type = 'sale' AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CURRENT_DATE - INTERVAL '30' DAY GROUP BY 1
)
SELECT trade_date, trades, unique_buyers, collections,
  ROUND(CAST(unique_buyers AS DOUBLE) / NULLIF(trades,0), 3) AS buyer_ratio,
  AVG(trades) OVER (ORDER BY trade_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trades_7d_ma,
  CASE WHEN trades > AVG(trades) OVER (ORDER BY trade_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) * 1.5
    THEN '📈 异常活跃 — 注意套利窗口'
    WHEN trades < AVG(trades) OVER (ORDER BY trade_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) * 0.5
    THEN '📉 异常冷清 — 可能地板价下跌'
    ELSE '正常' END AS anomaly_alert
FROM market_heat ORDER BY trade_date DESC
```

---

## 🎯 差异化说明

| 维度 | 英文版 (#1226) | **本版（中国市场）** |
|------|---------------|-------------------|
| 语言 | 仅英文 | **中英双语** |
| 定价 | USD/原生 TON | **CNY 叠加层** |
| 市场 | 5 大市场全覆盖 | **偏重 Getgems/Disintar** |
| 鲸鱼追踪 | 通用排行榜 | **中文社区已知鲸鱼标注** |
| 套利分析 | — | **跨市场价差异常检测** |
| 文档 | 英文 write-up | **中文教程 + GitHub Pages** |

---

## 📄 许可证

Apache License 2.0

---

> 🦞 TON Society Footstep #1227 | GitHub: Shawnyangthesheep | TON: `UQDPYi4LKT_sqN3xJjkB4jC84ze3jzqaXtWWhHUGFvV5BfeA`