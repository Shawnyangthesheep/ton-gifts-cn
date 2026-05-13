-- ============================================================================
-- Query 8: Whale Activity Heatmap — By Hour × Day of Week
-- Helps Chinese traders identify the best/worst trading windows
-- ============================================================================
-- Key feature: Converts UTC to Beijing time (UTC+8) for Chinese users
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- Define whales: 100+ trades in last 90 days
whales AS (
  SELECT owner_address AS wallet
  FROM ton.nft_events
  WHERE type = 'sale'
    AND collection_address IN (SELECT col_address FROM gift_collections)
    AND block_date >= CURRENT_DATE - INTERVAL '90' DAY
  GROUP BY 1
  HAVING COUNT(*) >= 100
),

-- Hourly × daily distribution of whale trades
whale_activity AS (
  SELECT
    EXTRACT(HOUR FROM e.block_date)     AS utc_hour,
    EXTRACT(DOW FROM e.block_date)      AS dow,  -- 0=Sun, 6=Sat
    COUNT(*)                             AS whale_trades
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.owner_address IN (SELECT wallet FROM whales)
    AND e.block_date >= CURRENT_DATE - INTERVAL '60' DAY
  GROUP BY 1, 2
)

SELECT
  dow                                          AS day_of_week_num,
  CASE dow
    WHEN 0 THEN '周日' WHEN 1 THEN '周一' WHEN 2 THEN '周二'
    WHEN 3 THEN '周三' WHEN 4 THEN '周四' WHEN 5 THEN '周五'
    WHEN 6 THEN '周六'
  END                                          AS day_name_cn,
  (utc_hour + 8) % 24                          AS beijing_hour,
  whale_trades,
  ROUND(
    CAST(whale_trades AS DOUBLE) / 
    SUM(whale_trades) OVER (PARTITION BY dow) * 100, 2
  )                                            AS pct_of_day,

  -- Peak/valley indicator
  CASE
    WHEN CAST(whale_trades AS DOUBLE) >= 
      AVG(whale_trades) OVER (PARTITION BY dow) * 1.5
    THEN '🔴 鲸鱼高峰'
    WHEN CAST(whale_trades AS DOUBLE) <= 
      AVG(whale_trades) OVER (PARTITION BY dow) * 0.5
    THEN '🟢 低流动性窗口'
    ELSE '🟡 正常'
  END                                          AS activity_level

FROM whale_activity
ORDER BY dow, beijing_hour

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type : Heatmap (pivot table → color by whale_trades)
--   X-axis     : beijing_hour (0–23)
--   Y-axis     : day_name_cn (周一–周日)
--   Color      : whale_trades (darker = more whale activity)
--
-- Story this tells:
--   - When do Chinese whales trade? (heatmap peaks in Beijing time)
--   - When is liquidity low? (useful for small traders to avoid slippage)
--   - Weekend vs weekday patterns? (dow dimension)
-- For Chinese traders: 避开鲸鱼高峰 = 减少滑点; 低流动性窗口 = 大单可能剧烈波动
-- ============================================================================