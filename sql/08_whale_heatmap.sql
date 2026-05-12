-- ============================================================================
-- 查询 8: 鲸鱼活动热力图 — 按小时/星期/市场分布
-- 帮助中国交易者识别最佳交易时间段
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- 鲸鱼地址（近90天交易>=100次）
whales AS (
  SELECT owner_address AS wallet
  FROM ton.nft_events
  WHERE type = 'sale'
    AND collection_address IN (SELECT col_address FROM gift_collections)
    AND block_date >= CURRENT_DATE - INTERVAL '90' DAY
  GROUP BY 1
  HAVING COUNT(*) >= 100
),

-- 鲸鱼的按小时分布
whale_activity AS (
  SELECT
    EXTRACT(HOUR FROM e.block_date)     AS trade_hour,
    EXTRACT(DOW FROM e.block_date)      AS trade_dow,  -- 0=Sun, 6=Sat
    COUNT(*)                             AS whale_trades
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.owner_address IN (SELECT wallet FROM whales)
    AND e.block_date >= CURRENT_DATE - INTERVAL '60' DAY
  GROUP BY 1, 2
)

SELECT
  trade_dow,
  CASE trade_dow
    WHEN 0 THEN '周日' WHEN 1 THEN '周一' WHEN 2 THEN '周二'
    WHEN 3 THEN '周三' WHEN 4 THEN '周四' WHEN 5 THEN '周五'
    WHEN 6 THEN '周六'
  END                                     AS day_name_cn,
  trade_hour,
  -- UTC+8 北京时间转换
  (trade_hour + 8) % 24                   AS beijing_hour,
  whale_trades,
  -- 该时段占本日总交易的%
  CAST(whale_trades AS DOUBLE) / 
    SUM(whale_trades) OVER (PARTITION BY trade_dow) * 100 AS pct_of_day
FROM whale_activity
ORDER BY trade_dow, trade_hour