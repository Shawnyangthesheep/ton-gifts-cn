-- ============================================================================
-- 查询 3: 鲸鱼交易排行榜 & 巨鲸地址监控
-- 中国市场定制 — 识别大额交易者/地址，支持社区标记
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- 获取所有买家统计
buyer_stats AS (
  SELECT
    e.owner_address                          AS wallet_address,
    COUNT(*)                                 AS total_trades,
    COUNT(DISTINCT e.collection_address)     AS collections_traded,
    MIN(e.block_date)                        AS first_trade,
    MAX(e.block_date)                        AS last_trade,
    -- 按时间分段: 近7天 / 近30天
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '7' DAY THEN 1 ELSE 0 END)   AS trades_7d,
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '30' DAY THEN 1 ELSE 0 END)  AS trades_30d
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1
),

-- 卖家统计
seller_stats AS (
  SELECT
    e.prev_owner                             AS wallet_address,
    COUNT(*)                                 AS total_sales,
    COUNT(DISTINCT e.collection_address)     AS collections_sold,
    SUM(CASE WHEN e.block_date >= CURRENT_DATE - INTERVAL '30' DAY THEN 1 ELSE 0 END)  AS sales_30d
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
  GROUP BY 1
)

SELECT
  COALESCE(b.wallet_address, s.wallet_address) AS wallet,
  COALESCE(b.total_trades, 0)                  AS total_buys,
  COALESCE(s.total_sales, 0)                   AS total_sells,
  COALESCE(b.trades_7d, 0)                     AS buys_7d,
  COALESCE(b.trades_30d, 0)                    AS buys_30d,
  COALESCE(s.sales_30d, 0)                     AS sells_30d,
  COALESCE(b.collections_traded, 0)            AS collections_active,
  -- 鲸鱼评级
  CASE
    WHEN COALESCE(b.total_trades, 0) >= 500 THEN '🐋 超级鲸鱼'
    WHEN COALESCE(b.total_trades, 0) >= 100 THEN '🐳 大鲸鱼'
    WHEN COALESCE(b.total_trades, 0) >= 30  THEN '🐬 中型交易者'
    ELSE '🐟 散户'
  END                                          AS whale_tier,
  b.first_trade,
  b.last_trade,
  -- 活跃度: 最近30天是否仍在交易
  CASE WHEN COALESCE(b.trades_30d, 0) > 0 THEN '活跃' ELSE '休眠' END AS status
FROM buyer_stats b
FULL OUTER JOIN seller_stats s ON b.wallet_address = s.wallet_address
WHERE COALESCE(b.total_trades, 0) >= 10
ORDER BY total_buys DESC
LIMIT 200