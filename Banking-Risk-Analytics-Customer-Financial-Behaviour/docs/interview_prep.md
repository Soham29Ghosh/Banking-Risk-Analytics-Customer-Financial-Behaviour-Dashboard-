# Interview Prep: Banking Risk Analytics Project

## 1. Two-minute project pitch (practise this out loud)

> "I analysed a banking dataset of 3,000 clients with 25 attributes (income, loans, deposits, credit cards, loyalty tier and the bank's own risk weighting) plus three lookup tables.
>
> I started with data-quality checks in Python and found that 59 Client IDs were reused by different people. So a simple distinct count would undercount clients by 60. I kept every row and created a surrogate key.
>
> I then engineered features like total loan, total deposit and loan-to-income, loaded the data into PostgreSQL with a proper schema, and answered 18 business questions with SQL using CTEs and window functions.
>
> The most interesting finding was about risk. The bank's Risk Weighting rises with income, so it really measures exposure size. But affordability goes the other way: a third of the lowest-risk clients have loans more than six times their income. I flagged 595 clients, about 20%, who are rated low-risk but are highly leveraged and hold a quarter of all bank loans.
>
> I also found the bank lends 1.16 times what it holds in deposits, and that loyalty tiers don't reflect value: deposits were statistically the same across tiers.
>
> Finally, I built a 3-page Tableau dashboard and recommended adding an affordability check to risk scoring, cross-selling deposits to borrower-heavy clients and rebuilding the loyalty tiers."

## 2. Questions you'll likely get, with answers

**Q: Where did the data come from? Is it real?**
It's a public sample banking dataset widely used for analytics practice; it may be synthetic. A tutorial originally built a Power BI dashboard on it. I rebuilt the work in Tableau and went further: the data-quality audit, the SQL layer, the loan-to-income risk analysis, statistical tests and segmentation. *(Be honest. Interviewers respect "I started from a tutorial and extended it", and they can tell when someone hides it.)*

**Q: Why not just drop the duplicate Client IDs?**
They weren't duplicates. The names, ages and join dates were all different, so they were different people. Dropping them would lose 59 real clients and their balances. The right fix was a surrogate key, plus flagging the issue upstream.

**Q: How did you define total loan and total deposit?**
Total loan = bank loans + business lending + credit card balance. Total deposit = bank deposits + savings + checking + foreign currency accounts.

**Q: What is the loan-to-deposit ratio and why does it matter?**
Loans ÷ deposits. Above 1 means the bank lends more than it holds in deposits and must fund the difference elsewhere, usually at a higher cost. Here it is 1.16, a $618M gap.

**Q: Why loan-to-income, and why 6×?**
Loan-to-income measures affordability: how many years of income the loan represents. 6× is a common rule-of-thumb ceiling for mortgage-style lending. It's an assumption, so I'd calibrate it against default data if that were available.

**Q: How do you know risk weighting doesn't capture affordability?**
Two numbers. Spearman correlation between income and risk weighting is +0.68. Correlation between loan-to-income and risk weighting is slightly *negative* (−0.13). And the share of clients over 6× income falls steadily from 32.5% at weight 1 to 16.3% at weight 5.

**Q: Why Spearman and Kruskal–Wallis instead of Pearson and ANOVA?**
The balances are heavily right-skewed with large outliers, and risk weighting is ordinal (1–5). Rank-based (non-parametric) tests don't assume normality and are robust to outliers.

**Q: What does p = 0.16 for loyalty vs deposits mean?**
If the loyalty tiers truly had the same deposit distribution, we'd see differences at least this large about 16% of the time just by chance. That's above 0.05, so there's no evidence the tiers differ in deposits.

**Q: How did you create the segments? Why not k-means?**
I used a 2×2 median split of total loan vs total deposit. It's simple, explainable to business users and directly actionable (who to cross-sell deposits to, who to cross-sell lending to). K-means would be a next step if I had more behavioural variables, like transactions or product usage.

**Q: Why did you handle outliers the way you did?**
Large balances are real clients and matter most for risk, so I kept them. I reported medians alongside sums and means so the outliers don't distort typical-client figures.

**Q: Explain one of your SQL queries.**
Pick Q15 or Q16. For example, Q16 uses `ROW_NUMBER() OVER (PARTITION BY banking_relationship ORDER BY total_loan DESC)` to find the largest risk-weight-5 exposure in each relationship type, then filters `rn = 1`.

**Q: Why a view in SQL?**
`v_client_metrics` defines the derived metrics (total loan, loan-to-income, bands) once. Every query reuses the same definitions, which avoids inconsistent formulas.

**Q: Why use COUNT of a key instead of COUNTD of Client ID in Tableau?**
Because Client IDs are reused, COUNTD gives 2,940 instead of 3,000.

**Q: What would you do with more time or more data?**
- Get actual default/delinquency outcomes and build a probability-of-default model (logistic regression or gradient boosting) to replace the rule-based flag.
- Add transaction data for behavioural segmentation.
- Automate the pipeline and schedule a dashboard refresh.

**Q: What was the hardest part?**
Noticing that "Total Clients" was wrong. The numbers looked plausible, and only checking row count against distinct IDs revealed it. It taught me to validate keys before building KPIs.

**Q: Who would use this dashboard, and what decision would they make?**
- Credit risk: review the 595 flagged clients.
- Retail and relationship managers: cross-sell to Borrower-heavy clients and Savers.
- Marketing: redesign the loyalty tiers.

## 3. Concepts to revise

Loan-to-deposit ratio · funding gap · risk weighting / risk-weighted assets (basic idea) · NPAs (for Indian banking interviews) · median vs mean with skewed data · Spearman vs Pearson · Kruskal–Wallis vs ANOVA · p-values · surrogate vs natural keys · window functions · CTEs · PERCENTILE_CONT · Tableau LOD vs table calculations · COUNT vs COUNTD.
