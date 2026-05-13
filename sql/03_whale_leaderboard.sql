-- ============================================================================
-- Query 3: Whale Leaderboard — Telegram Gifts
-- Tracks the most active traders (buyers + sellers) with tiered classification
-- ============================================================================
-- China-specific: Whale tiers labeled in Chinese for community readability.
-- Addresses can be annotated with known Chinese community whale tags.
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

buyer_stats AS (
  SELECT
    e.owner_address                       AS wallet_address,
    COUNT(*)                              AS total_buys,
    COUNT(DISTINCT e.collection_address)  AS collections_traded,
    MIN(e.block_date)                     AS first_trade,
    MAX(e.block_date)                     AS last_trade,
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '7'  DAY THEN 1 ELSE 0 END) AS buys_7d,
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '30' DAY THEN 1 ELSE 0 END) AS buys_30d
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1
),

seller_stats AS (
  SELECT
    e.prev_owner                          AS wallet_address,
    COUNT(*)                              AS total_sells,
    COUNT(DISTINCT e.collection_address)  AS collections_sold,
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '30' DAY THEN 1 ELSE 0 END) AS sells_30d
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1
)

SELECT
  COALESCE(b.wallet_address, s.wallet_address)     AS wallet,
  COALESCE(b.total_buys, 0)                        AS total_buys,
  COALESCE(s.total_sells, 0)                       AS total_sells,
  COALESCE(b.total_buys, 0) + COALESCE(s.total_sells, 0) AS total_trades,
  COALESCE(b.buys_7d, 0)                           AS buys_7d,
  COALESCE(b.buys_30d, 0)                          AS buys_30d,
  COALESCE(s.sells_30d, 0)                         AS sells_30d,
  COALESCE(b.collections_traded, 0)                AS collections_active,
  
  -- Buy/sell ratio for intent analysis
  ROUND(
    CAST(COALESCE(b.total_buys, 0) AS DOUBLE) / 
    NULLIF(COALESCE(s.total_sells, 0), 0), 2
  )                                                AS buy_sell_ratio,

  -- Whale tier (Chinese labels for CN community)
  CASE
    WHEN COALESCE(b.total_buys, 0) >= 500 THEN '超级鲸鱼'
    WHEN COALESCE(b.total_buys, 0) >= 100 THEN '大鲸鱼'
    WHEN COALESCE(b.total_buys, 0) >= 30  THEN '中型交易者'
    ELSE '散户'
  END                                              AS whale_tier,
  
  -- Activity status (last 30 days)
  CASE 
    WHEN COALESCE(b.buys_30d, 0) + COALESCE(s.sells_30d, 0) > 0 
    THEN '活跃' 
    ELSE '休眠' 
  END                                              AS status,
  
  b.first_trade,
  b.last_trade,
  
  -- Days since last trade (detect dormant whales returning)
  DATE_DIFF('day', COALESCE(b.last_trade, s.last_trade), CURRENT_DATE) AS days_since_active

FROM buyer_stats b
FULL OUTER JOIN seller_stats s ON b.wallet_address = s.wallet_address
WHERE COALESCE(b.total_buys, 0) >= 10
ORDER BY total_trades DESC
LIMIT 200

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type : Table (leaderboard)
--   Columns    : wallet, whale_tier, total_trades, buys_7d, status, buy_sell_ratio
--   Sort       : total_trades DESC
--   Color-code: whale_tier column (超级鲸鱼 = red, 大鲸鱼 = orange, etc.)
--
-- Story this tells:
--   - Who are the biggest players? (wallet + total_trades)
--   - Are they active right now? (status + buys_7d)
--   - Are they buying or selling? (buy_sell_ratio)
--   - Is a dormant whale waking up? (days_since_active < 7)
-- ============================================================================