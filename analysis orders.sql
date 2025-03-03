/* 
Найти самый популярный товар в сервисе 
(тот, который попал в заказы клиентов наибольшее количество раз).
*/
with products_amount as (
select op.product_id, p.product_name, sum(op.amount) as total_amount
from orders_product op
join products p
on op.product_id = p.product_id
group by op.product_id, p.product_name 
)
select product_name
from products_amount
where total_amount = (
   select max(total_amount)
   from products_amount
 );


-- Найти день, в который количество выполненных доставок в сервисе было 
-- максимальным за всё время работы сервиса.
with completed_deliveries as (
select *
from info
where is_completed_flg = 'True'
),
count_deliveries as (
select delivery_dt, count(delivery_id) as total_deliveries
from completed_deliveries
group by delivery_dt
)
select delivery_dt
from count_deliveries
where total_deliveries = (
select max(total_deliveries) from count_deliveries
);


--another way
select delivery_dt
from delivery_info
where is_completed_flg = 1
group by delivery_dt
order by count(delivery_dt) DESC
limit 1;


/*
Найти день, в который количество выполненных доставок в сервисе было минимальным за 
всё время работы сервиса.
*/
with completed_deliveries as (
select *
from info
where is_completed_flg = 'True'
),
count_deliveries as (
select delivery_dt, count(delivery_id) as total_deliveries
from completed_deliveries
group by delivery_dt
)
select delivery_dt
from count_deliveries
where total_deliveries = (
select min(total_deliveries) from count_deliveries
)


--Посчитать среднее время сессии пользователей в приложении в зависимости от используемого устройства в минутах.
with time_to_min as (
select *, 
    TIMESTAMPDIFF(MINUTE, start_dttm, finish_dttm) 
AS minutes_spent
 from app_sess 
)
select device_name, avg(minutes_spent)
from time_to_min
group by device_name


-- Найти максимальное количество различных товаров, добавленных в один заказ.
with total_prod as (
select order_id, count(product_id) as total
from orders_product
group by order_id
)
select max(total)
from total_prod


-- Подготовить статистику по количеству незавершённых доставок по месяцам, начиная с 2022 года.
with converted_delivery as (
select *, 
SUBSTRING_INDEX(delivery_dt, '-', 1) AS day,
SUBSTRING_INDEX(SUBSTRING_INDEX(delivery_dt, '-', 2), '-', -1) AS month,
SUBSTRING_INDEX(SUBSTRING_INDEX(delivery_dt, '-', 3), '-', -1) AS year
from info
),
from2022 as (
select * 
from converted_delivery
where year >= 2022 and is_completed_flg='False'
),
groupbymonth as (
select month, count(delivery_id) as '# of incomplete orders'
from from2022
group by month
)
select * from groupbymonth
order by month asc;


--Подготовить статистику по количеству заказов в разрезе метода оплаты по годам за всё время работы сервиса.
select 
SUBSTRING_INDEX(SUBSTRING_INDEX(order_dt, '.', 3), '.', -1) AS year, 
payment_method,
count(order_id) as 'количество заказов'
from orders
group by year, payment_method
order by year, payment_method, 'количество заказов';


-- Найти топ-10 клиентов, совершивших наибольшее количество заказов за всё время работы сервиса.
select customer_id, count(order_id) as orders_amount
from orders 
group by customer_id
order by orders_amount desc
limit 10;


/* Найти самые популярные категории товаров (product_group_name) среди пользователей различных возрастных групп:
18–30 лет;
30–45 лет;
45–60 лет;
60+ лет.
*/
with created_age as (
select op.product_id, p.product_group_name, p.product_name, op.order_id,
o.customer_id, c.first_name, c.birth_dt, 
TIMESTAMPDIFF(YEAR, STR_TO_DATE(c.birth_dt, '%d.%m.%Y'), CURDATE()) AS age
from products p
inner join orders_product op
on  p.product_id = op.product_id
inner join orders o
on op.order_id = o.order_id
inner join customers c
on c.customer_id = o.customer_id 
),
create_group as (
select product_id, product_group_name, product_name, order_id,
customer_id, age,
CASE
WHEN age between 18 and 30 THEN '18-30'
WHEN age between 30 and 45 THEN '30-45'
WHEN age between 45 and 60 THEN '45-60'
WHEN age > 60 THEN '60+'
Else '-'
END AS age_category
from created_age
),
ranking as (
SELECT 
    age_category,
    product_group_name,
    count(product_id) AS purchase_count,
    RANK() OVER (PARTITION BY age_category ORDER BY  count(product_id) DESC) AS rnk
FROM create_group
GROUP BY age_category, product_group_name
)
select age_category, product_group_name, purchase_count
from ranking 
where rnk = 1;


-- Найти товар, который клиенты чаще всего заказывают совместно с 'Носки'.
WITH paired_products AS (
    SELECT 
        p.product_name,
        op1.product_id AS main_product,
        op2.product_id AS associated_product,
        COUNT(*) AS frequency
    FROM orders_product op1
    JOIN orders_product op2 
        ON op1.order_id = op2.order_id  
        AND op1.product_id != op2.product_id  
    JOIN products p
        ON p.product_id = op1.product_id
    WHERE p.product_name = 'Носки' 
    GROUP BY op1.product_id, op2.product_id
    ORDER BY frequency DESC
    LIMIT 1
)
SELECT 
    p.product_name AS most_frequently_bought_together,
    pp.frequency
FROM paired_products pp
JOIN products p ON pp.associated_product = p.product_id;
