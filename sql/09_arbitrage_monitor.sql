-- ============================================================================
-- 查询 9: 跨市场套利价差监测（实验性）
-- ============================================================================
-- 限制说明:
--   1. Dune TON spellbook 暂无直接存储成交价格（TON 数额）的字段
--   2. 需要等 spellbook 更新 `ton.nft_trades` 表（如有 price/currency 字段）
--   3. 当前版本使用交易频率 & 买方活跃度作为替代热度信号
--
-- 升级计划（spellbook 完善后）:
--   - 加入 price_ton 字段 → 计算 CNY 等值
--   - 同一 NFT 在不同市场出现 → 价差检测
--   - 套利窗口 = 最低 ask - 最高 bid > 阈值
-- ============================================================================

WITH gift_collections AS (
  SELECT col_address
  FROM dune.rdmcd.result_gifts_collection_addresses
),

-- 每日各市场热度（代理价差：高热度市场倾向高溢价）
market_heat AS (
  SELECT
    DATE_TRUNC('day', e.block_date)       AS trade_date,
    COUNT(*)                               AS trades,
    COUNT(DISTINCT e.owner_address)        AS unique_buyers,
    COUNT(DISTINCT e.collection_address)   AS collections
  FROM ton.nft_events e
  WHERE e.type = 'sale'
    AND e.collection_address IN (SELECT col_address FROM gift_collections)
    AND e.block_date >= CURRENT_DATE - INTERVAL '30' DAY
  GROUP BY 1
)

SELECT
  trade_date,
  trades,
  unique_buyers,
  collections,
  -- 买方/交易比（高比值=散户主导，低比值=鲸鱼主导）
  ROUND(CAST(unique_buyers AS DOUBLE) / NULLIF(trades, 0), 3) AS buyer_ratio,
  -- 30日移动均线
  AVG(trades) OVER (ORDER BY trade_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trades_7d_ma,
  -- 交易量异常检测（偏离均线×2 = 可能套利窗口）
  CASE 
    WHEN trades > AVG(trades) OVER (ORDER BY trade_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) * 1.5
    THEN '📈 异常活跃 — 注意套利窗口'
    WHEN trades < AVG(trades) OVER (ORDER BY trade_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) * 0.5
    THEN '📉 异常冷清 — 可能地板价下跌'
    ELSE '正常'
  END                                       AS anomaly_alert
FROM market_heat
ORDER BY trade_date DESC