-- ============================================================================
-- Query 7: Collection-Level Floor Tracker & Heat Rating
-- Ranks Telegram Gift collections by trading activity and liquidity
-- ============================================================================
-- Note: Dune TON spellbook currently lacks a direct floor-price field.
-- This query uses trade frequency as a heat proxy.
-- When price data becomes available, add: MIN(price_ton) AS floor_ton
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

collection_daily AS (
  SELECT
    e.collection_address,
    e.block_date,
    COUNT(*)                            AS daily_trades,
    COUNT(DISTINCT e.owner_address)     AS daily_buyers
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CURRENT_DATE - INTERVAL '90' DAY
  GROUP BY 1, 2
),

collection_summary AS (
  SELECT
    collection_address,
    COUNT(*)                                              AS total_trades_90d,
    COUNT(DISTINCT daily_buyers)                          AS unique_buyers_90d,
    MAX(daily_trades)                                     AS peak_daily_trades,
    ROUND(AVG(daily_trades), 1)                           AS avg_daily_trades,
    SUM(CASE WHEN block_date >= CURRENT_DATE - INTERVAL '7' DAY THEN daily_trades ELSE 0 END) AS trades_7d,
    SUM(CASE WHEN block_date >= CURRENT_DATE - INTERVAL '30' DAY THEN daily_trades ELSE 0 END) AS trades_30d
  FROM collection_daily
  GROUP BY 1
)

SELECT
  collection_address,
  total_trades_90d,
  unique_buyers_90d,
  peak_daily_trades,
  avg_daily_trades,
  trades_7d,
  trades_30d,
  
  -- Heat level (Chinese labels for CN community)
  CASE
    WHEN trades_7d >= 500    THEN '🔥 极热'
    WHEN trades_7d >= 100    THEN '🔶 热门'
    WHEN trades_7d >= 20     THEN '🟡 温和'
    WHEN trades_7d > 0       THEN '🟢 有交易'
    ELSE '⚪ 沉寂'
  END                                                  AS heat_level,
  
  -- Liquidity score (higher = easier to trade in/out)
  ROUND(unique_buyers_90d * avg_daily_trades / 100, 1) AS liquidity_score,
  
  -- Trend: 7d vs 30d comparison
  CASE
    WHEN trades_30d > 0 AND (CAST(trades_7d AS DOUBLE) * 4.3) > trades_30d 
    THEN '📈 加速中'
    WHEN trades_30d > 0 AND (CAST(trades_7d AS DOUBLE) * 4.3) < trades_30d * 0.5 
    THEN '📉 降温中'
    WHEN trades_7d > 0 
    THEN '➡️ 稳定'
    ELSE '—'
  END                                                  AS trend

FROM collection_summary
ORDER BY trades_7d DESC
LIMIT 100

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type : Table with color-coded heat_level column
--   Columns    : collection_address, heat_level, trades_7d, liquidity_score, trend
--   Sort       : trades_7d DESC
--   Color      : heat_level (极热=red, 热门=orange, 温和=yellow, etc.)
--
-- Story this tells:
--   - Which collections are trending NOW? (trades_7d + heat_level)
--   - Which have good liquidity for large trades? (liquidity_score)
--   - Are new buyers entering? (unique_buyers_90d)
-- For Chinese traders: 极热 can mean FOMO, 温和/有交易 may have 捡漏 opportunities
-- ============================================================================