# SQL Business Case Study: E-commerce Performance

Answering 15 business questions about a UK online retailer using **SQL** (CTEs, joins, window functions, cohort and RFM analysis).

> **Data note:** the dataset is **synthetic** (2,500 customers, 42 products, 8,826 orders, Jan 2024 – Dec 2025), generated with a fixed random seed by `build_data.py` so every result is reproducible. It is built to behave like real retail data, but the figures are illustrative, not from a real company.

## Business questions
| # | Question | SQL techniques |
|---|---|---|
| 1 | What are our headline KPIs? | Joins, aggregation |
| 2–4 | How is revenue trending, growing and accumulating? | `GROUP BY`, `LAG()`, running `SUM() OVER` |
| 5–7 | Which categories and products drive revenue? | CTEs, `RANK() OVER (PARTITION BY ...)` |
| 8–9 | Which regions and acquisition channels perform best? | Multi-table joins |
| 10–12 | Who are our best customers, and how often do they return? | `LAG()`, conditional aggregation |
| 13 | Do customers come back after signing up? (cohorts) | CTEs, `LEFT JOIN`, date maths |
| 14 | Which customers are Champions vs at risk? (RFM) | `NTILE()`, `CASE` |
| 15 | Do discounts increase basket size? | Grouped comparison |

## Key findings
- **Revenue:** £3.88m from 8,826 orders and 2,409 customers; average order value **£439**. Monthly revenue grew from about £6k (Jan 2024) to about £317k (Dec 2025), driven mainly by the growing customer base.
- **Concentration risk:** **Electronics is 48% of revenue**, and 5 of the top 6 products are Electronics. A supply or pricing problem in one category would hit the business hard.
- **Regions:** London is the largest market (30% of revenue), but **Scotland has the highest average order value (£463)**, so it may be worth targeting with premium bundles.
- **Channels:** revenue per customer is similar across channels (£1,581 to £1,647). Referral is highest, but the gap to Paid Search is only about 4%, which is too small to act on without a proper test.
- **Loyalty:** 82% of customers have ordered more than once, with about 86 days between orders on average.
- **RFM segments:** **Champions (591 customers) generate 42% of revenue.** The **"At risk (high value)" group (419 customers) accounts for another 29% (£1.11m)** and is the obvious win-back priority.
- **Discounts:** average order value falls from £453 (no discount) to £351 (20% off), and £130k was given away in total. In this data discounting does not lift basket size, so blanket discounts mostly give away margin.
- **Limitation (Q13):** recent signup cohorts show low 90-day reorder rates (e.g. 12% for 2025-Q3) only because they haven't had 90 days yet. Always check that a cohort has had enough time before reading retention numbers.

## Recommendations
1. Launch a win-back campaign for the high-value at-risk segment.
2. Reduce reliance on Electronics by promoting Fashion and Fitness bundles.
3. Replace blanket discounts with targeted offers, and test them with an A/B experiment.

## How to run
```bash
pip install pandas numpy tabulate
python build_data.py      # creates data/*.csv and data/shop.db (SQLite)
python run_queries.py     # runs sql/queries.sql and writes sql/results.md
```
Or open `data/shop.db` in any SQLite viewer (e.g. DB Browser for SQLite) and paste the queries from `sql/queries.sql`.

## Files
- `sql/schema.sql`: table definitions
- `sql/queries.sql`: all 15 queries, commented
- `sql/results.md`: output of every query
- `data/`: CSVs and the SQLite database
