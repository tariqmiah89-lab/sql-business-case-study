-- Revenue per order line = quantity * unit_price * (1 - discount_rate)

-- Q1: Headline KPIs: revenue, orders, customers, average order value
SELECT ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate)),0) AS revenue,
       COUNT(DISTINCT o.order_id) AS orders,
       COUNT(DISTINCT o.customer_id) AS active_customers,
       ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate))/COUNT(DISTINCT o.order_id),2) AS avg_order_value
FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id);

-- Q2: Monthly revenue trend
SELECT substr(o.order_date,1,7) AS month,
       ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate)),0) AS revenue
FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id)
GROUP BY month ORDER BY month;

-- Q3: Month-over-month growth using LAG()
WITH m AS (
  SELECT substr(o.order_date,1,7) AS month, SUM(oi.quantity*p.unit_price*(1-o.discount_rate)) AS revenue
  FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id) GROUP BY month)
SELECT month, ROUND(revenue,0) AS revenue,
       ROUND(100.0*(revenue - LAG(revenue) OVER (ORDER BY month))/LAG(revenue) OVER (ORDER BY month),1) AS mom_growth_pct
FROM m ORDER BY month;

-- Q4: Running (cumulative) revenue with a window function
WITH m AS (
  SELECT substr(o.order_date,1,7) AS month, SUM(oi.quantity*p.unit_price*(1-o.discount_rate)) AS revenue
  FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id) GROUP BY month)
SELECT month, ROUND(SUM(revenue) OVER (ORDER BY month),0) AS cumulative_revenue FROM m ORDER BY month;

-- Q5: Revenue and share of total by category
WITH c AS (
  SELECT p.category, SUM(oi.quantity*p.unit_price*(1-o.discount_rate)) AS revenue
  FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id) GROUP BY p.category)
SELECT category, ROUND(revenue,0) AS revenue,
       ROUND(100.0*revenue/SUM(revenue) OVER (),1) AS pct_of_total
FROM c ORDER BY revenue DESC;

-- Q6: Top 10 products by revenue
SELECT p.product_name, p.category,
       SUM(oi.quantity) AS units, ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate)),0) AS revenue
FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id)
GROUP BY p.product_id ORDER BY revenue DESC LIMIT 10;

-- Q7: Best product in each category using RANK()
WITH r AS (
  SELECT p.category, p.product_name, SUM(oi.quantity*p.unit_price*(1-o.discount_rate)) AS revenue,
         RANK() OVER (PARTITION BY p.category ORDER BY SUM(oi.quantity*p.unit_price*(1-o.discount_rate)) DESC) AS rnk
  FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id)
  GROUP BY p.product_id)
SELECT category, product_name, ROUND(revenue,0) AS revenue FROM r WHERE rnk = 1 ORDER BY revenue DESC;

-- Q8: Revenue and average order value by region
SELECT c.region, COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate)),0) AS revenue,
       ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate))/COUNT(DISTINCT o.order_id),2) AS avg_order_value
FROM customers c JOIN orders o USING(customer_id) JOIN order_items oi USING(order_id) JOIN products p USING(product_id)
GROUP BY c.region ORDER BY revenue DESC;

-- Q9: Acquisition channel performance (customers, revenue per customer)
SELECT c.channel, COUNT(DISTINCT c.customer_id) AS customers,
       ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate)),0) AS revenue,
       ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate))/COUNT(DISTINCT c.customer_id),2) AS revenue_per_customer
FROM customers c JOIN orders o USING(customer_id) JOIN order_items oi USING(order_id) JOIN products p USING(product_id)
GROUP BY c.channel ORDER BY revenue_per_customer DESC;

-- Q10: Top 10 customers by lifetime value
SELECT o.customer_id, c.region, COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate)),0) AS lifetime_value
FROM orders o JOIN customers c USING(customer_id) JOIN order_items oi USING(order_id) JOIN products p USING(product_id)
GROUP BY o.customer_id ORDER BY lifetime_value DESC LIMIT 10;

-- Q11: Repeat vs one-time customers
WITH n AS (SELECT customer_id, COUNT(*) AS orders FROM orders GROUP BY customer_id)
SELECT CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
       COUNT(*) AS customers, ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1) AS pct
FROM n GROUP BY customer_type;

-- Q12: Average days between orders per customer (LAG), summarised
WITH g AS (
  SELECT customer_id, julianday(order_date) - julianday(LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date)) AS gap
  FROM orders)
SELECT ROUND(AVG(gap),1) AS avg_days_between_orders, COUNT(gap) AS repeat_orders FROM g WHERE gap IS NOT NULL;

-- Q13: Cohort retention: share of each signup-quarter cohort that ordered again in 90+ days
WITH first_o AS (SELECT customer_id, MIN(order_date) AS first_date FROM orders GROUP BY customer_id),
cohort AS (
  SELECT c.customer_id,
         substr(c.signup_date,1,4) || '-Q' || ((CAST(substr(c.signup_date,6,2) AS INTEGER)+2)/3) AS signup_quarter
  FROM customers c),
again AS (
  SELECT DISTINCT o.customer_id FROM orders o JOIN first_o f USING(customer_id)
  WHERE julianday(o.order_date) - julianday(f.first_date) >= 90)
SELECT signup_quarter, COUNT(*) AS customers,
       ROUND(100.0*SUM(CASE WHEN a.customer_id IS NOT NULL THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_reordered_90d_plus
FROM cohort co LEFT JOIN again a USING(customer_id)
GROUP BY signup_quarter ORDER BY signup_quarter;

-- Q14: RFM segmentation with NTILE (as of 2025-12-31)
WITH rfm AS (
  SELECT o.customer_id,
         julianday('2025-12-31') - julianday(MAX(o.order_date)) AS recency_days,
         COUNT(DISTINCT o.order_id) AS frequency,
         SUM(oi.quantity*p.unit_price*(1-o.discount_rate)) AS monetary
  FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id) GROUP BY o.customer_id),
scored AS (
  SELECT *, NTILE(4) OVER (ORDER BY recency_days DESC) AS r,
            NTILE(4) OVER (ORDER BY frequency) AS f,
            NTILE(4) OVER (ORDER BY monetary) AS m FROM rfm)
SELECT CASE WHEN r>=3 AND f>=3 AND m>=3 THEN 'Champions'
            WHEN r>=3 AND f<=2 THEN 'New / Promising'
            WHEN r<=2 AND f>=3 AND m>=3 THEN 'At risk (high value)'
            WHEN r<=2 THEN 'Lapsed'
            ELSE 'Core' END AS segment,
       COUNT(*) AS customers, ROUND(AVG(monetary),0) AS avg_spend, ROUND(SUM(monetary),0) AS total_revenue
FROM scored GROUP BY segment ORDER BY total_revenue DESC;

-- Q15: Does discounting pay off? Order size and revenue by discount band
SELECT o.discount_rate, COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.quantity*p.unit_price*(1-o.discount_rate))/COUNT(DISTINCT o.order_id),2) AS avg_order_value,
       ROUND(SUM(oi.quantity*p.unit_price*o.discount_rate),0) AS discount_given
FROM orders o JOIN order_items oi USING(order_id) JOIN products p USING(product_id)
GROUP BY o.discount_rate ORDER BY o.discount_rate;
