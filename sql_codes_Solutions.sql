-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region

SELECT Distinct(market)
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';


-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg

WITH table1 AS (
		SELECT COUNT(DISTINCT product_code) AS Unique_product_2020
        FROM fact_sales_monthly
        WHERE fiscal_year = 2020
	),
	table2 AS(
	SELECT COUNT(DISTINCT product_code) AS Unique_product_2021
	FROM fact_sales_monthly
	WHERE fiscal_year = 2021
)
SELECT Unique_product_2020, Unique_product_2021,	
ROUND(((Unique_product_2021 - Unique_product_2020) / Unique_product_2020) * 100,2) AS percentage_change
FROM table1
CROSS JOIN table2;


-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. The final output contains 2 fields, segment product_count

SELECT segment, COUNT(DISTINCT product) as product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, segment product_count_2020 product_count_2021 difference
WITH table1 AS (
    SELECT segment, COUNT(DISTINCT product) as product_count_2020
    FROM dim_product as p
    JOIN fact_sales_monthly as s ON p.product_code = s.product_code
    WHERE fiscal_year = 2020
    GROUP BY segment
),
table2 AS (
    SELECT segment, COUNT(DISTINCT product) as product_count_2021
    FROM dim_product as p
    JOIN fact_sales_monthly as s ON p.product_code = s.product_code
    WHERE fiscal_year = 2021
    GROUP BY segment
)
SELECT table1.segment, product_count_2020, product_count_2021, product_count_2021 - product_count_2020 as difference
FROM table1
JOIN table2 ON table1.segment = table2.segment
ORDER BY product_count_2021 DESC;



-- 5. Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, product_code product manufacturing_cost

SELECT 
    p.product_code, 
    p.product, 
    mc.manufacturing_cost as MIN_and_MAX_manufacturing_cost
FROM dim_product AS p
JOIN fact_manufacturing_cost AS mc ON p.product_code = mc.product_code
WHERE mc.manufacturing_cost = (
    SELECT MAX(manufacturing_cost)
    FROM fact_manufacturing_cost
)
OR mc.manufacturing_cost = (
    SELECT MIN(manufacturing_cost)
    FROM fact_manufacturing_cost
);


-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. The final output contains these fields, customer_code customer average_discount_percentage

SELECT c.customer_code, c.customer, 
ROUND(AVG(pre_invoice_discount_pct)*100,2) as average_discount_percentage
FROM fact_pre_invoice_deductions as inv
JOIN dim_customer as c ON inv.customer_code = c.customer_code
WHERE market = 'India' AND fiscal_year = 2021
GROUP BY c.customer, c.customer_code
ORDER by average_discount_percentage DESC
LIMIT 5;


-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and high-performing months and take strategic decisions. The final report contains these columns: Month Year Gross sales Amount

SELECT monthname(s.date) as months, year(s.date) as years, 
ROUND(SUM(s.sold_quantity*g.gross_price),2) as Gross_sales_amount 
FROM fact_gross_price as g
JOIN fact_sales_monthly as s ON g.product_code = s.product_code
JOIN dim_customer as c ON s.customer_code = c.customer_code
WHERE c.customer = "Atliq Exclusive"
GROUP BY months,years;


-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity

SELECT 
CASE
    WHEN date BETWEEN '2019-09-01' AND '2019-11-01' then 1  
    WHEN date BETWEEN '2019-12-01' AND '2020-02-01' then 2
    WHEN date BETWEEN '2020-03-01' AND '2020-05-01' then 3
    WHEN date BETWEEN '2020-06-01' AND '2020-08-01' then 4
    END AS Quarters,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarters
ORDER BY total_sold_quantity DESC;


-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and also find the percentage of contribution? The final output contains these fields- channel, gross_sales_mln and percentage.

WITH GrossSalesByChannel AS (
  SELECT
    c.channel,
    SUM(g.gross_price * s.sold_quantity) AS gross_sales_mln
  FROM
    dim_customer AS c
    JOIN fact_sales_monthly AS s ON c.customer_code = s.customer_code
    JOIN fact_gross_price AS g ON s.product_code = g.product_code
  WHERE
    YEAR(s.date) = 2021
  GROUP BY
    c.channel
)
, TotalGrossSales AS (
  SELECT SUM(gross_sales_mln) AS total_gross_sales_mln
  FROM GrossSalesByChannel
)
SELECT
  G.channel,
  ROUND(G.gross_sales_mln, 2) AS gross_sales_mln,
  ROUND((G.gross_sales_mln / T.total_gross_sales_mln) * 100, 2) AS percentage
FROM GrossSalesByChannel AS G
CROSS JOIN TotalGrossSales AS T
ORDER BY G.gross_sales_mln DESC;


-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields, division, product_code, product, total_sold_quantity, rank_order

WITH ProductRanks AS (
  SELECT
    p.division,
    p.product_code,
    p.product,
    SUM(s.sold_quantity * g.gross_price) AS total_gross_sales,
    RANK() OVER (PARTITION BY p.division ORDER BY SUM(s.sold_quantity * g.gross_price) DESC) AS rank_order
  FROM
    dim_product AS p
    JOIN fact_sales_monthly AS s ON p.product_code = s.product_code
    JOIN fact_gross_price AS g ON p.product_code = g.product_code
  WHERE
    YEAR(s.date) = 2021
  GROUP BY
    p.division, p.product_code, p.product
)
SELECT
  division,
  product_code,
  product,
  total_gross_sales,
  rank_order
FROM ProductRanks
WHERE rank_order <= 3;
 


