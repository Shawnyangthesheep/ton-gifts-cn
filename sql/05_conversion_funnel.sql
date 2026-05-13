-- ============================================================================
-- Query 5: Conversion Funnel — Mint → First Trade → Active Trading
-- Tracks how many minted NFTs end up being traded on secondary markets
-- ============================================================================
-- Use case: High flip rates = speculative market; Low = collector/hodler market
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- Mint events (birth of each NFT)
mints AS (
  SELECT
    collection_address,
    nft_id,
    MIN(block_date) AS mint_date
  FROM ton.nft_events
  WHERE type = 'mint'
    AND collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1, 2
),

-- First sale time per NFT
first_sale AS (
  SELECT
    e.collection_address,
    e.nft_id,
    MIN(e.block_date) AS first_sale_date
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1, 2
),

-- Weekly funnel metrics
funnel AS (
  SELECT
    DATE_TRUNC('week', m.mint_date)           AS week,
    COUNT(DISTINCT m.nft_id)                  AS total_minted,
    COUNT(DISTINCT fs.nft_id)                 AS ever_traded,
    COUNT(DISTINCT CASE 
      WHEN fs.first_sale_date <= m.mint_date + INTERVAL '7' DAY 
      THEN fs.nft_id END)                    AS traded_within_7d,
    COUNT(DISTINCT CASE 
      WHEN fs.first_sale_date <= m.mint_date + INTERVAL '30' DAY 
      THEN fs.nft_id END)                    AS traded_within_30d
  FROM mints m
  LEFT JOIN first_sale fs 
    ON m.collection_address = fs.collection_address 
    AND m.nft_id = fs.nft_id
  GROUP BY 1
)

SELECT
  week,
  total_minted,
  ever_traded,
  ROUND(CAST(ever_traded AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2)     AS pct_ever_traded,
  traded_within_7d,
  ROUND(CAST(traded_within_7d AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2) AS pct_7d_flip,
  traded_within_30d,
  ROUND(CAST(traded_within_30d AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2) AS pct_30d_flip,
  
  -- Market sentiment indicator
  CASE
    WHEN ROUND(CAST(traded_within_7d AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2) > 50
    THEN '🔥 高度投机'
    WHEN ROUND(CAST(traded_within_7d AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2) > 20
    THEN '🔶 交易活跃'
    WHEN ROUND(CAST(traded_within_7d AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2) > 5
    THEN '🟢 正常流通'
    ELSE '⚪ 收藏主导'
  END                                                                       AS market_sentiment

FROM funnel
WHERE week >= CAST('2025-08-01' AS TIMESTAMP)
ORDER BY week DESC

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type : Funnel (or dual-axis line chart)
--   X-axis     : week
--   Y-axis L   : total_minted (bars for scale)
--   Y-axis R   : pct_7d_flip, pct_30d_flip (lines for conversion rates)
--
-- Story this tells:
--   - Are new mints being immediately flipped? (pct_7d_flip)
--   - What % of Gifts ever enter secondary market? (pct_ever_traded)
--   - Is the market speculative or collector-driven? (market_sentiment)
-- For Chinese traders: High pct_7d_flip = 投机氛围重, be careful
-- ============================================================================