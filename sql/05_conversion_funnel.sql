-- ============================================================================
-- 查询 5: 链上转化漏斗 — 铸造 → 首次交易 → 活跃交易
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- 铸造事件（每个 NFT 的出生记录）
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

-- 首次交易时间
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

-- 计算转化漏斗
funnel AS (
  SELECT
    DATE_TRUNC('week', m.mint_date)          AS week,
    COUNT(DISTINCT m.nft_id)                  AS total_minted,
    COUNT(DISTINCT fs.nft_id)                 AS ever_traded,
    COUNT(DISTINCT CASE 
      WHEN fs.first_sale_date <= m.mint_date + INTERVAL '7' DAY 
      THEN fs.nft_id 
    END)                                      AS traded_within_7d,
    COUNT(DISTINCT CASE 
      WHEN fs.first_sale_date <= m.mint_date + INTERVAL '30' DAY 
      THEN fs.nft_id 
    END)                                      AS traded_within_30d
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
  ROUND(CAST(ever_traded AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2) 
                                              AS pct_ever_traded,
  traded_within_7d,
  ROUND(CAST(traded_within_7d AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2) 
                                              AS pct_7d_flip,
  traded_within_30d,
  ROUND(CAST(traded_within_30d AS DOUBLE) / NULLIF(total_minted, 0) * 100, 2) 
                                              AS pct_30d_flip
FROM funnel
WHERE week >= CAST('2025-08-01' AS TIMESTAMP)
ORDER BY week DESC