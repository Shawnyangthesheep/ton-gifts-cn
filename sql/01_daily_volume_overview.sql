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