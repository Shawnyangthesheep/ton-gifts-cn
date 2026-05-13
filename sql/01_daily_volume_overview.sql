-- ============================================================================
-- Query 1: Daily Volume Overview — Telegram Gifts
-- Tracks daily trade count, minting activity, unique buyers/sellers, and MAs
-- ============================================================================
-- 
-- This is the entry-point query for the dashboard, used as the "At a Glance" view.
-- It's also referenced by queries 3, 4, and 7 as the base CTE.
--
-- Parameters:
--   {{start_date}} - Filter from this date (default: 2025-08-01)
--
-- Visualization: Dual-axis line + bar chart recommended
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- Daily trade events (sale only)
daily_trades AS (
  SELECT
    DATE_TRUNC('day', e.block_date)              AS trade_date,
    COUNT(*)                                  AS trade_count,
    COUNT(DISTINCT e.collection_address)      AS active_collections,
    COUNT(DISTINCT e.owner_address)         AS unique_buyers,
    COUNT(DISTINCT e.prev_owner)            AS unique_sellers,
    APPROX_COUNT_DISTINCT(e.tx_hash)          AS unique_txs
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CAST('{{start_date}}' AS TIMESTAMP)
  GROUP BY 1
),

-- Daily mint events
daily_mints AS (
  SELECT
    DATE_TRUNC('day', e.block_date)              AS trade_date,
    COUNT(*)                                  AS mint_count,
    COUNT(DISTINCT e.collection_address)      AS minting_collections
  FROM ton.nft_events e
  WHERE e.type = 'mint'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CAST('{{start_date}}' AS TIMESTAMP)
  GROUP BY 1
)

SELECT
  t.trade_date,
  t.trade_count,
  t.active_collections,
  t.unique_buyers,
  t.unique_sellers,
  t.unique_txs,
  COALESCE(m.mint_count, 0)                  AS mint_count,
  COALESCE(m.minting_collections, 0)         AS minting_collections,
  
  -- 7-day moving average (smooths daily noise)
  ROUND(AVG(t.trade_count) OVER (
    ORDER BY t.trade_date 
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ), 1)                                      AS trade_count_7d_ma,
  
  -- 30-day moving average (long-term trend)
  ROUND(AVG(t.trade_count) OVER (
    ORDER BY t.trade_date 
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ), 1)                                      AS trade_count_30d_ma,
  
  -- Week-over-week change
  t.trade_count - LAG(t.trade_count, 7) OVER (
    ORDER BY t.trade_date
  )                                          AS trade_count_wow_change,
  
  -- Buyer/seller ratio (market sentiment: >1 = buying pressure, <1 = selling)
  ROUND(CAST(t.unique_buyers AS DOUBLE) / NULLIF(t.unique_sellers, 0), 2) AS buyer_seller_ratio
  
FROM daily_trades t
LEFT JOIN daily_mints m ON t.trade_date = m.trade_date
ORDER BY t.trade_date DESC

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type   : Combo (bar + line)
--   X-axis      : trade_date
--   Y-axis L   : trade_count (bar)
--   Y-axis R   : trade_count_30d_ma (line, smooth trend)
--   Parameters: {{start_date}} = '2025-08-01' (onset of chain era)
--
-- Story this tells:
--   - Are trades increasing or decreasing? (30d MA line)
--   - Is today busier than last week? (WoW change)
--   - Is there buying or selling pressure? (buyer/seller ratio)
-- ============================================================================