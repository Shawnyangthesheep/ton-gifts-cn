-- ============================================================================
-- Query 6: Weekly Marketplace Trend (CNY Overlay Ready)
-- Tracks weekly trade volume per marketplace for CNY denomination overlay
-- ============================================================================
-- Marketplace identification:
--   This query identifies marketplaces via ton.messages source/destination.
--   UPDATE THE CTE below with verified marketplace contract addresses.
--   Known marketplaces: Fragment, Getgems, Portals, Disintar, TONNEL
--
-- Dune Parameter: Set week range via the dashboard date filter.
-- CNY Overlay: Use Dune's "Format → Currency → CNY" on a calculated TON×price column.
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- ==========================================================================
-- TODO: REPLACE with verified marketplace contract addresses on TON
-- To find addresses: visit each marketplace's "About" page or check
-- existing Dune TON dashboards for reference.
-- Example (Getgems): EQ...
-- ==========================================================================
marketplace_addresses AS (
  SELECT 'Getgems'   AS marketplace, CAST(NULL AS VARCHAR) AS contract_address
  UNION ALL
  SELECT 'Fragment'   AS marketplace, CAST(NULL AS VARCHAR) AS contract_address
  UNION ALL
  SELECT 'Disintar'   AS marketplace, CAST(NULL AS VARCHAR) AS contract_address
  UNION ALL
  SELECT 'TONNEL'     AS marketplace, CAST(NULL AS VARCHAR) AS contract_address
  UNION ALL
  SELECT 'Portals'    AS marketplace, CAST(NULL AS VARCHAR) AS contract_address
),

gift_trades AS (
  SELECT
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

-- Identify marketplace via ton.messages matching
-- (Relies on messages.source/destination = marketplace contract address)
marketplace_matches AS (
  SELECT
    g.tx_hash,
    MAX(ma.marketplace) AS marketplace
  FROM gift_trades g
  JOIN ton.messages m ON m.tx_hash = g.tx_hash
  LEFT JOIN marketplace_addresses ma
    ON (m.source = ma.contract_address OR m.destination = ma.contract_address)
  WHERE ma.contract_address IS NOT NULL
  GROUP BY 1
),

weekly_market AS (
  SELECT
    DATE_TRUNC('week', g.block_date)      AS week,
    COALESCE(pm.marketplace, 'Other')     AS marketplace,
    COUNT(*)                                AS trades,
    COUNT(DISTINCT g.collection_address)    AS collections,
    COUNT(DISTINCT g.buyer)               AS buyers
  FROM gift_trades g
  LEFT JOIN marketplace_matches pm ON g.tx_hash = pm.tx_hash
  GROUP BY 1, 2
)

SELECT
  week,
  marketplace,
  trades,
  collections,
  buyers,
  ROUND(
    CAST(trades AS DOUBLE) / NULLIF(SUM(trades) OVER (PARTITION BY week), 0) * 100,
    2
  )                                          AS pct_share,
  trades - LAG(trades) OVER (
    PARTITION BY marketplace ORDER BY week
  )                                          AS wow_change,
  -- Placeholder for CNY overlay (Dune visualization):
  -- Once price_per_trade_TON is available, multiply by TON/CNY rate
  CAST(NULL AS DOUBLE)                       AS volume_ton_estimate,
  CAST(NULL AS DOUBLE)                       AS volume_cny_estimate
FROM weekly_market
ORDER BY week DESC, trades DESC

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type : Stacked Bar (or 100% Stacked Bar for pct_share)
--   X-axis     : week
--   Y-axis     : trades (or pct_share for % view)
--   Breakdown  : marketplace (color)
--   Add CNY toggle: duplicate chart, override Y-axis to volume_cny_estimate
-- ============================================================================
