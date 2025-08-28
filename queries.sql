-- Общее количество покупателей.
-- Запрос делает выборку количества уникальных id покупателей из таблицы customers.

select distinct count(customer_id) as customers_count
from customers;


-- Анализ отдела продаж

-- 1 отчёт (top_10_total_income)
-- Здесь в одном запросе я формирую имя, считаю кол-во операций и общую выручку.

select
    concat(e.first_name, ' ', e.last_name) as seller,
    count(s.sales_id) as operations,
    floor(sum(s.quantity * p.price)) as income
from sales as s
inner join products as p on s.product_id = p.product_id
inner join employees as e on s.sales_person_id = e.employee_id
group by s.sales_person_id, concat(e.first_name, ' ', e.last_name)
order by income desc limit 10;


-- 2 отчёт (lowest_average_income)

/*

total_avg_income - табличное выражение со средней выручкой по всем продавцам.
avg_income - табличное выражение со средней выручкой каждого из продавцов.
В основном запросе я делаю выборку продавцов и их средней выручки.
Для продавцов, чья средняя выручка ниже средней выручки по всем продавцам.

*/

with total_avg_income as (
    select avg(s.quantity * p.price) as total_avg
    from sales as s
    inner join products as p on s.product_id = p.product_id
),

avg_income as (
    select
        concat(e.first_name, ' ', e.last_name) as seller,
        floor(sum(s.quantity * p.price) / count(s.sales_id)) as average_income
    from sales as s
    inner join products as p on s.product_id = p.product_id
    inner join employees as e on s.sales_person_id = e.employee_id
    group by e.employee_id
)

select
    ai.seller,
    ai.average_income
from avg_income as ai
cross join total_avg_income as tai
where ai.average_income < tai.total_avg
order by ai.average_income;


-- 3 отчёт (day_of_the_week_income)

/*

tab1 - таблица с id продажи и номером дня недели.
В ней я меняю порядковый номер "sunday" с 0 на 7.
В tab2 я формирую табличное выражение со всеми данными и сортирую данные в нём.
В основном запросе я делаю выборку только того, что требуется в отчёте.

ps Поздно понял, что нужно объединить все понедельники, вторники, ... для каждого из сотрудников(

*/

with tab1 as (
    select
        s.sales_id,
        case extract(dow from s.sale_date)
            when 0 then 7
            else extract(dow from s.sale_date)
        end as day_number
    from sales as s
),

tab2 as (
    select
        e.employee_id,
        t1.day_number,
        concat(e.first_name, ' ', e.last_name) as seller,
        to_char(s.sale_date, 'day') as day_of_week,
        floor(sum(s.quantity * p.price)) as income
    from sales as s
    inner join tab1 as t1 on s.sales_id = t1.sales_id
    inner join products as p on s.product_id = p.product_id
    inner join employees as e on s.sales_person_id = e.employee_id
    group by e.employee_id, t1.day_number, to_char(s.sale_date, 'day')
    order by t1.day_number, seller
)

select
    seller,
    day_of_week,
    income
from tab2;

-- Анализ покупателей

-- 1 отчёт (age_groups)
-- Объединение трёх подзапросов, каждый из которых считает количество покупателей в определённом возрастном диапазоне.

(select
    '16-25' as age_category,
    count(*) as age_count
from customers
where age between 16 and 25)
union
(select
    '26-40' as age_category,
    count(*) as age_count
from customers
where age between 26 and 40)
union
(select
    '40+' as age_category,
    count(*) as age_count
from customers
where age > 40)
order by age_category;

-- 2 отчёт (customers_by_month)
-- Я делаю выборку количества уникальных покупателей и суммы их выручки с группировкой под месяцам.

select
    to_char(s.sale_date, 'YYYY-MM') as selling_month,
    count(distinct s.customer_id) as total_customers,
    floor(sum(s.quantity * p.price)) as income
from sales as s
inner join products as p on s.product_id = p.product_id
group by to_char(s.sale_date, 'YYYY-MM')
order by selling_month;

-- 3 отчёт (special_offer)

/*

Я создаю табличное выражение с данными покупателя, продавца и даты сделки, когда цена была равна 0,
также добавляю оконную функцию row_number с сортировкой по дате, 
чтобы в основном запросе были данные не всех покупок, а только одной первой.

*/

with tab as (
    select
        s.sale_date::date as sale_date,
        c.first_name || ' ' || c.last_name as customer,
        concat(e.first_name, ' ', e.last_name) as seller,
        row_number() over (
            partition by c.customer_id order by s.sale_date
        ) as rn
    from sales as s
    inner join customers as c on s.customer_id = c.customer_id
    inner join employees as e on s.sales_person_id = e.employee_id
    inner join products as p on s.product_id = p.product_id
    where s.quantity * p.price = 0
    order by c.customer_id
)

select
    customer,
    sale_date,
    seller
from tab
where rn = 1;

/* 

Мне не понравилось делать дашборд и презентацию с имеющимися данными,
поэтому я сделал ещё несколько выборок:

-- топ-10 самых продаваемых продуктов

select 
    products.name as product_name,
    sum(sales.quantity) as quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join products on products.product_id = sales.product_id
group by products.name
order by total_amount desc limit 10;

-- топ-10 наименее продаваемых продуктов

select 
    products.name as product_name,
    sum(sales.quantity) as quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join products on products.product_id = sales.product_id
where products.price <> 0
group by products.name
order by total_amount asc limit 10;

-- доля выручки с каждого продукта

select 
    products.name as product_name,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join products on products.product_id = sales.product_id
group by products.name
order by total_amount desc;

-- топ-10 клиентов

select 
    customers.first_name || ' ' || customers.last_name as customer,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join customers on customers.customer_id = sales.customer_id
inner join products on products.product_id = sales.product_id
group by customers.first_name || ' ' || customers.last_name
order by total_amount desc limit 10;

-- вклад клиентов по возрастной группе

(select 
    '16-25' as age_category,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join customers on customers.customer_id = sales.customer_id
inner join products on products.product_id = sales.product_id
where customers.age between 16 and 25)
union
(select 
    '26-40' as age_category,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join customers on customers.customer_id = sales.customer_id
inner join products on products.product_id = sales.product_id
where customers.age between 26 and 40)
union
(select 
    '40+' as age_category,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join customers on customers.customer_id = sales.customer_id
inner join products on products.product_id = sales.product_id
where customers.age > 40)
;

-- топ-10 товаров каждой возрастной группы

(select 
    '16-25' as age_category,
    products.name as product_name,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join customers on customers.customer_id = sales.customer_id
inner join products on products.product_id = sales.product_id
where customers.age between 16 and 25
group by products.name
order by total_amount desc, total_quantity desc limit 10)
union
(select 
    '26-40' as age_category,
    products.name as product_name,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join customers on customers.customer_id = sales.customer_id
inner join products on products.product_id = sales.product_id
where customers.age between 26 and 40
group by products.name
order by total_amount desc, total_quantity desc limit 10)
union
(select 
    '40+' as age_category,
    products.name as product_name,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join customers on customers.customer_id = sales.customer_id
inner join products on products.product_id = sales.product_id
where customers.age > 40
group by products.name
order by total_amount desc, total_quantity desc limit 10)
order by age_category asc, total_amount desc, total_quantity desc
;

-- все сотрудники (для исследования взаимосвязи)

select 
    employees.first_name || ' ' || employees.last_name as seller,
    sum(sales.sales_id) as sale_count,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity*products.price)) as total_amount
from sales
inner join products on products.product_id = sales.product_id
inner join employees on employees.employee_id = sales.sales_person_id
group by employees.first_name || ' ' || employees.last_name
order by total_amount desc;

*/