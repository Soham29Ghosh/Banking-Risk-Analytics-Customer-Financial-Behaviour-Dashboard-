# Insights & Recommendations: Banking Risk Analytics

**Data:** 3,000 client records (25 attributes) plus 3 lookup tables. Clients joined from 1995 to 2021; snapshot date 31-Dec-2021. Amounts are in the dataset's unspecified currency, shown as $. Every number here is reproduced by `notebooks/02_eda_segmentation_risk.ipynb` and `sql/03_analysis_queries.sql`.

## Executive summary

| KPI | Value |
|---|---|
| Clients | 3,000 (2,940 distinct Client IDs; see finding 1) |
| Total loans | $4,384M (Business Lending 59%, Bank Loans 40%, Credit Cards 0.2%) |
| Total deposits | $3,766M |
| Loan-to-deposit ratio | **1.16**, a funding gap of **$618M** |
| Estimated fee revenue | $158M (68% from High-fee clients) |
| Clients rated low-risk but highly leveraged | **595 (19.8%)**, holding **$448M (25.3%) of bank loans** |

## Key findings

**1. Client ID isn't a reliable key (data quality).**
59 Client IDs are each used by two different people (119 rows). A `DISTINCTCOUNT(Client ID)` KPI reports 2,940 clients, an undercount of 60. I kept all rows and used a surrogate key. In production, this should be escalated as a source-system integrity issue.

**2. Lending exceeds deposits.**
Loans are 1.16× deposits. The $618M gap must be funded from non-deposit sources, which are usually more expensive and less stable. The ratio is similar across all four relationship types (1.15–1.19), so this is a whole-book issue, not a channel issue.

**3. Exposure is concentrated in Private Bank and European clients.**
Private Bank holds 45% of clients and 45% of loans. European clients hold 44% of the loan book. Growth or stress in these two groups moves the whole portfolio.

**4. Risk Weighting measures exposure size, not affordability (key risk insight).**
Risk Weighting rises strongly with income (Spearman ρ = 0.68). But the share of clients whose bank loan exceeds 6× their income is **highest in the lowest risk band**: 32.5% at weight 1 vs 16.3% at weight 5. Low-income clients carry a median loan of 5.9× income vs 2.0× for high-income clients. Result: **595 clients rated low-risk (weight 1–2) have loans > 6× income**. They hold 25% of all bank loans, at a median of 9.1× income.

**5. Loyalty tiers don't reflect customer value.**
Median deposits, income and tenure aren't significantly different across Jade, Silver, Gold and Platinum (Kruskal–Wallis p = 0.16, 0.60 and 0.19). Platinum clients actually have the *lowest* median deposits. Rewards are not aligned with value.

**6. Fee tier isn't linked to client value.**
49% of clients are on the High fee structure, and they generate 68% of estimated fee revenue. Yet their income and loan sizes are no different from those of Low-fee clients. That's a revenue strength, but also a churn risk if competitors price lower.

**7. Product-mix segments.**
- **Full relationship** (above-median loans *and* deposits): 1,009 clients, $2.28B loans, $2.25B deposits. These are the most valuable clients.
- **Borrower-heavy**: 491 clients, $973M loans vs only $254M deposits. They are the biggest contributors to the funding gap.
- **Saver**: 491 clients with $803M deposits and few loans. They are under-served on lending and investment products.
- **Low engagement**: 1,009 clients, the lowest balances and lowest risk weights.

**8. Acquisition accelerated recently, and there is a data gap.**
New clients jumped from about 100–120 a year to 187 (2019) and 248 (2020). So about a fifth of clients (629, or 21%) joined in the last 3 years and have a short repayment history. There are **no clients with join dates in 1997–1998**, which is likely a data gap to confirm with the source team.

**9. Age, tenure and properties owned don't predict balances.**
These have near-zero correlation with loans and deposits, and clients aged 60+ (36% of clients) look like everyone else financially. Segmenting by age alone isn't useful.

## Recommendations

1. **Add an affordability rule to credit risk scoring.** Flag any client with a loan > 6× income for review regardless of Risk Weighting. Start with the 595 flagged clients, prioritised by advisor (Joe Carroll's book has the most: 44).
2. **Close the funding gap by cross-selling deposits to Borrower-heavy clients**, for example term-deposit offers bundled with loan servicing. Moving 10% of their loan value into deposits would add about $97M.
3. **Offer lending and investment products to Savers.** They are low-risk (average risk weight 2.1) and hold $803M of deposits.
4. **Rebuild loyalty tiers** on deposit balance, product count and tenure, so Platinum actually means high value.
5. **Review fee pricing** for High-fee clients in the Full-relationship segment, to protect the most valuable relationships from churn.
6. **Fix data quality at source:** enforce unique Client IDs and investigate the missing 1997–1998 cohort.

## Limitations

- This is a public sample dataset, possibly synthetic. There's no default/repayment outcome, so risk is assessed through *exposure and affordability proxies*, not actual losses.
- The processing-fee rates (High 5%, Mid 3%, Low 1%) are assumptions used to estimate revenue.
- The 6× loan-to-income threshold is a common rule of thumb. The flag should be calibrated against real default data.
