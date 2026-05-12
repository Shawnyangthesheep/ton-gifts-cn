-- ============================================================================
-- 查询 4: 持仓集中度分析（Gini 系数代理指标）
-- 中国市场定制 — 识别集中持有风险
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- 每个地址持有的 Gift 数量（通过买入-卖出净额）
wallet_holdings AS (
  SELECT
    buys.wallet,
    COALESCE(buys.buy_count, 0) - COALESCE(sells.sell_count, 0) AS net_holdings
  FROM (
    SELECT owner_address AS wallet, COUNT(*) AS buy_count
    FROM ton.nft_events
    WHERE type = 'sale'
      AND collection_address IN (SELECT col_address FROM gift_collections)
    GROUP BY 1
  ) buys
  LEFT JOIN (
    SELECT prev_owner AS wallet, COUNT(*) AS sell_count
    FROM ton.nft_events
    WHERE type = 'sale'
      AND collection_address IN (SELECT col_address FROM gift_collections)
    GROUP BY 1
  ) sells ON buys.wallet = sells.wallet
  WHERE COALESCE(buys.buy_count, 0) - COALESCE(sells.sell_count, 0) > 0
),

-- 排名用于计算集中度
ranked AS (
  SELECT
    net_holdings,
    ROW_NUMBER() OVER (ORDER BY net_holdings) AS rn,
    COUNT(*) OVER ()                          AS total_wallets
  FROM wallet_holdings
)

SELECT
  'Top 10 wallets'  AS segment,
  SUM(net_holdings) AS holdings_in_segment,
  COUNT(*)          AS wallet_count,
  CAST(SUM(net_holdings) AS DOUBLE) / 
    CAST((SELECT SUM(net_holdings) FROM wallet_holdings) AS DOUBLE) * 100 
                    AS pct_of_total
FROM wallet_holdings
WHERE net_holdings IN (
  SELECT net_holdings FROM wallet_holdings ORDER BY net_holdings DESC LIMIT 10
)

UNION ALL

SELECT
  'Top 50 wallets',
  SUM(net_holdings),
  COUNT(*),
  CAST(SUM(net_holdings) AS DOUBLE) / 
    CAST((SELECT SUM(net_holdings) FROM wallet_holdings) AS DOUBLE) * 100
FROM wallet_holdings
WHERE net_holdings IN (
  SELECT net_holdings FROM wallet_holdings ORDER BY net_holdings DESC LIMIT 50
)

UNION ALL

SELECT
  'Top 100 wallets',
  SUM(net_holdings),
  COUNT(*),
  CAST(SUM(net_holdings) AS DOUBLE) / 
    CAST((SELECT SUM(net_holdings) FROM wallet_holdings) AS DOUBLE) * 100
FROM wallet_holdings
WHERE net_holdings IN (
  SELECT net_holdings FROM wallet_holdings ORDER BY net_holdings DESC LIMIT 100
)

UNION ALL

SELECT
  'All wallets',
  SUM(net_holdings),
  COUNT(*),
  100.0
FROM wallet_holdings
ORDER BY wallet_count