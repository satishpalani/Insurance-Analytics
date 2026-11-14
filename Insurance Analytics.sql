CREATE DATABASE insurance_analytics;
USE insurance_analytics;

RENAME TABLE `individual budgets` TO individual_budgets;

SELECT 'individual_budgets' AS tbl, COUNT(*) AS n FROM individual_budgets
UNION ALL SELECT 'brokerage', COUNT(*) FROM brokerage
UNION ALL SELECT 'fees', COUNT(*) FROM fees
UNION ALL SELECT 'invoice', COUNT(*) FROM invoice
UNION ALL SELECT 'meeting', COUNT(*) FROM meeting
UNION ALL SELECT 'opportunity', COUNT(*) FROM opportunity;

SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'insurance_analytics'
ORDER BY table_name, ordinal_position;

SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'insurance_analytics' AND ordinal_position = 1;

SELECT 'invoice_date' AS col, COUNT(*) AS total,
       SUM(NULLIF(TRIM(invoice_date),'') IS NOT NULL AND STR_TO_DATE(TRIM(invoice_date),'%d-%m-%Y') IS NULL) AS unparsed
FROM invoice
UNION ALL SELECT 'meeting_date', COUNT(*),
       SUM(NULLIF(TRIM(meeting_date),'') IS NOT NULL AND STR_TO_DATE(TRIM(meeting_date),'%d-%m-%Y') IS NULL)
FROM meeting
UNION ALL SELECT 'closing_date', COUNT(*),
       SUM(NULLIF(TRIM(closing_date),'') IS NOT NULL AND STR_TO_DATE(TRIM(closing_date),'%d-%m-%Y') IS NULL)
FROM opportunity
UNION ALL SELECT 'brokerage income_due_date', COUNT(*),
       SUM(NULLIF(TRIM(income_due_date),'') IS NOT NULL AND STR_TO_DATE(TRIM(income_due_date),'%d-%m-%Y') IS NULL)
FROM brokerage;

SELECT invoice_date, Amount FROM invoice LIMIT 3;
SELECT meeting_date FROM meeting LIMIT 3;
SELECT COUNT(*) AS brokerage_with_comma FROM brokerage WHERE Amount LIKE '%,%';


-- Budget reshaped to one row per employee per income class (like Unpivot)
CREATE OR REPLACE VIEW v_budget AS
SELECT TRIM(`Employee Name`) AS employee, 'New' AS income_class, `New Budget` AS target
FROM individual_budgets
UNION ALL
SELECT TRIM(`Employee Name`), 'Cross Sell', `Cross sell bugdet` FROM individual_budgets
UNION ALL
SELECT TRIM(`Employee Name`), 'Renewal', `Renewal Budget` FROM individual_budgets;

-- Brokerage + Fees combined, names trimmed, typo fixed, blank class labelled Null
CREATE OR REPLACE VIEW v_placed AS
SELECT CASE WHEN TRIM(`Exe Name`) = 'Vididt Saha' THEN 'Vidit Shah' ELSE TRIM(`Exe Name`) END AS employee,
       COALESCE(NULLIF(TRIM(income_class),''),'Null') AS income_class,
       CAST(NULLIF(TRIM(Amount),'') AS DECIMAL(15,2)) AS amount,
       'Brokerage' AS source
FROM brokerage
UNION ALL
SELECT TRIM(`Account Executive`),
       COALESCE(NULLIF(TRIM(income_class),''),'Null'),
       CAST(Amount AS DECIMAL(15,2)),
       'Fees'
FROM fees;

CREATE OR REPLACE VIEW v_invoice AS
SELECT invoice_number,
       STR_TO_DATE(TRIM(invoice_date),'%d-%m-%Y') AS invoice_date,
       TRIM(`Account Executive`) AS employee,
       COALESCE(NULLIF(TRIM(income_class),''),'Null') AS income_class,
       Amount AS amount
FROM invoice;

CREATE OR REPLACE VIEW v_meeting AS
SELECT TRIM(`Account Executive`) AS employee,
       STR_TO_DATE(TRIM(meeting_date),'%d-%m-%Y') AS meeting_date,
       YEAR(STR_TO_DATE(TRIM(meeting_date),'%d-%m-%Y')) AS meeting_year
FROM meeting;

CREATE OR REPLACE VIEW v_opportunity AS
SELECT opportunity_name, opportunity_id,
       TRIM(`Account Executive`) AS employee,
       revenue_amount,
       TRIM(stage) AS stage,
       TRIM(product_group) AS product_group,
       CASE WHEN TRIM(stage) IN ('Qualify Opportunity','Propose Solution') THEN 1 ELSE 0 END AS is_open
FROM opportunity;

-- Employee list built from the data itself (no manual list)
CREATE OR REPLACE VIEW v_employee AS
SELECT employee FROM v_budget
UNION SELECT employee FROM v_placed
UNION SELECT employee FROM v_invoice
UNION SELECT employee FROM v_meeting
UNION SELECT employee FROM v_opportunity;

-- Check the views
SELECT 'v_budget' AS view_name, COUNT(*) AS n FROM v_budget
UNION ALL SELECT 'v_placed', COUNT(*) FROM v_placed
UNION ALL SELECT 'v_invoice', COUNT(*) FROM v_invoice
UNION ALL SELECT 'v_meeting', COUNT(*) FROM v_meeting
UNION ALL SELECT 'v_opportunity', COUNT(*) FROM v_opportunity
UNION ALL SELECT 'v_employee', COUNT(*) FROM v_employee;

-- Target, placed, invoiced and achievement % by income class
SELECT c.income_class,
       t.target,
       p.placed_achieved,
       i.invoiced,
       ROUND(p.placed_achieved / t.target * 100, 2) AS placed_pct,
       ROUND(i.invoiced / t.target * 100, 2)        AS invoice_pct
FROM (SELECT income_class FROM v_budget
      UNION SELECT income_class FROM v_placed
      UNION SELECT income_class FROM v_invoice) c
LEFT JOIN (SELECT income_class, SUM(target) AS target
           FROM v_budget GROUP BY income_class) t ON t.income_class = c.income_class
LEFT JOIN (SELECT income_class, SUM(amount) AS placed_achieved
           FROM v_placed GROUP BY income_class) p ON p.income_class = c.income_class
LEFT JOIN (SELECT income_class, SUM(amount) AS invoiced
           FROM v_invoice GROUP BY income_class) i ON i.income_class = c.income_class
ORDER BY FIELD(c.income_class, 'Cross Sell', 'New', 'Renewal', 'Null');

-- Yearly meeting count
SELECT meeting_year, COUNT(*) AS meetings
FROM v_meeting
GROUP BY meeting_year
ORDER BY meeting_year;


-- Meetings by executive
SELECT employee,
       SUM(meeting_year = 2019) AS meetings_2019,
       SUM(meeting_year = 2020) AS meetings_2020,
       COUNT(*)                 AS total_meetings
FROM v_meeting
GROUP BY employee
GROUP BY employee
ORDER BY total_meetings DESC, employee;

-- Invoices by executive, split by income class
SELECT employee,
       SUM(income_class = 'Cross Sell') AS cross_sell,
       SUM(income_class = 'New')        AS new_biz,
       SUM(income_class = 'Renewal')    AS renewal,
       SUM(income_class = 'Null')       AS null_class,
       COUNT(*)                         AS total
FROM v_invoice
GROUP BY employee
ORDER BY total DESC, employee;


-- Opportunity totals
SELECT COUNT(*) AS total_opportunities,
       SUM(is_open) AS open_opportunities,
       SUM(stage = 'Won') AS closed_won,
       ROUND(SUM(stage = 'Won') / COUNT(*) * 100, 1) AS conversion_pct
FROM v_opportunity;

-- Top 4 by revenue
SELECT opportunity_name, revenue_amount
FROM v_opportunity
ORDER BY revenue_amount DESC, opportunity_name
LIMIT 4;

-- Top 4 open opportunities
SELECT opportunity_name, revenue_amount
FROM v_opportunity
WHERE is_open = 1
ORDER BY revenue_amount DESC, opportunity_name
LIMIT 4;

-- Stage funnel by revenue
SELECT stage, SUM(revenue_amount) AS revenue
FROM v_opportunity
GROUP BY stage
ORDER BY FIELD(stage, 'Qualify Opportunity', 'Propose Solution', 'Negotiate');

-- Product distribution
SELECT product_group, COUNT(*) AS opportunities
FROM v_opportunity
GROUP BY product_group
ORDER BY opportunities DESC;

-- Employee scorecard
SELECT e.employee,
       COALESCE(t.target,0)        AS target,
       COALESCE(p.placed,0)        AS placed,
       COALESCE(i.invoiced,0)      AS invoiced,
       ROUND(p.placed   / t.target * 100, 2) AS placed_pct,
       ROUND(i.invoiced / t.target * 100, 2) AS invoice_pct,
       COALESCE(m.meetings,0)      AS meetings,
       COALESCE(i.invoice_count,0) AS invoices,
       COALESCE(o.opps,0)          AS opportunities,
       COALESCE(o.open_opps,0)     AS open_opps
FROM v_employee e
LEFT JOIN (SELECT employee, SUM(target) AS target FROM v_budget GROUP BY employee) t ON t.employee = e.employee
LEFT JOIN (SELECT employee, SUM(amount) AS placed FROM v_placed GROUP BY employee) p ON p.employee = e.employee
LEFT JOIN (SELECT employee, SUM(amount) AS invoiced, COUNT(*) AS invoice_count FROM v_invoice GROUP BY employee) i ON i.employee = e.employee
LEFT JOIN (SELECT employee, COUNT(*) AS meetings FROM v_meeting GROUP BY employee) m ON m.employee = e.employee
LEFT JOIN (SELECT employee, COUNT(*) AS opps, SUM(is_open) AS open_opps FROM v_opportunity GROUP BY employee) o ON o.employee = e.employee
ORDER BY placed DESC, e.employee;


-- Filter
DELIMITER $$
CREATE PROCEDURE sp_kpi_by_class(IN emp VARCHAR(100))
BEGIN
  SELECT c.income_class, t.target, p.placed_achieved, i.invoiced,
         ROUND(p.placed_achieved / t.target * 100, 2) AS placed_pct,
         ROUND(i.invoiced / t.target * 100, 2)        AS invoice_pct
  FROM (SELECT income_class FROM v_budget
        UNION SELECT income_class FROM v_placed
        UNION SELECT income_class FROM v_invoice) c
  LEFT JOIN (SELECT income_class, SUM(target) AS target FROM v_budget
             WHERE emp IS NULL OR employee = emp GROUP BY income_class) t ON t.income_class = c.income_class
  LEFT JOIN (SELECT income_class, SUM(amount) AS placed_achieved FROM v_placed
             WHERE emp IS NULL OR employee = emp GROUP BY income_class) p ON p.income_class = c.income_class
  LEFT JOIN (SELECT income_class, SUM(amount) AS invoiced FROM v_invoice
             WHERE emp IS NULL OR employee = emp GROUP BY income_class) i ON i.income_class = c.income_class
  ORDER BY FIELD(c.income_class, 'Cross Sell', 'New', 'Renewal', 'Null');
END$$
DELIMITER ;

CALL sp_kpi_by_class(NULL);
