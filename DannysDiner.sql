USE [Dannys Diner];

CREATE TABLE sales(
	"customer_id" VARCHAR(1),
	"order_date" DATE,
	"product_id" INT
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');

CREATE TABLE menu(
	"product_id" INT,
	"product_name" VARCHAR(5),
	"price" INT
);

INSERT INTO menu
	("product_id", "product_name", "price")
VALUES
	('1', 'sushi', '10'),
	('2', 'curry', '15'),
	('3', 'ramen', '12');

CREATE TABLE members(
	"customer_id" VARCHAR(1),
	"join_date" DATE
);

INSERT INTO members
	("customer_id", "join_date")
VALUES
	('A', '2021-01-07'),
	('B', '2021-01-09');

SELECT * FROM sales;
SELECT * FROM menu;
SELECT * FROM members;

/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?

SELECT s.customer_id, SUM(price) AS total_amount_spent
FROM sales AS s
INNER JOIN menu AS m
ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT order_date) AS num_days
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?

WITH cte AS
(
SELECT s.customer_id, m.product_name,
ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS row_num
FROM sales AS s
JOIN menu AS m
ON s.product_id = m.product_id
)
SELECT customer_id, product_name
FROM cte
WHERE row_num = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT TOP 1 m.product_name, COUNT(m.product_name) AS order_count
FROM sales AS s
JOIN menu AS m
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY COUNT(m.product_name) DESC;

-- 5. Which item was the most popular for each customer?

WITH item_count AS
(
SELECT s.customer_id, m.product_name,
COUNT(*) AS order_count,
DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS ranking
FROM sales AS s
JOIN menu AS m
ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, product_name
FROM item_count
WHERE ranking = 1;


-- 6. Which item was purchased first by the customer after they became a member?

WITH orders AS
(
	SELECT s.customer_id, m.product_name, s.order_date, mb.join_date,
	DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY order_date) AS ranking
	FROM menu AS m
	JOIN sales AS s
	ON m.product_id = s.product_id
	JOIN members AS mb
	ON s.customer_id = mb.customer_id
	WHERE s.order_date > mb.join_date
)
SELECT customer_id, product_name
FROM orders
WHERE ranking = 1;



-- 7. Which item was purchased just before the customer became a member?

WITH orders AS
(
	SELECT s.customer_id, m.product_name, s.order_date, mb.join_date,
	DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY order_date DESC) AS ranking
	FROM menu AS m
	JOIN sales AS s
	ON m.product_id = s.product_id
	JOIN members AS mb
	ON s.customer_id = mb.customer_id
	WHERE s.order_date < mb.join_date
)
SELECT customer_id, product_name
FROM orders
WHERE ranking = 1;


-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id,
COUNT(m.product_id) AS total_items_ordered,
SUM(price) AS total_amount_spent
FROM menu AS m
JOIN sales AS s
ON m.product_id = s.product_id
JOIN members AS mb
ON s.customer_id = mb.customer_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH cte AS
(
	SELECT s.customer_id, m.product_name, m.price,
	CASE
		WHEN m.product_name = 'sushi' THEN m.price*10*2
		ELSE m.price*10
		END AS points
	FROM sales AS s
	JOIN menu AS m
	ON s.product_id = m.product_id
)
SELECT customer_id, SUM(points) AS total_points
FROM cte
GROUP BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH cte AS
(
SELECT s.customer_id, m.product_name, m.price, order_date, join_date, 
CASE
	WHEN s.order_date BETWEEN mb.join_date AND DATEADD(day, 7, mb.join_date) THEN m.price * 10 * 2
	WHEN m.product_name = 'sushi' THEN m.price * 10 * 2
	ELSE m.price * 10
	END AS points
FROM menu AS m
JOIN sales AS s
ON s.product_id = m.product_id
JOIN members AS mb
ON s.customer_id = mb.customer_id
WHERE order_date < '2021-02-01'
)
SELECT customer_id, SUM(points) AS total_points
FROM cte
GROUP BY customer_id


-- BONUS Questions
-- 11. Determine the name and price of the product ordered by each customer on all order dates & find out whether the customer was a member on the order date or not?

SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE
	WHEN mb.join_date <= s.order_date THEN 'Y'
	ELSE 'N'
	END AS member
FROM menu AS m
JOIN sales AS s
ON s.product_id = m.product_id
LEFT JOIN members AS mb
ON mb.customer_id = s.customer_id

-- 12. Rank the previous output from Q.11 based on the order_date for each customer and Display NULL if the customer was not a member when dish was ordered?

WITH cte AS
(
 SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE
	WHEN mb.join_date <= s.order_date THEN 'Y'
	ELSE 'N'
	END AS member_status
FROM menu AS m
JOIN sales AS s
ON s.product_id = m.product_id
LEFT JOIN members AS mb
ON mb.customer_id = s.customer_id
)
SELECT *,
CASE
	WHEN cte.member_status = 'Y' THEN RANK() OVER (PARTITION BY customer_id, member_status ORDER BY order_date)
	ELSE NULL
	END AS ranking
FROM cte