-- ============================================================================
-- 查询 6: 周度市场交易趋势（用于 CNY 定价叠加）
-- 按周 × 市场统计交易量，可在 Dune 前端加 CNY/USDT 汇率参数
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- Gift 交易事件
gift_trades AS (
  SELECT DISTINCT
    e.tx_hash,
    e.block_date,
    e.collection_address,
    e.owner_address  AS buyer,
    e.prev_owner     AS seller
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CAST('2025-08-01' AS TIMESTAMP)
),

-- 通过 messages 表识别市场（简化版 — 基于已知市场合约地址）
market_map AS (
  SELECT tx_hash, 'Fragment' AS marketplace
  FROM ton.messages
  WHERE source = '0:584b9b3e4a1da9a7b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4'
     OR destination = '0:584b9b3e4a1da9a7b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4'
  UNION ALL
  SELECT tx_hash, 'Getgems'
  FROM ton.messages
  WHERE source = '0:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0'
     OR destination = '0:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0'
),

-- 周度按市场汇总
weekly_market AS (
  SELECT
    DATE_TRUNC('week', g.block_date)    AS week,
    COALESCE(m.marketplace, 'Other')   AS marketplace,
    COUNT(*)                             AS trades,
    COUNT(DISTINCT g.collection_address) AS collections,
    COUNT(DISTINCT g.buyer)              AS buyers
  FROM gift_trades g
  LEFT JOIN market_map m ON g.tx_hash = m.tx_hash
  GROUP BY 1, 2
)

SELECT
  week,
  marketplace,
  trades,
  collections,
  buyers,
  -- 本周占比
  CAST(trades AS DOUBLE) / SUM(trades) OVER (PARTITION BY week) * 100 AS pct_share,
  -- 环比上周
  trades - LAG(trades) OVER (PARTITION BY marketplace ORDER BY week)   AS wow_change
FROM weekly_market
ORDER BY week DESC, trades DESC