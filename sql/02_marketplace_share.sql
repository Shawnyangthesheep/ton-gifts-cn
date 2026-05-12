-- ============================================================================
-- 查询 2: Telegram Gifts 各市场交易份额分析
-- 识别 5 大市场: Fragment / Getgems / Portals / Disintar / TONNEL
-- ============================================================================
-- 市场识别方法:
--   ton.messages 表记录交易来源地址，通过 source/destination 识别市场
--   dune.ton_foundation.dataset_labels 提供市场钱包标签
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- 获取所有 Gift 交易事件（含交易哈希）
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

-- 通过 messages 表追溯交易来源（识别市场）
marketplace_msg AS (
  SELECT
    m.tx_hash,
    CASE
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'fragment'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'fragment'
      ) THEN 'Fragment'
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'getgems'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'getgems'
      ) THEN 'Getgems'
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'disintar'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'disintar'
      ) THEN 'Disintar'
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'tonnel'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'tonnel'
      ) THEN 'TONNEL'
      WHEN m.source IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'portals'
      ) OR m.destination IN (
        SELECT address FROM dune.ton_foundation.dataset_labels
        WHERE label_type = 'marketplace' AND namespace = 'portals'
      ) THEN 'Portals'
      ELSE 'Other/Unknown'
    END AS marketplace
  FROM ton.messages m
  WHERE m.tx_hash IN (SELECT tx_hash FROM gift_trades)
    AND m.created_at >= CAST('2025-08-01' AS TIMESTAMP)
)

SELECT
  DATE_TRUNC('week', g.block_date)          AS week,
  COALESCE(m.marketplace, 'Other/Unknown')  AS marketplace,
  COUNT(*)                                   AS trade_count,
  COUNT(DISTINCT g.collection_address)       AS active_collections,
  COUNT(DISTINCT g.buyer)                    AS unique_buyers
FROM gift_trades g
LEFT JOIN marketplace_msg m ON g.tx_hash = m.tx_hash
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC