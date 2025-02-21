-- What is the YoY AOV?

WITH AOV_CTE AS (
    SELECT
        YEAR(sale_date) AS sale_year,
        MONTH(sale_date) AS sale_month,
        ROUND(AVG(t.total_amount), 2) AS avg_order_value
    FROM transactions AS t
    GROUP BY
        YEAR(sale_date),
        MONTH(sale_date)
)
SELECT
    sale_year,
    sale_month,
    avg_order_value,
    ROUND(
        ((avg_order_value - LAG(avg_order_value) OVER (ORDER BY sale_year, sale_month)) / LAG(avg_order_value) OVER (ORDER BY sale_year, sale_month)) * 100,
        2
    ) AS percent_change
FROM AOV_CTE
ORDER BY sale_year ASC, sale_month ASC;


-- Total profit generated

SELECT
	SUM(total_amount) - SUM(Price_Per_Unit) AS profit
FROM transactions;


-- What is the grand total revenue generated?

SELECT
	SUM(total_amount) AS total_revenue
FROM transactions;


-- Average number of orders per year

SELECT
	YEAR(sale_date) AS sale_year,
    COUNT(transaction_id) AS order_count,
    AVG(COUNT(transaction_id)) OVER() AS avg_orders
FROM transactions
GROUP BY YEAR(sale_date)
ORDER BY sale_year ASC;


-- What are the total sales, average order value, and order count for each year? Show revenue percent of grand total

SELECT
    YEAR(sale_date) AS sale_year,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER(), 2) AS revenue_percentage,
    ROUND(AVG(total_amount), 2) AS AOV,
    COUNT(transaction_id) AS order_count
FROM transactions
GROUP BY YEAR(sale_date)
ORDER BY total_revenue DESC;


-- How are sales trending YoY?

WITH yearly_revenue AS (
	SELECT
		YEAR(sale_date) AS sale_year,
        ROUND(SUM(total_amount), 2) AS total_revenue
	FROM transactions
    GROUP BY YEAR(sale_date)
    ORDER BY sale_year
),
yearly_revenue_change AS (
	SELECT
		sale_year,
        total_revenue,
        ROUND(LAG(total_revenue) OVER(ORDER BY sale_year)) AS prev_year_revenue
	FROM yearly_revenue
)
SELECT
	sale_year,
    total_revenue,
    prev_year_revenue,
    CASE
		WHEN prev_year_revenue IS NOT NULL THEN
			ROUND(((total_revenue - prev_year_revenue) * 100.0 / prev_year_revenue), 2)
            ELSE NULL 
		END AS percent_change
FROM yearly_revenue_change
ORDER BY sale_year ASC;
    

-- How are MoM sales trends?

WITH monthly_revenue AS (
	SELECT
		YEAR(sale_date) AS sale_year,
        MONTH(sale_date) AS sale_month,
        ROUND(SUM(total_amount), 2) AS total_revenue
	FROM transactions
    GROUP BY YEAR(sale_date), MONTH(sale_date)
    ORDER BY sale_year, sale_month
),
revenue_change AS (
	SELECT
		sale_year,
        sale_month,
        total_revenue,
        ROUND(LAG(total_revenue) OVER(PARTITION BY sale_year ORDER BY sale_month), 2) AS prev_month_revenue
	FROM monthly_revenue
)
SELECT
	sale_year,
    sale_month,
    total_revenue,
    prev_month_revenue,
    CASE
		WHEN prev_month_revenue IS NOT NULL THEN
			ROUND(((total_revenue - prev_month_revenue) * 100.0 / prev_month_revenue), 2)
		ELSE NULL 
	END AS percent_change
FROM revenue_change
ORDER BY sale_year, sale_month;


-- How are QoQ sales trends? 

WITH quarterly_revenue AS (
	SELECT
		YEAR(sale_date) AS sale_year,
        QUARTER(sale_date) AS sale_quarter,
        ROUND(SUM(total_amount), 2) AS total_revenue
	FROM transactions
    GROUP BY YEAR(sale_date), QUARTER(sale_date)
    ORDER BY sale_year, sale_quarter
),
revenue_change AS (
	SELECT
		sale_year,
        sale_quarter,
        total_revenue,
        ROUND(LAG(total_revenue) OVER(PARTITION BY sale_year ORDER BY sale_quarter), 2) AS prev_quarter_revenue
	FROM quarterly_revenue
)
SELECT
	sale_year,
    sale_quarter,
    total_revenue,
    prev_quarter_revenue,
    CASE
		WHEN prev_quarter_revenue IS NOT NULL THEN
			ROUND(((total_revenue - prev_quarter_revenue) * 100.0 / prev_quarter_revenue), 2)
		ELSE NULL 
	END AS percent_change
FROM revenue_change
ORDER BY sale_year, sale_quarter;


-- What are the top performing products by revenue and order quantity?

SELECT
	products.product_id,
    products.product_name,
    ROUND(SUM(transactions.total_amount), 2) AS total_revenue,
    COUNT(products.product_id) AS product_count
FROM products
LEFT JOIN transactions ON products.product_id = transactions.product_id
GROUP BY products.product_id, products.product_name
ORDER BY total_revenue DESC;


-- Transitioning from products, what are the top performing product categories by revenue and order quantity?

SELECT
    p.product_category,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    COUNT(p.product_id) AS product_count,
    ROUND((SUM(t.total_amount) / (SELECT SUM(total_amount) FROM transactions) * 100), 2) AS revenue_pct
FROM products AS p
LEFT JOIN transactions AS t ON p.product_id = t.product_id
GROUP BY p.product_category
ORDER BY total_revenue DESC;


-- How much total revenue did each store bring in? 

SELECT
	s.store_id,
    s.store_location,
    ROUND(SUM(t.total_amount), 2) AS store_revenue
FROM stores AS s
INNER JOIN transactions AS t USING(store_id)
GROUP BY s.store_id, s.store_location
ORDER BY store_revenue DESC;


-- What products sell the most in different seasons?

WITH season_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        ROUND(SUM(t.total_amount), 2) AS total_sales,
        CASE
            WHEN (MONTH(sale_date) = 12 AND DAY(sale_date) >= 21) OR
                 (MONTH(sale_date) = 1) OR
                 (MONTH(sale_date) = 2) OR
                 (MONTH(sale_date) = 3 AND DAY(sale_date) <= 19) THEN 'Winter'
            WHEN (MONTH(sale_date) = 3 AND DAY(sale_date) >= 20) OR
                 (MONTH(sale_date) = 4) OR
                 (MONTH(sale_date) = 5) OR
                 (MONTH(sale_date) = 6 AND DAY(sale_date) <= 19) THEN 'Spring'
            WHEN (MONTH(sale_date) = 6 AND DAY(sale_date) >= 20) OR
                 (MONTH(sale_date) = 7) OR
                 (MONTH(sale_date) = 8) OR
                 (MONTH(sale_date) = 9 AND DAY(sale_date) <= 21) THEN 'Summer'
            WHEN (MONTH(sale_date) = 9 AND DAY(sale_date) >= 22) OR
                 (MONTH(sale_date) = 10) OR
                 (MONTH(sale_date) = 11) OR
                 (MONTH(sale_date) = 12 AND DAY(sale_date) <= 20) THEN 'Fall'
            ELSE 'Other'
        END AS season
    FROM transactions AS t
    JOIN products AS p USING(product_id)
    GROUP BY product_id, season
)
SELECT
    season,
    product_id,
    product_name,
    total_sales
FROM season_sales
WHERE (season, total_sales) IN (
    SELECT season, MAX(total_sales)
    FROM season_sales
    GROUP BY season
)
ORDER BY season;


-- How are sales on the weekends compared to weekdays? 

SELECT
	CASE
		WHEN WEEKDAY(sale_date) < 5 THEN 'Weekday'
		ELSE 'Weekend'
	END AS day_type,
    COUNT(transaction_id) AS order_count,
    ROUND(SUM(total_amount), 2) AS total_amount
FROM transactions
GROUP BY day_type
ORDER BY total_amount DESC;


-- How much do holiday/promotional seasons impact sales compared to normal business days?

SELECT 
    ROUND(SUM(total_amount), 2) AS total_sales,
    CASE 
        WHEN (MONTH(sale_date) IN (11, 12)) THEN 'Winter Holidays'
        WHEN (MONTH(sale_date) = 1 AND DAY(sale_date) <= 15) THEN 'New Year Season'
        WHEN (MONTH(sale_date) BETWEEN 3 AND 5) THEN 'Spring Holidays'
        WHEN (MONTH(sale_date) BETWEEN 6 AND 8) THEN 'Summer Holidays'
        WHEN (MONTH(sale_date) BETWEEN 9 AND 10) THEN 'Fall Holidays'
        ELSE 'Non-Holidays'
    END AS holiday_season
FROM transactions
GROUP BY holiday_season
ORDER BY total_sales DESC;


-- How often do customers buy during different seasons?

WITH customer_seasonal_preferences AS (
    SELECT
        COUNT(transaction_id) AS customer_order_count,
        CASE
            WHEN (MONTH(sale_date) = 12 AND DAY(sale_date) >= 21) OR
                 (MONTH(sale_date) = 1) OR
                 (MONTH(sale_date) = 2) OR
                 (MONTH(sale_date) = 3 AND DAY(sale_date) <= 19) THEN 'Winter'
            WHEN (MONTH(sale_date) = 3 AND DAY(sale_date) >= 20) OR
                 (MONTH(sale_date) = 4) OR
                 (MONTH(sale_date) = 5) OR
                 (MONTH(sale_date) = 6 AND DAY(sale_date) <= 19) THEN 'Spring'
            WHEN (MONTH(sale_date) = 6 AND DAY(sale_date) >= 20) OR
                 (MONTH(sale_date) = 7) OR
                 (MONTH(sale_date) = 8) OR
                 (MONTH(sale_date) = 9 AND DAY(sale_date) <= 21) THEN 'Summer'
            WHEN (MONTH(sale_date) = 9 AND DAY(sale_date) >= 22) OR
                 (MONTH(sale_date) = 10) OR
                 (MONTH(sale_date) = 11) OR
                 (MONTH(sale_date) = 12 AND DAY(sale_date) <= 20) THEN 'Fall'
            ELSE 'Other'
        END AS season
    FROM transactions AS t 
    GROUP BY season
)
SELECT * 
FROM customer_seasonal_preferences
ORDER BY customer_order_count DESC;


-- What is the YoY repeat purchase rate?

WITH yearly_customers AS (
    SELECT 
        YEAR(t.sale_date) AS purchase_year,
        COUNT(DISTINCT c.customer_id) AS total_customers,
        COUNT(DISTINCT CASE WHEN c.is_repeat_customer = 'Yes' THEN c.customer_id END) AS repeat_customers
    FROM transactions AS t
    JOIN customers AS c USING(customer_id)
    GROUP BY YEAR(t.sale_date)
),
repeat_rate AS (
    SELECT 
        purchase_year,
        total_customers,
        repeat_customers,
        ROUND((repeat_customers / total_customers) * 100, 2) AS repeat_purchase_rate
    FROM yearly_customers
)
SELECT 
    r1.purchase_year,
    r1.repeat_purchase_rate AS current_year_rate,
    r2.repeat_purchase_rate AS previous_year_rate,
    ROUND(((r1.repeat_purchase_rate - r2.repeat_purchase_rate) / r2.repeat_purchase_rate) * 100, 2) AS YoY_change
FROM repeat_rate r1
LEFT JOIN repeat_rate r2 
ON r1.purchase_year = r2.purchase_year + 1
ORDER BY r1.purchase_year;


-- What percentage of revenue comes from repeat customers vs new customers?

SELECT 
    is_repeat_customer,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    ROUND((SUM(t.total_amount) / (SELECT SUM(total_amount) FROM transactions) * 100), 2) AS revenue_pct
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
GROUP BY is_repeat_customer;


-- How many repeat customers are present, and what is the repeat purchase rate?

SELECT 
    COUNT(DISTINCT CASE WHEN c.is_repeat_customer = 'Yes' THEN c.customer_id END) AS repeat_customers,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN c.is_repeat_customer = 'Yes' THEN c.customer_id END) / 
                COUNT(DISTINCT c.customer_id), 2) AS repeat_purchase_rate
FROM customers AS c
JOIN transactions AS t ON c.customer_id = t.customer_id;


-- Which membership drives the most sales and customer loyalty?

SELECT 
	m.membership_tier,
    c.membership_tier_id,
    m.monthly_cost,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    ROUND(SUM(t.total_amount), 2) AS total_sales
FROM customers c
INNER JOIN transactions t ON c.customer_id = t.customer_id
INNER JOIN membership_tiers m ON m.membership_tier_id = c.membership_tier_id
GROUP BY c.membership_tier_id
ORDER BY total_sales DESC;


-- How many new customers and repeat customers are in each membership tier?

WITH new_customers AS (
    SELECT 
        m.membership_tier,
        COUNT(DISTINCT c.customer_id) AS new_customer_count
    FROM customers AS c
    JOIN membership_tiers AS m ON c.membership_tier_id = m.membership_tier_id
    WHERE c.is_repeat_customer = 'No'
    GROUP BY m.membership_tier
),
repeat_customers AS (
    SELECT 
        m.membership_tier,
        COUNT(DISTINCT c.customer_id) AS repeat_customer_count
    FROM customers AS c
    JOIN membership_tiers AS m ON c.membership_tier_id = m.membership_tier_id
    WHERE c.is_repeat_customer = 'Yes'
    GROUP BY m.membership_tier
),
total_customers AS (
    SELECT
        COUNT(DISTINCT c.customer_id) AS total_customers
    FROM customers AS c
)
SELECT 
    m.membership_tier,
    COALESCE(nc.new_customer_count, 0) AS new_customer_count,
    COALESCE(rc.repeat_customer_count, 0) AS repeat_customer_count,
    (COALESCE(nc.new_customer_count, 0) + COALESCE(rc.repeat_customer_count, 0)) AS total_per_membership,
    (COALESCE(nc.new_customer_count, 0) + COALESCE(rc.repeat_customer_count, 0)) * 100.0 / tc.total_customers AS percentage_of_total
FROM membership_tiers AS m
LEFT JOIN new_customers nc ON m.membership_tier = nc.membership_tier
LEFT JOIN repeat_customers rc ON m.membership_tier = rc.membership_tier
JOIN total_customers tc
ORDER BY m.membership_tier;


-- Who are the top 10 customers with the highest customer lifetime value?

WITH customer_data AS (
    SELECT 
        c.customer_id,
        COUNT(t.transaction_id) AS purchase_count,
        SUM(t.total_amount) AS total_spent,
        DATEDIFF(CURDATE(), MIN(t.sale_date)) / 365 AS customer_lifespan -- in years
    FROM 
        customers AS c
    JOIN 
        transactions AS t ON c.customer_id = t.customer_id
    GROUP BY 
        c.customer_id
)
SELECT 
    customer_id,
    ROUND(total_spent / purchase_count, 2) AS average_purchase_value,
    ROUND(purchase_count / customer_lifespan, 2) AS purchase_frequency,
    ROUND((total_spent / purchase_count) * (purchase_count / customer_lifespan) * customer_lifespan, 2) AS clv
FROM 
    customer_data
ORDER BY clv DESC
LIMIT 10;


-- How much revenue did each age group generate, and what age group is the most profitable?

SELECT
    age_groups,
    total_revenue,
    gross_margin
FROM (
    SELECT
        ROUND(SUM(t.total_amount), 2) AS total_revenue,
        ROUND((SUM(t.total_amount) - SUM(p.cost_of_goods_sold)) / SUM(t.total_amount), 3) * 100 AS gross_margin,
        CASE
            WHEN c.age < 20 THEN 'Adolescent'
            WHEN c.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.age BETWEEN 60 AND 69 THEN '60-69'
            ELSE 'Other'
        END AS age_groups
    FROM customers AS c
    JOIN transactions AS t USING(customer_record_id)
    JOIN products AS p USING(product_id)
    GROUP BY
        CASE
            WHEN c.age < 20 THEN 'Adolescent'
            WHEN c.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.age BETWEEN 60 AND 69 THEN '60-69'
            ELSE 'Other'
        END
) AS subquery
ORDER BY gross_margin DESC;


-- What is the most popular product in each age group?

WITH age_groups AS (
    SELECT
		c.customer_record_id,
		CASE
			WHEN c.age < 20 THEN 'Adolescent'
			WHEN c.age BETWEEN 20 AND 29 THEN '20-29'
			WHEN c.age BETWEEN 30 AND 39 THEN '30-39'
			WHEN c.age BETWEEN 40 AND 49 THEN '40-49'
			WHEN c.age BETWEEN 50 AND 59 THEN '50-59'
			WHEN c.age BETWEEN 60 AND 69 THEN '60-69'
			ELSE 'Other'
		END AS age_group
	FROM customers AS c
),
product_popularity AS (
	SELECT
		a.age_group,
        p.product_name,
        COUNT(t.product_id) AS product_count,
        RANK() OVER(PARTITION BY a.age_group ORDER BY COUNT(t.product_id) DESC) AS product_rank
	FROM transactions AS t
    JOIN age_groups AS a ON t.customer_record_id = a.customer_record_id
    JOIN products AS p ON t.product_id = p.product_id
    GROUP BY a.age_group, p.product_name
)
SELECT
	age_group,
    product_name
FROM product_popularity
WHERE product_rank = 1;


-- Find the customers who are most loyal to the stores for targeted VIP marketing. 

SELECT 
    c.customer_id,
    c.age,
    c.location, 
    COUNT(t.transaction_id) AS purchase_count, 
    ROUND(SUM(t.total_amount), 2) AS total_spent,
    ROUND(AVG(t.total_amount), 2) AS avg_transaction_value
FROM transactions t
JOIN customers c ON t.customer_record_id = c.customer_record_id
GROUP BY c.customer_record_id, c.age, c.location
HAVING COUNT(t.transaction_id) > 5  -- Adjust for repeat buyer threshold
ORDER BY total_spent DESC;


-- How much revenue did each gender generate?

SELECT
	c.gender,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    ROUND((SUM(t.total_amount) / (SELECT SUM(total_amount) FROM transactions) * 100), 2) AS revenue_pct
FROM customers AS c
JOIN transactions AS t
USING(customer_record_id)
GROUP BY c.gender
ORDER BY total_revenue DESC;


-- What was the most popular product for each gender?

SELECT
	gender,
    product_name,
    product_count,
    product_rank
FROM (
	SELECT
		c.gender,
		p.product_name,
		COUNT(t.product_id) AS product_count,
		RANK() OVER(PARTITION BY c.gender ORDER BY COUNT(t.product_id)) AS product_rank
	FROM transactions AS t
	JOIN customers AS c ON t.customer_record_id = c.customer_record_id
	JOIN products AS p ON t.product_id = p.product_id
	GROUP BY c.gender, p.product_name
	ORDER BY product_rank ) AS subquery
WHERE product_rank = 1;


-- For each store, rank each age group's revenue generation. 

WITH age_groups AS (
    SELECT 
        customer_record_id,
        CASE
            WHEN age < 20 THEN 'Adolescent'
            WHEN age BETWEEN 20 AND 29 THEN '20-29'
            WHEN age BETWEEN 30 AND 39 THEN '30-39'
            WHEN age BETWEEN 40 AND 49 THEN '40-49'
            WHEN age BETWEEN 50 AND 59 THEN '50-59'
            WHEN age BETWEEN 60 AND 69 THEN '60-69'
            ELSE 'Other'
        END AS age_group
    FROM customers
),
age_group_revenue AS (
    SELECT 
        c.location, 
        a.age_group,
        COUNT(c.customer_record_id) AS customer_count,
        ROUND(SUM(t.total_amount), 2) AS total_revenue,
        RANK() OVER (PARTITION BY c.location ORDER BY SUM(t.total_amount) DESC) AS rank_per_store
    FROM customers c
    JOIN transactions t ON c.customer_record_id = t.customer_record_id
    JOIN age_groups a ON c.customer_record_id = a.customer_record_id
    GROUP BY c.location, a.age_group
)
SELECT location, age_group, customer_count, total_revenue, rank_per_store
FROM age_group_revenue
ORDER BY location, rank_per_store;


-- What percent of revenue did each store generate?

SELECT 
    s.store_location, 
    ROUND(SUM(t.total_amount), 2) AS store_revenue,
    ROUND(SUM(t.total_amount) * 100.0 / (SELECT SUM(total_amount) FROM transactions), 2) AS revenue_percentage
FROM stores AS s
JOIN transactions AS t USING(store_id)
GROUP BY s.store_location
ORDER BY revenue_percentage DESC;


-- How many customers shopped at each store, and what was the average spend per transaction?

SELECT 
    c.location, 
    COUNT(DISTINCT c.customer_record_id) AS customer_count,
    ROUND(AVG(t.total_amount), 2) AS avg_spend_per_transaction
FROM transactions t
JOIN customers c ON t.customer_record_id = c.customer_record_id
GROUP BY c.location
ORDER BY avg_spend_per_transaction DESC;


-- What is the top selling product per store?
 
WITH ranked_products AS (
	SELECT
		s.store_id,
		s.store_location,
		p.product_name,
		ROUND(SUM(t.total_amount), 2) AS total_revenue,
        ROW_NUMBER() OVER(PARTITION BY s.store_id ORDER BY SUM(t.total_amount) DESC) AS product_rank
	FROM transactions AS t
	JOIN stores AS s ON t.store_id = s.store_id
	JOIN products AS p ON t.product_id = p.product_id
	GROUP BY s.store_id, s.store_location, p.product_name
	ORDER BY total_revenue DESC
)
SELECT
	store_id,
    store_location,
    product_name,
    total_revenue
FROM ranked_products
WHERE product_rank = 1
ORDER BY store_id;


-- What are the return rates for each store? Order from highest to lowest. 

SELECT s.store_location, 
       (SUM(CASE WHEN t.returns = 'Yes' THEN 1 ELSE 0 END) / COUNT(t.transaction_id)) * 100 AS return_rate
FROM transactions AS t
JOIN stores AS s
USING(store_id)
GROUP BY s.store_location
ORDER BY return_rate DESC;


-- Which stores are most affected by returns, and how do they affect overall profitability?

SELECT 
    s.store_location, 
    COUNT(t.transaction_id) AS total_transactions,
    SUM(CASE WHEN t.returns = 'Yes' THEN 1 ELSE 0 END) AS return_transactions,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    ROUND(SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END), 0) AS total_returns,
    ROUND((SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END) / NULLIF(SUM(t.total_amount), 0)) * 100, 2) AS return_rate_pct,
    ROUND(SUM(t.total_amount) - SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END), 2) AS net_sales,
    ROUND(SUM(p.cost_of_goods_sold), 2) AS total_cogs,
    ROUND((SUM(t.total_amount) - SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END) - SUM(p.cost_of_goods_sold)), 2) AS net_profit,
    ROUND(((SUM(t.total_amount) - SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END) - SUM(p.cost_of_goods_sold)) 
          / NULLIF(SUM(t.total_amount) - SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END), 0)) * 100, 2) AS net_profit_margin
FROM transactions AS t
JOIN stores AS s ON s.store_id = t.store_id
JOIN products AS p ON t.product_id = p.product_id
GROUP BY s.store_location
ORDER BY return_rate_pct DESC;


-- What is the average revenue generated per store, and which stores have total revenue above/below the threshold?

WITH revenue_per_store AS (
	SELECT
		s.store_id,
        s.store_location,
        ROUND(SUM(t.total_amount), 2) AS total_revenue
	FROM stores AS s
    INNER JOIN transactions AS t
    USING(store_id)
    GROUP BY s.store_id, s.store_location
),
store_revenue_averages AS (
	SELECT
		ROUND((SUM(total_amount) / COUNT(DISTINCT store_id)), 2) AS storewide_average
	FROM transactions
)
SELECT
	r.store_id,
    r.store_location,
   s1.storewide_average,
   r.total_revenue,
   ROUND(r.total_revenue - s1.storewide_average, 2) AS revenue_difference
FROM revenue_per_store AS r
CROSS JOIN store_revenue_averages AS s1;


-- Find the transaction volume for each store

SELECT s.store_location, COUNT(t.transaction_id) AS transaction_count
FROM stores AS s
JOIN transactions AS t USING(store_id)
GROUP BY s.store_location
ORDER BY transaction_count DESC;


-- Find the AOV(average order value) across each store

SELECT s.store_location, ROUND(AVG(t.total_amount), 2) AS avg_order_value
FROM stores AS s
JOIN transactions AS t USING(store_id)
GROUP BY s.store_location
ORDER BY avg_order_value DESC;


-- What is the repeat purchase rate for each product?

WITH product_purchases AS (
    SELECT 
        t.product_id,
        p.product_name,
        COUNT(DISTINCT t.customer_id) AS unique_customers,
        COUNT(t.transaction_id) AS total_purchases
    FROM transactions AS t
    JOIN products AS p ON t.product_id = p.product_id
    GROUP BY t.product_id, p.product_name
)
SELECT 
    product_name,
    total_purchases,
    unique_customers,
    ROUND((total_purchases - unique_customers) / total_purchases * 100, 2) AS repeat_purchase_rate
FROM product_purchases
ORDER BY repeat_purchase_rate DESC;


-- Repeat purchase rate for each product category?

WITH product_purchases AS (
    SELECT 
        p.product_category,
        COUNT(DISTINCT t.customer_id) AS unique_customers,
        COUNT(t.transaction_id) AS total_purchases
    FROM transactions AS t
    JOIN products AS p ON t.product_id = p.product_id
    GROUP BY p.product_category
)
SELECT 
    product_category,
    total_purchases,
    unique_customers,
    ROUND((total_purchases - unique_customers) / total_purchases * 100, 2) AS repeat_purchase_rate
FROM product_purchases
ORDER BY repeat_purchase_rate DESC;


-- What are the top 10 best selling products?

SELECT
	p.product_name AS best_selling_product,
    ROUND(SUM(t.total_amount), 2) AS total_amount
FROM products AS p
RIGHT JOIN transactions AS t
ON p.product_id = t.product_id
GROUP BY p.product_name
ORDER BY total_amount DESC
LIMIT 10;


-- Take the top 10 products and calculate their percentage of revenue relative to the total

WITH top_ten_products AS (
    SELECT
        p.product_name AS best_selling_product,
        ROUND(SUM(t.total_amount), 2) AS total_amount
    FROM products AS p
    RIGHT JOIN transactions AS t
    ON p.product_id = t.product_id
    GROUP BY p.product_name
    ORDER BY total_amount DESC
    LIMIT 10
)
SELECT
    best_selling_product,
    total_amount,
    total_amount * 100.0 / (SELECT SUM(total_amount) FROM top_ten_products) AS revenue_percentage
FROM top_ten_products
ORDER BY revenue_percentage DESC;


-- How many products have been returned and what is the return rate?

SELECT 
    COUNT(CASE WHEN returns = 'Yes' THEN 1 END) AS total_returns,
    COUNT(transaction_id) AS total_transactions,
    ROUND(100.0 * COUNT(CASE WHEN returns = 'Yes' THEN 1 END) / COUNT(transaction_id), 2) AS return_pct
FROM transactions;


-- Identify the slowest moving products

SELECT
	p.product_id,
    p.product_name,
    ROUND(SUM(t.total_amount), 2) AS total_revenue
FROM products AS p
LEFT JOIN transactions AS t
USING(product_id)
GROUP BY p.product_id, p.product_name
ORDER BY total_revenue ASC;


-- What are the products that are returned the least? 

SELECT 
    p.product_name,
    COUNT(CASE WHEN t.returns = 'Yes' THEN 1 END) AS return_count,
    COUNT(t.transaction_id) AS total_sales,
    ROUND(100.0 * COUNT(CASE WHEN t.returns = 'Yes' THEN 1 END) / COUNT(t.transaction_id), 2) AS return_rate
FROM products AS p
LEFT JOIN transactions AS t ON p.product_id = t.product_id
GROUP BY p.product_name
ORDER BY return_rate ASC, total_sales DESC
LIMIT 5;


-- What are the products that are returned the most? 

SELECT 
    p.product_name,
    COUNT(CASE WHEN t.returns = 'Yes' THEN 1 END) AS return_count,
    COUNT(t.transaction_id) AS total_sales,
    ROUND(100.0 * COUNT(CASE WHEN t.returns = 'Yes' THEN 1 END) / COUNT(t.transaction_id), 2) AS return_rate
FROM products AS p
LEFT JOIN transactions AS t ON p.product_id = t.product_id
GROUP BY p.product_name
ORDER BY return_rate DESC, total_sales DESC
LIMIT 5;


-- How do profit margins fluctuate by month?

SELECT 
    MONTH(t.sale_date) AS month,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    ROUND(SUM(p.cost_of_goods_sold), 2) AS total_cogs,
    ROUND((SUM(t.total_amount) - SUM(p.cost_of_goods_sold)) / SUM(t.total_amount), 3) * 100 AS profit_margin
FROM transactions AS t
JOIN products AS p ON t.product_id = p.product_id
GROUP BY month
ORDER BY profit_margin DESC;


-- What is each product's profit margin?

SELECT
	p.product_id,
    p.product_name,
    ROUND((SUM(t.total_amount) - SUM(p.cost_of_goods_sold)) / SUM(t.total_amount), 3) * 100 AS profit_margin
FROM products AS p
LEFT JOIN transactions AS t
USING(product_id)
GROUP BY p.product_id, p.product_name
ORDER BY profit_margin DESC;


-- What is each product categories' profit margin?

WITH RankedProducts AS (
    SELECT 
        p.product_id,
        p.product_category,
        ROUND((SUM(t.total_amount) - SUM(p.cost_of_goods_sold)) / SUM(t.total_amount), 3) * 100 AS profit_margin,
        ROW_NUMBER() OVER (PARTITION BY p.product_category ORDER BY 
            ROUND((SUM(t.total_amount) - SUM(p.cost_of_goods_sold)) / SUM(t.total_amount), 3) * 100 DESC) AS rank_num
    FROM products AS p
    LEFT JOIN transactions AS t USING (product_id)
    GROUP BY p.product_id, p.product_category
)
SELECT product_id, product_category, profit_margin
FROM RankedProducts
WHERE rank_num = 1
ORDER BY profit_margin DESC;


-- Finding product category order counts during February for Valentine's Day preferences

SELECT
	YEAR(t.sale_date) AS sale_year,
    MONTH(t.sale_date) AS sale_month,
	p.product_category,
    COUNT(p.product_category) AS cat_count
FROM transactions AS t
JOIN products AS p USING(product_id)
WHERE MONTH(t.sale_date) = 2
GROUP BY YEAR(t.sale_date), MONTH(t.sale_date), p.product_category
ORDER BY sale_year ASC, cat_count DESC;
    

-- Are there any products that are frequently bought together?

SELECT
	a.product_id,
    b.product_id,
    COUNT(*) AS frequency
FROM transactions AS a
JOIN transactions AS b ON a.transaction_id = b.transaction_id AND a.product_id != b.product_id
GROUP BY a.product_id, b.product_id
ORDER BY frequency;


-- Which products have the highest gross profit margin?

SELECT
	s.store_location,
    p.product_id,
    p.product_name,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    ROUND(SUM(p.cost_of_goods_sold), 2) AS total_cogs,
    ROUND((SUM(t.total_amount) - SUM(p.cost_of_goods_sold)) / SUM(t.total_amount), 3) * 100 AS gross_margin
FROM transactions AS t
JOIN stores AS s ON t.store_id = s.store_id
JOIN products AS p ON t.product_id = p.product_id
GROUP BY s.store_location, p.product_id, p.product_name
ORDER BY gross_margin DESC;


-- Which product categories have the highest gross profit margin in each store?

SELECT
	s.store_location,
    p.product_category,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    ROUND(SUM(p.cost_of_goods_sold), 2) AS total_cogs,
    ROUND((SUM(t.total_amount) - SUM(p.cost_of_goods_sold)) / SUM(t.total_amount), 3) * 100 AS gross_margin
FROM transactions AS t
JOIN stores AS s ON t.store_id = s.store_id
JOIN products AS p ON t.product_id = p.product_id
GROUP BY s.store_location, p.product_category
ORDER BY gross_margin DESC;


-- Which products have the highest gross profit margin in each store?

SELECT
	s.store_location,
    p.product_name,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    ROUND(SUM(p.cost_of_goods_sold), 2) AS total_cogs,
    ROUND((SUM(t.total_amount) - SUM(p.cost_of_goods_sold)) / SUM(t.total_amount), 3) * 100 AS gross_margin
FROM transactions AS t
JOIN stores AS s ON t.store_id = s.store_id
JOIN products AS p ON t.product_id = p.product_id
GROUP BY s.store_location, p.product_name
ORDER BY gross_margin DESC;


-- What product categories have the highest return rates?

SELECT 
    p.product_category,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(CASE WHEN t.returns = 'Yes' THEN 1 ELSE 0 END) AS return_transactions,
    ROUND(SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END), 0) AS total_returns,
    ROUND((SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END) / NULLIF(SUM(t.total_amount), 0)) * 100, 2) AS return_rate_pct
FROM transactions AS t
JOIN products AS p ON t.product_id = p.product_id
GROUP BY p.product_category
ORDER BY return_rate_pct DESC;


-- What products have the highest return rates?

SELECT 
    p.product_name,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(CASE WHEN t.returns = 'Yes' THEN 1 ELSE 0 END) AS return_transactions,
    ROUND(SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END), 0) AS total_returns,
    ROUND((SUM(CASE WHEN t.returns = 'Yes' THEN t.total_amount ELSE 0 END) / NULLIF(SUM(t.total_amount), 0)) * 100, 2) AS return_rate_pct
FROM transactions AS t
JOIN products AS p ON t.product_id = p.product_id
GROUP BY p.product_name
ORDER BY return_rate_pct DESC;