# RFM Player Segmentation — Sports Betting

RFM (Recency · Frequency · Monetary) segmentation of ~2,900 active sportsbook players using SQL Server window functions, mapping behavioral scores to seven actionable CRM segments.

**Tools:** SQL Server (T-SQL) · Tableau

**Headline finding: 28% of players drive 59% of total betting handle.**


# Business Questions

1. Where is player value actually concentrated?
2. Which players deserve VIP investment, which deserve win-back spend — and which deserve neither?
3. Are there high-value players quietly churning that a simple active/inactive view would miss?

## Segment Results

| Segment | Players | % of Players | Total Stake | % of Stake | Avg Stake |
|---|---|---|---|---|---|
| Champions | 529 | 18.0% | $1,247,962 | 44.1% | $2,359 |
| Regular | 587 | 20.0% | $550,655 | 19.5% | $938 |
| **At-Risk VIP** | **290** | **9.9%** | **$420,006** | **14.9%** | **$1,448** |
| At-Risk | 329 | 11.2% | $199,959 | 7.1% | $608 |
| Loyal / Active | 259 | 8.8% | $158,417 | 5.6% | $612 |
| Lost | 556 | 18.9% | $148,785 | 5.3% | $268 |
| New / Promising | 386 | 13.1% | $102,231 | 3.6% | $265 |

## Key Findings

- **Pareto concentration**: Champions (18% of players) hold 44% of handle; with At-Risk VIPs included, 28% of players drive 59% of stake
- **The At-Risk VIP segment is the money finding**: 290 formerly high-value players ($420K historical stake, $1,448 avg) gone quiet — the highest-ROI win-back target
- **Lost ≠ worth saving**: 19% of players but only $268 average stake — win-back spend here is wasted; the segment is deliberately deprioritized
- **Whale distribution**: max player stake ~$9,860 vs. typical ~$237 — a 40x gap that makes uniform player treatment economically irrational

## Recommendations

1. Targeted win-back campaign for the 290 At-Risk VIPs (with a holdout group to measure true incremental reactivation)
2. VIP protection program for Champions — 44% of handle in 529 players is also a **concentration risk**
3. Deprioritize win-back on the Lost segment; redirect that budget to At-Risk VIPs (~5x recoverable value per player)

---

## Methodology

Three-layer SQL pipeline:

```sql
-- 1. RFM base: per-player aggregates
WITH rfm_base AS (
    SELECT
        p.player_id,
        DATEDIFF(DAY, MAX(b.bet_date), '2026-03-31') AS recency_days,
        COUNT(b.bet_id)  AS frequency,
        SUM(b.stake)     AS monetary
    FROM players p
    JOIN bets b ON p.player_id = b.player_id
    GROUP BY p.player_id
),
-- 2. Quintile scoring
scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- note the DESC
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM rfm_base
)
-- 3. Ordered CASE mapping to segments (most specific first)
SELECT *,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3                  THEN 'Loyal / Active'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At-Risk VIP'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At-Risk'
        WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost'
        ELSE 'Regular'
    END AS segment
FROM scored;
```

### Design decisions worth noting

**The NTILE sort-direction trap.** For frequency and monetary, bigger = better (`ASC` → top values land in bucket 5). But recency is inverted: *smaller* = better. Sorting recency `DESC` puts the stalest players in bucket 1 and the most recently active in bucket 5. Get this wrong and your Champions segment fills with players who vanished a year ago — the single most common RFM implementation bug.

**Monetary = stake, not GGR.** RFM measures engagement value, not house profit. Scoring on GGR would rate winning VIPs as low-value exactly when the book most wants to retain them.

**Segment count = action count.** Seven segments because each maps to a distinct treatment. The At-Risk VIP bucket exists because folding it into generic "At-Risk" would bury a $420K opportunity.

### Known limitations

- Recency is partly confounded with tenure (late signups can't have high recency-days); production version would use rolling-window RFM or tenure-normalized recency
- Quintile boundaries are population-relative — cross-period comparisons need fixed thresholds
- Synthetic dataset: methodology transfers, dollar figures are illustrative

---

## Repository Structure

```
├── sql/
│   ├── 01_rfm_base.sql
│   ├── 02_rfm_scored_segments.sql
│   └── 03_segment_summary.sql
├── tableau/
│   └── rfm_dashboard.twbx (or Tableau Public link below)
└── README.md
```

## Dashboard

📊 Tableau Public: https://public.tableau.com/app/profile/ganesh.reddy.peesari/viz/PlayerValueSegmentationRFM/RFM

Related project: [Player Retention & Cohort Analysis](../retention-cohort-analysis) — same dataset, acquisition-side view of the lifecycle.

## About

Part of my data analytics portfolio — full portfolio on [Notion](https://literate-motion-b44.notion.site/Data-Portfolio-1e3fc4aaea2f807eb1e8d078ecba9b33).

**Ganesh Reddy Peesari** · [LinkedIn](https://linkedin.com/in/ganesh-reddy-peesari-27293527b) · peesariganeshreddy@gmail.com
