SELECT
    p.player_id,
    DATEDIFF(DAY, MAX(b.bet_date), '2026-03-31') AS recency_days,
    COUNT(b.bet_id) AS frequency,
    SUM(b.stake) AS monetary
FROM players p
JOIN bets b ON p.player_id = b.player_id
GROUP BY p.player_id;


/*WITH rfm_base AS (
    SELECT
        p.player_id,
        DATEDIFF(DAY, MAX(b.bet_date), '2026-03-31') AS recency_days,
        COUNT(b.bet_id) AS frequency,
        SUM(b.stake) AS monetary
    FROM players p
    JOIN bets b ON p.player_id = b.player_id
    GROUP BY p.player_id
)
SELECT
    player_id,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- DESC: most days ago = score 1, most recent = score 5
    NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,  -- ASC: lowest freq = score 1, highest = score 5
    NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score   -- ASC: lowest spend = score 1, highest = score 5
FROM rfm_base;*/

WITH rfm_base AS (
    SELECT
        p.player_id,
        DATEDIFF(DAY, MAX(b.bet_date), '2026-03-31') AS recency_days,
        COUNT(b.bet_id) AS frequency,
        SUM(b.stake) AS monetary
    FROM players p
    JOIN bets b ON p.player_id = b.player_id
    GROUP BY p.player_id
),
scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM rfm_base
),

segmented as (  
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
FROM scored)




SELECT
    segment,
    COUNT(*) AS players,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_players,
    ROUND(SUM(monetary), 0) AS total_stake,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_of_stake,
    ROUND(AVG(monetary), 0) AS avg_stake_per_player
FROM segmented   -- put the CASE query in a CTE named 'segmented'
GROUP BY segment
ORDER BY total_stake DESC;