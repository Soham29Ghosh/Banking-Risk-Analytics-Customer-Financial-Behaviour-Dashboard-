-- =====================================================================
-- 03_analysis_queries.sql : 18 business questions answered in SQL
-- Run:  psql -d banking -f sql/03_analysis_queries.sql
-- Amounts are in the dataset's (unspecified) currency, shown as $.
-- =====================================================================

-- ---------------------------------------------------------------
-- SECTION A. DATA QUALITY
-- ---------------------------------------------------------------

-- Q1. Is client_id a reliable key? (rows vs distinct ids)
SELECT COUNT(*)                  AS total_rows,
       COUNT(DISTINCT client_id) AS distinct_client_ids,
       COUNT(*) - COUNT(DISTINCT client_id) AS undercount_if_distinct_counted
FROM clients;

-- Q2. Which client_ids are shared by different people?
SELECT client_id,
       COUNT(*)                         AS rows_with_id,
       STRING_AGG(name, ' | ' ORDER BY name) AS names
FROM clients
GROUP BY client_id
HAVING COUNT(*) > 1
ORDER BY client_id
LIMIT 10;

-- Q3. Clients holding zero balances in key products
SELECT SUM(CASE WHEN bank_loans = 0       THEN 1 ELSE 0 END) AS zero_bank_loans,
       SUM(CASE WHEN bank_deposits = 0    THEN 1 ELSE 0 END) AS zero_bank_deposits,
       SUM(CASE WHEN business_lending = 0 THEN 1 ELSE 0 END) AS zero_business_lending
FROM clients;

-- ---------------------------------------------------------------
-- SECTION B. PORTFOLIO KPIs
-- ---------------------------------------------------------------

-- Q4. Headline KPIs and book-level loan-to-deposit ratio
SELECT COUNT(*)                                          AS total_clients,
       ROUND(SUM(total_loan)    / 1e6, 1)                AS total_loans_m,
       ROUND(SUM(total_deposit) / 1e6, 1)                AS total_deposits_m,
       ROUND(SUM(total_loan) / SUM(total_deposit), 3)    AS loan_to_deposit_ratio,
       ROUND((SUM(total_loan) - SUM(total_deposit)) / 1e6, 1) AS funding_gap_m,
       ROUND(SUM(total_loan * processing_fee_rate) / 1e6, 1)  AS est_fee_revenue_m
FROM v_client_metrics;

-- Q5. Loan book composition (share of each product)
SELECT product, ROUND(amount / 1e6, 1) AS amount_m,
       ROUND(100.0 * amount / SUM(amount) OVER (), 1) AS pct_of_loans
FROM (
    SELECT 'Bank Loans' AS product, SUM(bank_loans) AS amount FROM clients
    UNION ALL SELECT 'Business Lending', SUM(business_lending) FROM clients
    UNION ALL SELECT 'Credit Card Balance', SUM(credit_card_balance) FROM clients
) t
ORDER BY amount DESC;

-- ---------------------------------------------------------------
-- SECTION C. CUSTOMER SEGMENTS
-- ---------------------------------------------------------------

-- Q6. Loans, deposits and share of book by banking relationship
SELECT banking_relationship,
       COUNT(*)                                                    AS clients,
       ROUND(SUM(total_loan) / 1e6, 1)                             AS loans_m,
       ROUND(SUM(total_deposit) / 1e6, 1)                          AS deposits_m,
       ROUND(100.0 * SUM(total_loan) / SUM(SUM(total_loan)) OVER (), 1) AS pct_of_loan_book,
       ROUND(SUM(total_loan) / SUM(total_deposit), 2)              AS loan_to_deposit
FROM v_client_metrics
GROUP BY banking_relationship
ORDER BY loans_m DESC;

-- Q7. Nationality profile
SELECT nationality,
       COUNT(*) AS clients,
       ROUND(SUM(total_loan) / 1e6, 1)    AS loans_m,
       ROUND(SUM(total_deposit) / 1e6, 1) AS deposits_m,
       ROUND(AVG(estimated_income), 0)    AS avg_income
FROM v_client_metrics
GROUP BY nationality
ORDER BY loans_m DESC;

-- Q8. Income band: who is most leveraged?
SELECT income_band,
       COUNT(*) AS clients,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY loan_to_income)::numeric, 2) AS median_loan_to_income,
       ROUND(100.0 * SUM(total_loan) / SUM(SUM(total_loan)) OVER (), 1)               AS pct_of_loan_book
FROM v_client_metrics
GROUP BY income_band
ORDER BY median_loan_to_income DESC;

-- Q9. Age group x gender: average deposits
SELECT age_group, gender, COUNT(*) AS clients,
       ROUND(AVG(total_deposit), 0) AS avg_deposit,
       ROUND(AVG(total_loan), 0)    AS avg_loan
FROM v_client_metrics
GROUP BY age_group, gender
ORDER BY age_group, gender;

-- Q10. New-client acquisition trend by join year, with year-over-year change
WITH yearly AS (
    SELECT EXTRACT(YEAR FROM joined_bank)::int AS join_year, COUNT(*) AS new_clients
    FROM clients GROUP BY 1
)
SELECT join_year, new_clients,
       new_clients - LAG(new_clients) OVER (ORDER BY join_year) AS yoy_change,
       SUM(new_clients) OVER (ORDER BY join_year)               AS cumulative_clients
FROM yearly
ORDER BY join_year;

-- Q11. Relationship (product-mix) segments using median splits
WITH med AS (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_loan)    AS loan_med,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_deposit) AS dep_med
    FROM v_client_metrics
), seg AS (
    SELECT v.*,
           CASE WHEN total_loan >= loan_med AND total_deposit >= dep_med THEN 'Full relationship'
                WHEN total_loan >= loan_med                               THEN 'Borrower-heavy'
                WHEN total_deposit >= dep_med                             THEN 'Saver'
                ELSE 'Low engagement' END AS relationship_segment
    FROM v_client_metrics v CROSS JOIN med
)
SELECT relationship_segment, COUNT(*) AS clients,
       ROUND(SUM(total_loan) / 1e6, 1)    AS loans_m,
       ROUND(SUM(total_deposit) / 1e6, 1) AS deposits_m,
       ROUND(AVG(risk_weighting), 2)      AS avg_risk_weight
FROM seg
GROUP BY relationship_segment
ORDER BY loans_m DESC;

-- Q12. Top 10 clients by total exposure, and their share of the whole book
SELECT client_key, client_id, name, banking_relationship,
       ROUND(total_loan, 0) AS total_loan,
       risk_weighting,
       ROUND(100.0 * total_loan / SUM(total_loan) OVER (), 3) AS pct_of_book
FROM v_client_metrics
ORDER BY total_loan DESC
LIMIT 10;

-- ---------------------------------------------------------------
-- SECTION D. RISK
-- ---------------------------------------------------------------

-- Q13. Does risk weighting track affordability? (share of clients with loan > 6x income per risk band)
SELECT risk_weighting,
       COUNT(*) AS clients,
       ROUND(AVG(estimated_income), 0) AS avg_income,
       ROUND(AVG(total_loan), 0)       AS avg_total_loan,
       ROUND(100.0 * AVG(CASE WHEN loan_to_income > 6 THEN 1 ELSE 0 END), 1) AS pct_loan_over_6x_income
FROM v_client_metrics
GROUP BY risk_weighting
ORDER BY risk_weighting;

-- Q14. Under-rated risk: rated low (<= 2) but loan > 6x income
SELECT COUNT(*)                                 AS underrated_clients,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM clients), 1) AS pct_of_clients,
       ROUND(SUM(bank_loans) / 1e6, 1)          AS their_bank_loans_m,
       ROUND(100.0 * SUM(bank_loans) / (SELECT SUM(bank_loans) FROM clients), 1) AS pct_of_bank_loans
FROM v_client_metrics
WHERE risk_weighting <= 2 AND loan_to_income > 6;

-- Q15. Under-rated risk clients per investment advisor, ranked
SELECT investment_advisor,
       COUNT(*) AS clients,
       SUM(CASE WHEN risk_weighting <= 2 AND loan_to_income > 6 THEN 1 ELSE 0 END) AS underrated_clients,
       RANK() OVER (ORDER BY SUM(CASE WHEN risk_weighting <= 2 AND loan_to_income > 6 THEN 1 ELSE 0 END) DESC) AS review_priority
FROM v_client_metrics
GROUP BY investment_advisor
ORDER BY review_priority
LIMIT 10;

-- Q16. Highest-risk client per banking relationship (top exposure among risk weight 5)
SELECT banking_relationship, client_id, name, ROUND(total_loan, 0) AS total_loan
FROM (
    SELECT v.*, ROW_NUMBER() OVER (PARTITION BY banking_relationship ORDER BY total_loan DESC) AS rn
    FROM v_client_metrics v
    WHERE risk_weighting = 5
) t
WHERE rn = 1
ORDER BY total_loan DESC;

-- ---------------------------------------------------------------
-- SECTION E. LOYALTY & FEES
-- ---------------------------------------------------------------

-- Q17. Does loyalty tier reflect value?
SELECT loyalty_classification,
       COUNT(*) AS clients,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_deposit)::numeric, 0)    AS median_deposit,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY estimated_income)::numeric, 0) AS median_income,
       ROUND(AVG(tenure_years), 1) AS avg_tenure_years
FROM v_client_metrics
GROUP BY loyalty_classification
ORDER BY CASE loyalty_classification WHEN 'Jade' THEN 1 WHEN 'Silver' THEN 2 WHEN 'Gold' THEN 3 ELSE 4 END;

-- Q18. Fee structure: clients and estimated fee revenue share
SELECT fee_structure,
       COUNT(*) AS clients,
       ROUND(SUM(total_loan * processing_fee_rate) / 1e6, 1) AS fee_revenue_m,
       ROUND(100.0 * SUM(total_loan * processing_fee_rate)
             / SUM(SUM(total_loan * processing_fee_rate)) OVER (), 1) AS pct_of_fee_revenue
FROM v_client_metrics
GROUP BY fee_structure
ORDER BY fee_revenue_m DESC;
