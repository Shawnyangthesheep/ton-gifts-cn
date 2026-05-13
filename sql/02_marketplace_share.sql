-- ============================================================================
-- Query 2: Marketplace Share Analysis
-- Compares trading volume share across major TON NFT marketplaces
-- ============================================================================
--
-- Marketplace Identification Method:
--   Since Dune's ton.nft_events doesn't have a 'marketplace' field,
--   we trace trades back to the marketplace by checking which contract
--   initiated the transaction in ton.messages.
--
--   UPDATE: Replace the contract_address values below with verified
--   marketplace smart contract addresses on TON mainnet.
--   Sources: marketplace docs, TON Explorer, or existing Dune dashboards.
--
-- Reference marketplaces for Telegram Gifts:
--   - Fragment      : Telegram's official marketplace (fragment.com)
--   - Getgems       : Largest TON NFT marketplace (getgems.io)
--   - Disintar      : Popular among Chinese users (disintar.io)
--   - TONNEL        : TON NFT marketplace (tonnel.network)
--   - Portals       : NFT marketplace aggregator
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- ==========================================================================
-- ADDRESS LOOKUP TABLE — Verified marketplace contract addresses (2026-05-13)
-- Format: user-friendly TON address (EQ/EQC prefix)
-- Dune ton.messages stores addresses in user-friendly format → can match directly
--
-- Verified sources:
--   Getgems  : https://github.com/getgems-io/nft-contracts (official repo)
--   Others   : See sql/_marketplace_addresses.md for full reference + TODOs
-- ==========================================================================
marketplace_map AS (
  -- Getgems NFT Marketplace (official contract from getgems-io/nft-contracts)
  -- marketplaceAddress: EQBYTuYbLf8INxFtD8tQeNk5ZLy-nAX9ahQbG_yl1qQ-GEMS
  -- marketplaceFeeAddress (5% royalty): EQCjk1hh952vWaE9bRguFkAhDAL5jj3xj9p0uPWrFBq-GEMS
  SELECT 'Getgems'    AS label, 'EQBYTuYbLf8INxFtD8tQeNk5ZLy-nAX9ahQbG_yl1qQ-GEMS' AS contract_str WHERE 1=1
  UNION ALL SELECT 'Getgems', 'EQCjk1hh952vWaE9bRguFkAhDAL5jj3xj9p0uPWrFBq-GEMS' WHERE 1=1
  -- Fragment (Telegram): TODO — verify via https://fragment.com or TON Explorer
  UNION ALL SELECT 'Fragment',   NULL WHERE 1=0
  -- Disintar: TODO — verify via https://disintar.io
  UNION ALL SELECT 'Disintar',   NULL WHERE 1=0
  -- TONNEL: TODO — verify via https://tonnel.network
  UNION ALL SELECT 'TONNEL',     NULL WHERE 1=0
  -- Portals: TODO — verify via https://portals.io
  UNION ALL SELECT 'Portals',    NULL WHERE 1=0
),

marketplace_addresses AS (
  SELECT label, contract_str AS full_addr
  FROM marketplace_map
  WHERE contract_str IS NOT NULL
),

gift_trades AS (
  SELECT DISTINCT
    e.tx_hash,
    e.block_date,
    e.collection_address,
    e.owner_address   AS buyer,
    e.prev_owner      AS seller
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CAST('2025-08-01' AS TIMESTAMP)
),

-- Match trades to marketplaces via ton.messages
trade_marketplace AS (
  SELECT
    g.tx_hash,
    COALESCE(ma.label, 'Other/Unknown') AS marketplace
  FROM gift_trades g
  LEFT JOIN ton.messages m ON m.tx_hash = g.tx_hash
  LEFT JOIN marketplace_addresses ma
    ON (m.source = ma.full_addr OR m.destination = ma.full_addr)
  GROUP BY g.tx_hash, ma.label
  -- When no marketplace matched, marketplace = 'Other/Unknown'
),

-- ==========================================================================
-- FALLBACK: If ton.messages matching is unavailable, use a heuristic
-- based on transaction patterns. Comment this block out and use
-- the trade_marketplace CTE above when addresses are configured.
-- ==========================================================================
fallback_trade_marketplace AS (
  SELECT
    g.tx_hash,
    'Not Yet Classified' AS marketplace
  FROM gift_trades g
)

SELECT
  DATE_TRUNC('week', g.block_date)          AS week,
  COALESCE(tm.marketplace, 'Other/Unknown') AS marketplace,
  COUNT(*)                                   AS trade_count,
  COUNT(DISTINCT g.collection_address)       AS active_collections,
  COUNT(DISTINCT g.buyer)                    AS unique_buyers,
  ROUND(
    CAST(COUNT(*) AS DOUBLE) / NULLIF(
      SUM(COUNT(*)) OVER (PARTITION BY DATE_TRUNC('week', g.block_date)), 0
    ) * 100, 2
  )                                          AS pct_market_share
FROM gift_trades g
LEFT JOIN trade_marketplace tm ON g.tx_hash = tm.tx_hash
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC

-- ============================================================================
-- Dune Visualization Hint:
--   Chart type : Stacked Bar / 100% Stacked Area
--   X-axis     : week
--   Y-axis     : pct_market_share OR trade_count
--   Group by   : marketplace (color)
--   Purpose    : Shows which marketplace Chinese users prefer over time
-- ============================================================================