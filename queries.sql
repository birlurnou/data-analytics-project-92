-- Общее количество покупателей.
-- Запрос делает выборку количества уникальных 
-- id покупателей из таблицы customers.

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
group by s.sales_person_id -- убрал лишнюю группировку
order by income desc limit 10;


-- 2 отчёт (lowest_average_income)

/*

tab - все сотрудники и их средняя выручка
В основном запросе отсеиваем тех, чья средняя выручка выше средней выручки по
всем сотрудникам

*/

with tab as (
    select
        e.first_name || ' ' || e.last_name as seller,
        floor(sum(s.quantity * p.price) / count(s.sales_id)) as average_income
    from sales as s
    inner join employees as e on s.sales_person_id = e.employee_id
    inner join products as p on s.product_id = p.product_id
    group by e.employee_id
)

select
    seller,
    average_income
from tab
where
    average_income < (
        select avg(s.quantity * p.price)
        from sales as s
        inner join products as p on s.product_id = p.product_id
    )
order by average_income;

-- 3 отчёт (day_of_the_week_income)

/*

Переделал запрос.
Без cte/подзапроса не получилось, так как требуется отсортировать по дню недели.
Тогда мне нужно в выборку включать номер дня недели, которого не должно быть
в итоговой таблице.

*/

with tab as (
    select
        e.first_name || ' ' || e.last_name as seller,
        to_char(s.sale_date, 'day') as day_of_week,
        extract(isodow from s.sale_date) as number_of_day,
        floor(sum(s.quantity * p.price)) as income
    from sales as s
    inner join products as p on s.product_id = p.product_id
    inner join employees as e on s.sales_person_id = e.employee_id
    group by
        e.employee_id,
        to_char(s.sale_date, 'day'),
        extract(isodow from s.sale_date)
    order by number_of_day, seller
)

select
    seller,
    day_of_week,
    income
from tab;

-- Анализ покупателей

-- 1 отчёт (age_groups)
-- Сделал вместо объединения трёх запросов один запрос

select
    case
        when age between 16 and 25 then '16-25'
        when age between 26 and 40 then '26-40'
        when age > 40 then '40+'
    end as age_category,
    count(*) as age_count
from customers
group by
    case
        when age between 16 and 25 then '16-25'
        when age between 26 and 40 then '26-40'
        when age > 40 then '40+'
    end
order by age_category;

-- 2 отчёт (customers_by_month)
-- Я делаю выборку количества уникальных покупателей и суммы их выручки с 
-- группировкой под месяцам.

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

Я создаю табличное выражение с данными покупателя, продавца и даты сделки,
когда цена была равна 0,
также добавляю оконную функцию row_number с сортировкой по дате,
чтобы в основном запросе были данные не всех покупок, а только одной первой.

*/

with tab as (
    select
        s.sale_date::date as sale_date,
        c.first_name || ' ' || c.last_name as customer,
        concat(e.first_name, ' ', e.last_name) as seller,
        row_number() over (
            partition by c.customer_id
            order by s.sale_date
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
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join products on sales.product_id = products.product_id
group by products.name
order by total_amount desc limit 10;

-- топ-10 наименее продаваемых продуктов

select
    products.name as product_name,
    sum(sales.quantity) as quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join products on sales.product_id = products.product_id
where products.price <> 0
group by products.name
order by total_amount asc limit 10;

-- доля выручки с каждого продукта

select
    products.name as product_name,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join products on sales.product_id = products.product_id
group by products.name
order by total_amount desc;

-- топ-10 клиентов

select
    customers.first_name || ' ' || customers.last_name as customer,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join customers on sales.customer_id = customers.customer_id
inner join products on sales.product_id = products.product_id
group by customers.first_name || ' ' || customers.last_name
order by total_amount desc limit 10;

-- вклад клиентов по возрастной группе

(select
    '16-25' as age_category,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join customers on sales.customer_id = customers.customer_id
inner join products on sales.product_id = products.product_id
where customers.age between 16 and 25)
union
(select
    '26-40' as age_category,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join customers on sales.customer_id = customers.customer_id
inner join products on sales.product_id = products.product_id
where customers.age between 26 and 40)
union
(select
    '40+' as age_category,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join customers on sales.customer_id = customers.customer_id
inner join products on sales.product_id = products.product_id
where customers.age > 40);

-- топ-10 товаров каждой возрастной группы

(select
    '16-25' as age_category,
    products.name as product_name,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join customers on sales.customer_id = customers.customer_id
inner join products on sales.product_id = products.product_id
where customers.age between 16 and 25
group by products.name
order by total_amount desc, total_quantity desc limit 10)
union
(select
    '26-40' as age_category,
    products.name as product_name,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join customers on sales.customer_id = customers.customers
inner join products on sales.product_id = products.product_id
where customers.age between 26 and 40
group by products.name
order by total_amount desc, total_quantity desc limit 10)
union
(select
    '40+' as age_category,
    products.name as product_name,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join customers on sales.customer_id = customers.customer_id
inner join products on sales.product_id = products.product_id
where customers.age > 40
group by products.name
order by total_amount desc, total_quantity desc limit 10)
order by age_category asc, total_amount desc, total_quantity desc;

-- все сотрудники (для исследования взаимосвязи)

select
    employees.first_name || ' ' || employees.last_name as seller,
    sum(sales.sales_id) as sale_count,
    sum(sales.quantity) as total_quantity,
    floor(sum(sales.quantity * products.price)) as total_amount
from sales
inner join products on sales.product_id = products.product_id
inner join employees on sales.sales_person_id = employees.employee_id
group by employees.first_name || ' ' || employees.last_name
order by total_amount desc;

*/
