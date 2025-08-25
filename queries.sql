-- Общее количество покупателей.
-- Запрос делает выборку количества уникальных id покупателей из таблицы customers.

select distinct count(customer_id) as "customers_count"
from customers;


-- Анализ отдела продаж

-- 1 отчёт
-- Здесь в одном запросе я формирую имя, считаю кол-во операций и общую выручку.

select 
    concat(e.first_name, ' ', e.last_name) as seller,
    count(s.sales_id) as operations,
    floor(sum(s.quantity * p.price)) as income
from sales s
inner join products p on s.product_id = p.product_id
inner join employees e on s.sales_person_id = e.employee_id
group by s.sales_person_id, concat(e.first_name, ' ', e.last_name)
order by income desc;


-- 2 отчёт

/*

total_avg_income - табличное выражение со средней выручкой по всем продавцам.
avg_income - табличное выражение со средней выручкой каждого из продавцов.
В основном запросе я делаю выборку продавцов и их средней выручки.
Для продавцов, чья средняя выручка ниже средней выручки по всем продавцам.

*/

with total_avg_income as (
    select avg(s.quantity*p.price) as total_avg
    from sales s
    inner join products p on s.product_id = p.product_id
),
avg_income as (
    select 
        concat(e.first_name, ' ', e.last_name) as seller,
        floor(sum(s.quantity * p.price)/count(s.sales_id)) as average_income
    from sales s
    inner join products p on s.product_id = p.product_id
    inner join employees e on s.sales_person_id = e.employee_id
    group by e.employee_id
)
select 
    ai.seller,
    ai.average_income
from avg_income ai
cross join total_avg_income tai
where ai.average_income < tai.total_avg
order by ai.average_income;


-- 3 отчёт

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
        (
        case extract(dow from s.sale_date)
            when 0 then 7
            else extract(dow from s.sale_date)
        end
        ) as day_number
    from sales s
),
tab2 as (
    select
        e.employee_id,
        concat(e.first_name, ' ', e.last_name) as seller,
        t1.day_number,
        to_char(s.sale_date, 'day') as day_of_week,
        floor(sum(s.quantity*p.price)) as income
    from sales s
    inner join tab1 t1 on s.sales_id = t1.sales_id
    inner join products p on s.product_id = p.product_id
    inner join employees e on s.sales_person_id = e.employee_id
    -- group by e.employee_id, s.sale_date, t1.day_number, to_char(s.sale_date, 'day')
    group by e.employee_id, t1.day_number, to_char(s.sale_date, 'day')
    order by t1.day_number, seller
)
select
    seller,
    day_of_week,
    income
from tab2;

-- Анализ покупателей

-- 1 отчёт
-- Объединение трёх подзапросов, каждый из которых считает количество покупателей в определённом возрастном диапазоне

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
;

-- 2 отчёт
-- Я делаю выборку количества уникальных покупателей и суммы их выручки с группировкой под месяцам

select 
    to_char(sale_date, 'YYYY-MM') as selling_month,
    count(distinct s.customer_id) as total_customers, 
    floor(sum(s.quantity*p.price)) as income
from sales s
inner join products p on s.product_id = p.product_id
group by to_char(sale_date, 'YYYY-MM')
order by selling_month;

-- 3 отчёт

/*

Я создаю табличное выражение с данными покупателя, продавца и даты сделки, когда цена была равна 0,
также добавляю оконную функцию row_number с сортировкой по дате, 
чтобы в основном запросе были данные не всех покупок, а только одной первой

*/

with tab as (
    select 
        c.first_name || ' ' || c.last_name as customer,
        s.sale_date::date as sale_date,
        concat(e.first_name, ' ', e.last_name) as seller,
        row_number() over (partition by c.customer_id order by s.sale_date) as rn
    from sales s
    inner join employees e on e.employee_id = s.sales_person_id
    inner join customers c on c.customer_id = s.customer_id
    inner join products p on p.product_id = s.product_id
    where s.quantity * p.price = 0
    order by c.customer_id
)

select 
    customer,
    sale_date,
    seller
from tab
where rn = 1;