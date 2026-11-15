# Tableau Build Guide: Banking Risk Analytics Dashboard

This guide builds a **3-page interactive Tableau dashboard** from `data/processed/banking_clean.csv`. It works in both **Tableau Public web authoring** (in the browser) and **Tableau Desktop Public Edition**. Expect about 2–3 hours the first time.

The clean CSV already contains every engineered column (total loan, total deposit, income band, segments, risk flag and so on), so you only need a handful of calculated fields.

---

## 0. Setup (10 min)

1. Sign in at **public.tableau.com**. Then either choose **Create → Web Authoring**, or open Tableau Desktop Public Edition.
2. **Connect → Text file / Upload** → choose `banking_clean.csv`.
3. On the Data Source page, check the data types (click the small icon above each column):
   - `joined_bank` → **Date**
   - `client_key`, `risk_weighting`, `join_year`, `age`, `properties_owned`, `amount_of_credit_cards` → right-click → **Convert to Dimension** where you want them as categories. Keep `risk_weighting` as a **discrete** dimension.
   - `underrated_risk_flag`, `client_id_reused` → **Boolean** (or String "True"/"False")
4. Rename the data source to **Banking Clients** (top-left).
5. Optional but nice: right-click each money field → **Default Properties → Number Format → Currency (Custom)**, display units **Millions (M)**, 1 decimal.

---

## 1. Calculated fields (15 min)

Create each one via **Analysis → Create Calculated Field**. Copy the formulas exactly.

| Name | Formula | Notes |
|---|---|---|
| **Total Clients** | `COUNT([client_key])` | **Don't** use `COUNTD([client_id])`. Client IDs are reused (it would show 2,940 instead of 3,000). |
| **Total Loans** | `SUM([total_loan])` | Bank Loans + Business Lending + Credit Card Balance |
| **Total Deposits** | `SUM([total_deposit])` | Bank Deposits + Savings + Checking + Foreign Currency |
| **Loan-to-Deposit Ratio** | `SUM([total_loan]) / SUM([total_deposit])` | Format as number, 2 decimals |
| **Funding Gap** | `SUM([total_loan]) - SUM([total_deposit])` | |
| **Est. Fee Revenue** | `SUM([est_fee_revenue])` | |
| **Avg Tenure (yrs)** | `AVG([tenure_years])` | 1 decimal |
| **% Loan > 6x Income** | `AVG(IF [loan_to_income] > 6 THEN 1 ELSE 0 END)` | Format as percentage |
| **Underrated Risk Clients** | `SUM(IF [underrated_risk_flag] THEN 1 ELSE 0 END)` | If the field came in as a string, use `[underrated_risk_flag] = "True"` |
| **Underrated Risk Loans** | `SUM(IF [underrated_risk_flag] THEN [bank_loans] ELSE 0 END)` | |
| **% of Loan Book** | `SUM([total_loan]) / TOTAL(SUM([total_loan]))` | Table calculation. Set *Compute using* to the table |
| **Risk Band** | `IF [risk_weighting] <= 2 THEN "Low (1-2)" ELSEIF [risk_weighting] = 3 THEN "Medium (3)" ELSE "High (4-5)" END` | |

**Parameter (for interactivity):** create a parameter **Select Metric** (String) with the values `Total Loans` and `Total Deposits`. Then create:

```
// Selected Metric
CASE [Select Metric]
WHEN "Total Loans" THEN SUM([total_loan])
WHEN "Total Deposits" THEN SUM([total_deposit])
END
```

Right-click the parameter → **Show Parameter** on the dashboard so viewers can switch between the two.

---

## 2. Worksheets (60–90 min)

Name each sheet exactly as below. *Cols* means the Columns shelf, *Rows* the Rows shelf.

### KPI cards (5 small sheets)
For each sheet, drag a single measure onto **Text** on the Marks card. Use mark type **Text**, font 20–24 bold, and put the title inside the text box.
- `KPI Clients` → Total Clients
- `KPI Loans` → Total Loans (Millions)
- `KPI Deposits` → Total Deposits (Millions)
- `KPI LDR` → Loan-to-Deposit Ratio
- `KPI Fee` → Est. Fee Revenue (Millions)

### Page 1: Overview
1. **Loans vs Deposits by Relationship.** Cols: `banking_relationship`. Rows: Measure Values, filtered to Total Loans and Total Deposits. Colour: Measure Names. This gives a side-by-side bar. Sort descending.
2. **Selected Metric by Nationality.** Rows: `nationality`. Cols: Selected Metric. Bar, sorted descending, with labels on.
3. **Client Acquisition Trend.** Cols: `joined_bank` (YEAR, continuous). Rows: Total Clients. Line with markers. Annotate the 2019–2020 spike. Note: there are no clients for 1997–1998, a gap in the data.
4. **Loan Book Mix.** Use Measure Names and Measure Values with `SUM(bank_loans)`, `SUM(business_lending)` and `SUM(credit_card_balance)`. Pie or donut (two pies on a dual axis with a white inner circle), or a simple bar.
5. **Clients by Age Group & Gender.** Cols: `age_group`. Rows: Total Clients. Colour: `gender`. Side-by-side or stacked bar.

### Page 2: Loan & Risk Analysis
6. **Risk Weighting vs Affordability** (the key insight chart). Cols: `risk_weighting` (discrete). Rows: `% Loan > 6x Income` (bar) and `AVG(estimated_income)` (line) on a **dual axis** → right-click the second axis → **Synchronize** off, mark types Bar + Line. Title: *"Low-risk ratings hide the most leveraged clients."*
7. **Underrated Risk by Relationship.** Rows: `banking_relationship`. Cols: Underrated Risk Clients. Bar with labels.
8. **Advisor Review Priority.** Rows: `investment_advisor`. Cols: Underrated Risk Clients. Sort descending; keep the top 10 (Filter → Top → By field → Top 10).
9. **Leverage by Income Band.** Cols: `income_band` (sort Low, Mid, High manually). Rows: `MEDIAN(loan_to_income)`. Bar.
10. **Top 10 Exposures.** Rows: `client_id`, `name`, `banking_relationship`, `risk_weighting`. Text: Total Loans. Filter `client_key` to the Top 10 by SUM(total_loan). This is a table.

### Page 3: Customer Segments & Loyalty
11. **Segment Scatter.** Cols: `total_deposit` (dimension `client_key` on Detail so you get one dot per client). Rows: `total_loan`. Colour: `relationship_segment`. Add reference lines at the **median** on both axes (Analytics pane → Reference Line → Median).
12. **Segment Summary.** Rows: `relationship_segment`. Columns: Total Clients, Total Loans, Total Deposits. Use Measure Names and Measure Values as a text table, or a highlight table.
13. **Loyalty vs Value.** Cols: `loyalty_classification` (sort Jade, Silver, Gold, Platinum). Rows: `MEDIAN(total_deposit)`. Bar. Title: *"Loyalty tiers don't reflect deposit value."*
14. **Fee Structure Revenue.** Rows: `fee_structure`. Cols: Est. Fee Revenue. Label with `% of total` (Quick Table Calculation → Percent of Total).
15. **Tenure Band Mix.** Cols: `tenure_band`. Rows: Total Clients. Colour: `loyalty_classification`.

---

## 3. Dashboards (30–45 min)

General settings: **Size → Fixed, 1366 × 900** (or *Automatic* for web). Use a light background, one accent colour (teal, `#1f6f8b`) and red (`#e76f51`) only for risk.

**Dashboard 1: Executive Overview**
- Top row: a title text box, "Banking Risk & Customer Analytics | 3,000 clients | snapshot 31-Dec-2021", then the 5 KPI cards in a horizontal container.
- Middle: sheet 1 (relationship) on the left, sheet 2 (nationality, with the parameter control) on the right.
- Bottom: sheet 3 (acquisition trend) on the left, sheets 4 and 5 on the right.
- **Filters:** `gender`, `nationality`, `income_band`, `banking_relationship`. On each filter → **Apply to Worksheets → All Using This Data Source**.

**Dashboard 2: Loan & Risk**
- Top: the KPI cards for Loans and LDR, plus a text card: "595 clients (19.8%) rated low-risk but with loans > 6× income: $448M of bank loans."
- Sheets 6 (wide), then 7, 9 and 8, then 10 (table) at the bottom.
- **Action:** Dashboard → Actions → Add Action → **Filter**. Source: sheet 7 (relationship). Target: sheets 8 and 10. Run on **Select**. Clicking a relationship then filters the advisor and top-exposure lists.

**Dashboard 3: Segments & Loyalty**
- Sheet 11 (scatter, large) with sheet 12 next to it. Below: sheets 13, 14 and 15.
- **Highlight action** on `relationship_segment`, so hovering over a segment highlights it everywhere.

**Navigation:** add **Navigation buttons** (Objects → Navigation) on each dashboard to move between the 3 pages. Or combine them into a **Story** (Story → New Story), with one story point per dashboard and a one-line insight caption on each.

---

## 4. Tooltips and polish (15 min)

- Edit tooltips into plain sentences, for example: `<banking_relationship>: <Total Clients> clients, <Total Loans> in loans (<% of Loan Book> of the book)`.
- Hide sheet titles that duplicate the chart's purpose; keep the insight-style titles on the key charts.
- Show the data-quality note in small text on Dashboard 1: *"Client ID is reused by 59 pairs of different clients; counts use a surrogate key."*

---

## 5. Publish and share (5 min)

- **Web authoring:** File → **Save**. The workbook appears on your Tableau Public profile.
- **Desktop Public Edition:** File → **Save to Tableau Public As…**. Also **File → Export Packaged Workbook** → `Banking_Risk_Dashboard.twbx`, and commit it to `tableau/` in the repo.
- Open the workbook on your profile → **Share** → copy the link. Paste it into the README ("Live dashboard" badge), your resume and LinkedIn Featured.
- Take 3 screenshots (one per dashboard) → save them as `images/dashboard_1_overview.png` and so on, and record a 20–30 s GIF clicking through the filters (ScreenToGif on Windows is free).
