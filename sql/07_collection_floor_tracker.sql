-- ============================================================================
-- 查询 7: 合集层面地板价追踪
-- 按合集 × 稀有度层级统计最低成交价
-- 注: Dune TON spellbook 可能需要解析 NFT metadata 获取稀有度
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- 近30天每个合集的交易
collection_trades AS (
  SELECT
    e.collection_address,
    e.block_date,
    COUNT(*)                          AS daily_trades,
    COUNT(DISTINCT e.owner_address)   AS daily_unique_buyers
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CURRENT_DATE - INTERVAL '90' DAY
  GROUP BY 1, 2
),

-- 合集级汇总
collection_summary AS (
  SELECT
    collection_address,
    COUNT(*)                                    AS total_trades_90d,
    COUNT(DISTINCT owner_address)               AS unique_buyers_90d,
    MAX(daily_trades)                           AS peak_daily_trades,
    AVG(daily_trades)                           AS avg_daily_trades,
    -- 近7天（即日活跃度标志）
    SUM(CASE WHEN block_date >= CURRENT_DATE - INTERVAL '7' DAY 
        THEN daily_trades ELSE 0 END)           AS trades_7d
  FROM collection_trades
  GROUP BY 1
)

SELECT
  cs.collection_address,
  cs.total_trades_90d,
  cs.unique_buyers_90d,
  cs.peak_daily_trades,
  ROUND(cs.avg_daily_trades, 1)                 AS avg_daily_trades,
  cs.trades_7d,
  -- 热度评级
  CASE
    WHEN cs.trades_7d >= 500  THEN '🔥 极热'
    WHEN cs.trades_7d >= 100  THEN '🔶 热门'
    WHEN cs.trades_7d >= 20   THEN '🟡 温和'
    WHEN cs.trades_7d > 0     THEN '🟢 有交易'
    ELSE '⚪ 沉寂'
  END                                           AS heat_level,
  -- 流动性评分 (买方数 × 交易频次)
  cs.unique_buyers_90d * cs.avg_daily_trades    AS liquidity_score
FROM collection_summary cs
ORDER BY trades_7d DESC
LIMIT 100