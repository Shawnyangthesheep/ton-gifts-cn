-- ============================================================================
-- Query 9: Trading Volume Anomaly Monitor (Arbitrage Window Proxy)
-- Detects volume spikes/dips as potential arbitrage signal triggers
-- ============================================================================
--
-- LIMITATION NOTE:
--   Dune's TON spellbook does NOT currently expose NFT sale prices.
--   This query uses trade VOLUME as the only available signal.
--   Once ton.nft_trades.price_ton is available, replace the anomaly logic
--   with actual price-gap detection across marketplaces.
--
--   The "arbitrage window" here is defined as volume anomaly, not price gap.
--   This is still useful: volume spikes often precede price movements.
--
-- Future upgrade (when price data exists):
--   - JOIN trade data with marketplace_map (from Query 2)
--   - Calculate: price_per_nft (if available), group by collection + marketplace
--   - Flag: ABS(price_A - price_B) / MIN(price_A, price_B) > threshold
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- Daily summary metrics
daily_stats AS (
  SELECT
    DATE_TRUNC('day', e.block_date)            AS trade_date,
    COUNT(*)                                    AS trades,
    COUNT(DISTINCT e.owner_address)             AS unique_buyers,
    COUNT(DISTINCT e.collection_address)        AS collections
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CURRENT_DATE - INTERVAL '60' DAY
  GROUP BY 1
),

with_ma AS (
  SELECT
    trade_date,
    trades,
    unique_buyers,
    collections,
    ROUND(
      CAST(unique_buyers AS DOUBLE) / NULLIF(trades, 0), 3
    ) AS buyer_ratio,                            -- high = retail, low = whale-dominated
    
    AVG(trades) OVER (
      ORDER BY trade_date
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS ma_7d,                                  -- 7-day moving average
    
    STDDEV(trades) OVER (
      ORDER BY trade_date
      ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
    ) AS stddev_14d                              -- 14-day rolling stddev
  FROM daily_stats
)

SELECT
  trade_date,
  trades,
  unique_buyers,
  collections,
  buyer_ratio,
  ROUND(ma_7d, 1) AS ma_7d,
  ROUND(stddev_14d, 1) AS volatility_14d,
  
  -- Volume anomaly: Z-score using rolling mean and stddev
  CASE 
    WHEN stddev_14d > 0 THEN
      ROUND((CAST(trades AS DOUBLE) - ma_7d) / stddev_14d, 2)
    ELSE 0
  END AS volume_z_score,
  
  -- Signal labels (Chinese)
  CASE 
    WHEN stddev_14d > 0 
      AND (CAST(trades AS DOUBLE) - ma_7d) / stddev_14d > 2.0
    THEN '📈 高活跃 — 关注跨市场机会'
    WHEN stddev_14d > 0 
      AND (CAST(trades AS DOUBLE) - ma_7d) / stddev_14d < -2.0
    THEN '📉 低活跃 — 可能地板价下跌'
    WHEN buyer_ratio > 0.85
    THEN '👥 散户主导 — 无明显庄家痕迹'
    WHEN buyer_ratio < 0.40
    THEN '🐋 鲸鱼主导 — 大户可能在出货'
    ELSE '➡️ 正常'
  END AS signal_type,
  
  ROUND(ma_7d, 1) AS baseline_trades,
  ROUND(
    (CAST(trades AS DOUBLE) - ma_7d) / NULLIF(ma_7d, 0) * 100, 1
  ) AS pct_vs_baseline                           -- % above/below 7d average

FROM with_ma
ORDER BY trade_date DESC

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type : Combo (area chart + scatter + horizontal reference line)
--   X-axis     : trade_date
--   Y-axis     : trades (area) + volume_z_score (reference line)
--   Markers    : flag dots on z_score > 2 or < -2 (anomaly points)
--   Reference  : horizontal line at z=0 (baseline)
--
-- Story this tells:
--   - Volume spike = 资金涌入, could be 跨市场套利 opportunity
--   - Volume drop = market cooling, potential price softening
--   - buyer_ratio < 0.4 = whales are selling (大户可能在出货!)
-- For Chinese traders: When signal = 🐋, consider reducing exposure
-- ============================================================================