# Insurance Analytics: Weekly Branch Dashboard

A branch performance dashboard for an insurance brokerage, built from the same six datasets in **Excel**, **Tableau** and **MySQL** (Power BI to follow). Every version produces the same numbers, which makes it a useful comparison of how each tool handles data cleaning, modelling and reporting.

## Contents

- [Project background](#project-background)
- [The data](#the-data)
- [KPIs and definitions](#kpis-and-definitions)
- [Data quality issues and how I handled them](#data-quality-issues-and-how-i-handled-them)
- [Excel version](#excel-version)
- [Tableau version](#tableau-version)
- [MySQL version](#mysql-version)
- [Results](#results)
- [Key findings](#key-findings)
- [Limitations and assumptions](#limitations-and-assumptions)
- [Challenges and what I learned](#challenges-and-what-i-learned)
- [Repository structure](#repository-structure)
- [Author](#author)

## Project background

An insurance brokerage's corporate team reviews New, Cross Sell and Renewal business with each branch head. This dashboard supports that weekly conversation. It shows, for the branch and for each individual account executive:

- how much income was **placed** and **invoiced** against the annual **target**,
- how many **meetings** were held,
- the state of the **opportunity pipeline** (open opportunities, revenue by stage, top opportunities, product mix).

The task was to build this dashboard from the supplied data sets, using each tool independently, starting from a reference dashboard layout.

## The data

Six files from the brokerage's systems (Ahmedabad branch), used as supplied:

| File | Rows | What it holds |
|---|---|---|
| Individual_Budgets | 10 | Annual New, Cross Sell and Renewal targets per employee |
| brokerage | 961 | Brokerage income placed, with income class (New, Cross Sell, Renewal) |
| fees | 9 | Fee income placed |
| invoice | 204 | Invoiced income, with income class |
| meeting | 34 | Client meetings by account executive and date |
| Opportunity | 49 | Sales pipeline: stage, revenue, product group |

> The raw data files are not included in this repository.

## KPIs and definitions

| KPI | Definition |
|---|---|
| Target | Budget by employee, split into New, Cross Sell and Renewal |
| Placed achievement | Brokerage amount + Fees amount, by income class |
| Invoiced achievement | Invoice amount, by income class |
| Achievement % | Placed (or Invoiced) divided by Target |
| Meetings | Count of meetings, by year and by account executive |
| Open opportunity | Stage is Qualify Opportunity or Propose Solution |
| Conversion ratio | Closed Won divided by total opportunities |
| Top 4 | Top four opportunities by revenue, for all stages and for open ones |

Dashboard components: target vs placed vs invoiced for each income class, six achievement % cards, yearly meetings, meetings by executive, invoices by executive and income class, opportunity totals, top opportunities, stage funnel by revenue, and product distribution.

## Data quality issues and how I handled them

| Issue | Handling |
|---|---|
| Executive column called `Exe Name` in brokerage and `Account Executive` elsewhere | Standardised to one name |
| Extra spaces in text fields | Trimmed |
| 28 invoice rows and 1 brokerage row with no income class | Labelled `Null` and kept, so no income is dropped |
| `Vididt Saha` in brokerage vs `Vidit Shah` in the budget file | Treated as the same person and corrected |
| 141 invoice rows with no Account Exe ID | Joined people by name instead of ID |
| Budget stored as three columns | Reshaped to one row per employee per income class |
| Brokerage and Fees are two sources of placed income | Combined into one Placed table (970 rows) |
| 14 brokerage rows with no amount | Kept; they contribute nothing to totals |

## Excel version

**Approach: Power Query, Data Model, DAX and PivotTables**

1. **Clean in Power Query.** Loaded each file, trimmed text, replaced blank income classes, fixed the name typo, unpivoted the budget, appended brokerage and fees into one `Placed` table, and added an `Is Open` flag and a `Year` column.
2. **Model the data.** Built a star schema with several fact tables sharing two dimension tables (a galaxy schema):
   - Dimensions: `DimEmployee` (19 people) and `DimIncomeClass`.
   - Facts: Budget, Placed, Invoice, Meeting, Opportunity.
   - Eight one-to-many relationships, single-direction filters.
3. **Write DAX measures:** Total Target, Placed Achieved, Invoiced, Placed %, Invoice %, Meetings, Invoice Count, Total Opportunities, Open Opportunities, Open Revenue, Opportunity Revenue, Closed Won, Conversion Ratio.
4. **Build PivotTables and PivotCharts** for each dashboard component.
5. **Make it interactive** with slicers (Employee and Year) connected to every pivot, and achievement cards driven by `GETPIVOTDATA` with green and red arrows.

![Excel dashboard](Excel/screenshots/dashboard.png)

## Tableau version

**Approach: relationships, relationship calculations and calculated fields**

1. **Connected the files** and cleaned them inside the data source: pivoted the budget columns into rows and unioned brokerage and fees (using a wildcard union).
2. **Built the data model with relationships.** Tableau does not allow calculated fields as relationship keys, so keys are *relationship calculations* (for example `TRIM`, `IFNULL`, and a mapping of budget column names to income classes).
3. **Linked Placed and Invoice to Budget on income class only.** Many people have income but no budget row, and linking on employee as well would have dropped their amounts from the class totals.
4. **Created calculated fields:** Total Target, Placed Achieved, Invoiced, Placed %, Invoice %, arrow and status fields for the cards, Open Opportunities, Open Revenue, Closed Won, Conversion Ratio.
5. **Built a worksheet for each component,** including the stage funnel (Gantt bars with a negative offset) and the product mix, then assembled them into one dashboard.

![Tableau dashboard](Tableau/screenshots/dashboard.png)

## MySQL version

**Approach: raw tables, clean views, KPI queries**

1. **Imported** the six files unchanged with MySQL Workbench's Table Data Import Wizard.
2. **Cleaned in views,** leaving the imported tables untouched:
   `v_budget`, `v_placed`, `v_invoice`, `v_meeting`, `v_opportunity`, `v_employee`.
3. **Wrote the KPI queries.** Each table is totalled separately and then lined up by income class, so the figures are never double-counted.
4. **Added an employee scorecard** (one row per person across all KPIs) and a stored procedure, `sp_kpi_by_class`, that filters the class-level KPIs by employee.

The full script, with the expected result of each query in comments, is in [`MySQL/insurance_analytics.sql`](MySQL/insurance_analytics.sql).

```sql
CALL sp_kpi_by_class(NULL);      -- whole branch
CALL sp_kpi_by_class('Vinay');   -- one employee
```

![MySQL results](MySQL/screenshots/02_kpi_by_income_class.png)

## Results

All three versions agree on every figure. Whole-branch results:

| Income class | Target | Placed | Invoiced | Placed % | Invoiced % |
|---|---|---|---|---|---|
| Cross Sell | 20,083,111 | 13,041,253 | 2,853,842 | 64.94% | 14.21% |
| New | 19,673,793 | 3,531,629 | 569,815 | 17.95% | 2.90% |
| Renewal | 12,319,455 | 18,507,271 | 8,244,310 | 150.23% | 66.92% |
| Unclassified (Null) | none | 1,559 | 594,739 | n/a | n/a |
| **Total** | **52,076,359** | **35,081,712** | **12,262,706** | **67.37%** | **23.55%** |

Other checkpoints used to validate each tool:

- 204 invoices, 49 opportunities (44 open), 34 meetings (3 in 2019 and 31 in 2020).
- Opportunity revenue by stage: Qualify Opportunity 5,919,500, Propose Solution 60,000, Negotiate 899,000.
- Product mix: Employee Benefits 15, Fire 13, Marine 7, Engineering 6, Liability 5, Miscellaneous 2, Terrorism 1.

## Key findings

- **Renewal is the only class above target,** at about 150% placed. **New is the weakest,** at 18% placed and under 3% invoiced.
- **Placed income is far ahead of invoiced income** in every class (67% of total target placed, 24% invoiced), which suggests a gap between income booked and income billed that the branch heads should discuss.
- **The pipeline is early stage.** 44 of 49 opportunities are open, and the Qualify stage holds about 86% of the pipeline's revenue.
- **Meeting activity rose sharply,** from 3 meetings in 2019 to 31 in 2020.
- **Invoice volume is concentrated.** One executive accounts for 63 of the 204 invoices (about 31%).

## Limitations and assumptions

- Only 10 employees have targets, but income is recorded against more people, so the whole-branch view can exceed target and individual achievement % only exists for people with a budget.
- The opportunity data has no "Won" stage, so Closed Won and the conversion ratio are 0.
- Four open opportunities tie at 300,000 for fourth place in the Top 4. The Excel and MySQL versions show the same one; Tableau may show another.
- "Vididt Saha" and "Vidit Shah" are assumed to be the same person.
- Invoice rows are counted as rows (204 rows, 198 distinct invoice numbers).
- Some brokerage due dates are far in the future (up to 2108) and are not used in the dashboard.
- Current year is taken as 2020, the latest year in the meeting data.

## Challenges and what I learned

- **Hidden characters in CSV files.** Saving from Excel as CSV UTF-8 added an invisible marker to the first column name of every table in MySQL. Renaming those columns fixed it.
- **Silently dropped rows.** My first brokerage import produced 947 rows instead of 961. Importing amount and date columns as text and checking row counts after every import caught and fixed it.
- **A default value that hid a problem.** In Tableau, a calculated field ending in `ELSE "New"` relabelled the 28 unclassified invoices and 1 brokerage row as New and inflated the New totals. Giving each class its own explicit test fixed it, and comparing against the other tools exposed it.
- **Join design matters.** Linking on employee as well as income class silently drops people with no budget. Totalling each table separately and linking only on the shared key keeps every amount.
- **Validate across tools.** Agreeing totals across Excel, Tableau and MySQL gave much more confidence than checking any one of them alone.

## Repository structure

```
Insurance-Analytics/
├── Excel/
│   ├── (workbook)
│   └── screenshots/
├── Tableau/
│   ├── (workbook)
│   └── screenshots/
├── MySQL/
│   ├── insurance_analytics.sql
│   └── screenshots/
├── PowerBI/            (coming soon)
└── README.md
```

## Author

**Satish Palani**
