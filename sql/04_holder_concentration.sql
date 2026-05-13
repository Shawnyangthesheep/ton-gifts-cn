-- ============================================================================
-- Query 4: Holder Concentration Analysis (Gini Proxy)
-- Shows how concentrated Gift holdings are among top wallets
-- ============================================================================
-- Use case for Chinese traders: High concentration = easy price manipulation
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- Net holdings per wallet (buys - sells)
wallet_holdings AS (
  SELECT
    COALESCE(b.wallet, s.wallet) AS wallet,
    COALESCE(b.net_buys, 0) - COALESCE(s.net_sells, 0) AS net_holdings
  FROM (
    SELECT owner_address AS wallet, COUNT(*) AS net_buys
    FROM ton.nft_events
    WHERE type = 'sale'
      AND collection_address IN (SELECT col_address FROM gift_collections)
    GROUP BY 1
  ) b
  FULL OUTER JOIN (
    SELECT prev_owner AS wallet, COUNT(*) AS net_sells
    FROM ton.nft_events
    WHERE type = 'sale'
      AND collection_address IN (SELECT col_address FROM gift_collections)
    GROUP BY 1
  ) s ON b.wallet = s.wallet
  WHERE COALESCE(b.net_buys, 0) - COALESCE(s.net_sells, 0) > 0
),

total_holdings AS (
  SELECT SUM(net_holdings) AS grand_total FROM wallet_holdings
),

-- Ranked for top-N analysis
ranked AS (
  SELECT
    net_holdings,
    ROW_NUMBER() OVER (ORDER BY net_holdings DESC) AS rn,
    COUNT(*) OVER () AS total_wallets
  FROM wallet_holdings
)

SELECT
  'Top 10' AS segment,
  SUM(net_holdings) AS holdings,
  COUNT(*) AS wallet_count,
  ROUND(CAST(SUM(net_holdings) AS DOUBLE) / NULLIF((SELECT grand_total FROM total_holdings), 0) * 100, 2) AS pct_of_total
FROM (
  SELECT net_holdings FROM ranked WHERE rn <= 10
) t

UNION ALL

SELECT
  'Top 50',
  SUM(net_holdings),
  COUNT(*),
  ROUND(CAST(SUM(net_holdings) AS DOUBLE) / NULLIF((SELECT grand_total FROM total_holdings), 0) * 100, 2)
FROM (
  SELECT net_holdings FROM ranked WHERE rn <= 50
) t

UNION ALL

SELECT
  'Top 100',
  SUM(net_holdings),
  COUNT(*),
  ROUND(CAST(SUM(net_holdings) AS DOUBLE) / NULLIF((SELECT grand_total FROM total_holdings), 0) * 100, 2)
FROM (
  SELECT net_holdings FROM ranked WHERE rn <= 100
) t

UNION ALL

SELECT
  'All Wallets',
  SUM(net_holdings),
  COUNT(*),
  100.0
FROM wallet_holdings

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type : Stacked Bar (horizontal or vertical)
--   X-axis     : segment (Top 10 → All Wallets)
--   Y-axis     : pct_of_total (0-100%)
--   Color      : Segment (Top 10 = red warning, Top 50 = orange, etc.)
--
-- Story this tells:
--   - If Top 10 hold > 50% → High manipulation risk (集中持仓风险高)
--   - If Top 100 hold < 20% → Healthy distribution (持仓分散，健康市场)
-- Chinese traders should avoid markets where a few whales control supply.
-- ============================================================================