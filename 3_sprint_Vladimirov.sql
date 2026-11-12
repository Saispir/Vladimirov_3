/* Проект «Разработка витрины и решение ad-hoc задач»
 * Цель проекта: подготовка витрины данных маркетплейса «ВсёТут»
 * и решение четырех ad hoc задач на её основе
 * 
 * Автор: Владимиров Денис
 * Дата: 08.09.2026 
*/



/* Часть 1. Разработка витрины данных
 * Напишите ниже запрос для создания витрины данных
*/
WITH top_regions AS (
    SELECT u.region
    FROM ds_ecom.orders o
    JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id 
    WHERE o.order_status IN ('Доставлено', 'Отменено')
    GROUP BY u.region
    ORDER BY COUNT(o.order_id) DESC
    LIMIT 3
),
payment_features AS (
    SELECT 
        order_id,
        FIRST_VALUE(payment_type) OVER (PARTITION BY order_id ORDER BY payment_sequential ASC) AS first_payment_type,
        MAX(CASE WHEN payment_installments > 1 THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_installment,
        MAX(CASE WHEN payment_type = 'промокод' THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_promo
    FROM ds_ecom.order_payments
),
order_payments_agg AS (
    SELECT order_id, MAX(first_payment_type) AS first_payment_type, MAX(has_installment) AS has_installment, MAX(has_promo) AS has_promo
    FROM payment_features GROUP BY order_id
),
order_costs AS (
    SELECT o.order_id, SUM(oi.price + oi.delivery_cost) AS order_total_cost
    FROM ds_ecom.orders o
    JOIN ds_ecom.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Доставлено'
    GROUP BY o.order_id
),
order_reviews_agg AS (
    SELECT order_id, AVG(CASE WHEN review_score > 5 THEN review_score / 10.0 ELSE review_score END) AS avg_review_score
    FROM ds_ecom.order_reviews GROUP BY order_id
),
order_level AS (
    SELECT o.order_id, u.user_id, u.region, o.order_status, o.order_purchase_ts, oc.order_total_cost, ora.avg_review_score,
           COALESCE(opa.has_installment, 0) AS has_installment, COALESCE(opa.has_promo, 0) AS has_promo, opa.first_payment_type
    FROM ds_ecom.orders o
    JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id
    LEFT JOIN order_costs oc ON o.order_id = oc.order_id
    LEFT JOIN order_reviews_agg ora ON o.order_id = ora.order_id
    LEFT JOIN order_payments_agg opa ON o.order_id = opa.order_id
    WHERE o.order_status IN ('Доставлено', 'Отменено') AND u.region IN (SELECT region FROM top_regions)
)
SELECT 
	user_id, region, MIN(order_purchase_ts) AS first_order_ts, MAX(order_purchase_ts) AS last_order_ts,
	MAX(order_purchase_ts) - MIN(order_purchase_ts) AS lifetime,
	COUNT(order_id) AS total_orders,
	ROUND(AVG(avg_review_score)::numeric, 2) AS avg_order_rating,
	COUNT(avg_review_score) AS num_orders_with_rating,
	COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END) AS num_canceled_orders,
	ROUND((COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END)::numeric / COUNT(order_id)::numeric), 4) AS canceled_orders_ratio,
	COALESCE(SUM(order_total_cost), 0) AS total_order_costs,
	ROUND(COALESCE(AVG(order_total_cost), 0)::numeric, 2) AS avg_order_cost,
	SUM(has_installment) AS num_installment_orders, SUM(has_promo) AS num_orders_with_promo,
	MAX(CASE WHEN first_payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS used_money_transfer,
	MAX(has_installment) AS used_installments, MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
FROM order_level GROUP BY user_id, region;
    
/* Часть 2. Решение ad hoc задач
 * Для каждой задачи напишите отдельный запрос.
 * После каждой задачи оставьте краткий комментарий с выводами по полученным результатам.
*/
    

/* Задача 1. Сегментация пользователей 
 * Разделите пользователей на группы по количеству совершённых ими заказов.
 * Подсчитайте для каждой группы общее количество пользователей,
 * среднее количество заказов, среднюю стоимость заказа.
 * 
 * Выделите такие сегменты:
 * - 1 заказ — сегмент 1 заказ
 * - от 2 до 5 заказов — сегмент 2-5 заказов
 * - от 6 до 10 заказов — сегмент 6-10 заказов
 * - 11 и более заказов — сегмент 11 и более заказов
*/

WITH top_regions AS (
    SELECT u.region
    FROM ds_ecom.orders o
    JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id 
    WHERE o.order_status IN ('Доставлено', 'Отменено')
    GROUP BY u.region
    ORDER BY COUNT(o.order_id) DESC
    LIMIT 3
),
payment_features AS (
    SELECT 
        order_id,
        FIRST_VALUE(payment_type) OVER (PARTITION BY order_id ORDER BY payment_sequential ASC) AS first_payment_type,
        MAX(CASE WHEN payment_installments > 1 THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_installment,
        MAX(CASE WHEN payment_type = 'промокод' THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_promo
    FROM ds_ecom.order_payments
),
order_payments_agg AS (
    SELECT order_id, MAX(first_payment_type) AS first_payment_type, MAX(has_installment) AS has_installment, MAX(has_promo) AS has_promo
    FROM payment_features GROUP BY order_id
),
order_costs AS (
    SELECT o.order_id, SUM(oi.price + oi.delivery_cost) AS order_total_cost
    FROM ds_ecom.orders o
    JOIN ds_ecom.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Доставлено'
    GROUP BY o.order_id
),
order_reviews_agg AS (
    SELECT order_id, AVG(CASE WHEN review_score > 5 THEN review_score / 10.0 ELSE review_score END) AS avg_review_score
    FROM ds_ecom.order_reviews GROUP BY order_id
),
order_level AS (
    SELECT o.order_id, u.user_id, u.region, o.order_status, o.order_purchase_ts, oc.order_total_cost, ora.avg_review_score,
           COALESCE(opa.has_installment, 0) AS has_installment, COALESCE(opa.has_promo, 0) AS has_promo, opa.first_payment_type
    FROM ds_ecom.orders o
    JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id
    LEFT JOIN order_costs oc ON o.order_id = oc.order_id
    LEFT JOIN order_reviews_agg ora ON o.order_id = ora.order_id
    LEFT JOIN order_payments_agg opa ON o.order_id = opa.order_id
    WHERE o.order_status IN ('Доставлено', 'Отменено') AND u.region IN (SELECT region FROM top_regions)
),
showcase AS (
    SELECT 
        user_id, region, MIN(order_purchase_ts) AS first_order_ts, MAX(order_purchase_ts) AS last_order_ts,
        MAX(order_purchase_ts) - MIN(order_purchase_ts) AS lifetime,
        COUNT(order_id) AS total_orders,
        ROUND(AVG(avg_review_score)::numeric, 2) AS avg_order_rating,
        COUNT(avg_review_score) AS num_orders_with_rating,
        COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END) AS num_canceled_orders,
        ROUND((COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END)::numeric / COUNT(order_id)::numeric), 4) AS canceled_orders_ratio,
        COALESCE(SUM(order_total_cost), 0) AS total_order_costs,
        ROUND(COALESCE(AVG(order_total_cost), 0)::numeric, 2) AS avg_order_cost,
        SUM(has_installment) AS num_installment_orders, SUM(has_promo) AS num_orders_with_promo,
        MAX(CASE WHEN first_payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS used_money_transfer,
        MAX(has_installment) AS used_installments, MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
    FROM order_level GROUP BY user_id, region
),
user_segments AS (
    SELECT 
        *,
        CASE 
            WHEN total_orders = 1 THEN '1 заказ'
            WHEN total_orders BETWEEN 2 AND 5 THEN '2-5 заказов'
            WHEN total_orders BETWEEN 6 AND 10 THEN '6-10 заказов'
            ELSE '11 и более заказов'
        END AS segment
    FROM showcase
)
SELECT 
    segment,
    COUNT(user_id) AS total_users,
    ROUND(AVG(total_orders)::numeric, 2) AS avg_orders,
    ROUND(AVG(avg_order_cost)::numeric, 2) AS avg_order_cost
FROM user_segments
GROUP BY segment
ORDER BY 
    CASE segment
        WHEN '1 заказ' THEN 1
        WHEN '2-5 заказов' THEN 2
        WHEN '6-10 заказов' THEN 3
        WHEN '11 и более заказов' THEN 4
    END;

/* Напишите краткий комментарий с выводами по результатам задачи 1.
 * Основная масса клиентов разовые, соответственно поток выручки от постоянных клиентов отсутствует, лишь один клиент постоянно делает заказы.
*/


/* Задача 2. Ранжирование пользователей 
 * Отсортируйте пользователей, сделавших 3 заказа и более, по убыванию среднего чека покупки.  
 * Выведите 15 пользователей с самым большим средним чеком среди указанной группы.
*/

WITH top_regions AS (
    SELECT u.region 
    FROM ds_ecom.orders o 
    JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id 
    WHERE o.order_status IN ('Доставлено', 'Отменено') 
    GROUP BY u.region 
    ORDER BY COUNT(o.order_id) DESC 
    LIMIT 3
),
payment_features AS (
    SELECT 
    	order_id, 
    	FIRST_VALUE(payment_type) OVER (PARTITION BY order_id ORDER BY payment_sequential ASC) AS first_payment_type, 
    	MAX(CASE WHEN payment_installments > 1 THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_installment, 
    	MAX(CASE WHEN payment_type = 'промокод' THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_promo 
    FROM ds_ecom.order_payments
),
order_payments_agg AS (
    SELECT 
    	order_id, 
    	MAX(first_payment_type) AS first_payment_type, 
    	MAX(has_installment) AS has_installment, 
    	MAX(has_promo) AS has_promo 
    FROM payment_features 
    GROUP BY order_id
),
order_costs AS (
    SELECT 
    	o.order_id, 
    	SUM(oi.price + oi.delivery_cost) AS order_total_cost 
	FROM ds_ecom.orders o 
	JOIN ds_ecom.order_items oi ON o.order_id = oi.order_id
	WHERE o.order_status = 'Доставлено' 
	GROUP BY o.order_id
),
order_reviews_agg AS (
    SELECT 
    	order_id, 
    	AVG(CASE WHEN review_score > 5 THEN review_score / 10.0 ELSE review_score END) AS avg_review_score 
    	FROM ds_ecom.order_reviews 
    	GROUP BY order_id
),
order_level AS (
    SELECT 
    	o.order_id, 
    	u.user_id, 
    	u.region, 
    	o.order_status, 
    	o.order_purchase_ts, 
    	oc.order_total_cost, 
    	ora.avg_review_score, 
    	COALESCE(opa.has_installment, 0) AS has_installment, 
    	COALESCE(opa.has_promo, 0) AS has_promo, 
    	opa.first_payment_type 
    	FROM ds_ecom.orders o 
    	JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id 
    	LEFT JOIN order_costs oc ON o.order_id = oc.order_id 
    	LEFT JOIN order_reviews_agg ora ON o.order_id = ora.order_id 
    	LEFT JOIN order_payments_agg opa ON o.order_id = opa.order_id 
    	WHERE o.order_status IN ('Доставлено', 'Отменено') AND u.region IN (SELECT region FROM top_regions)
),
showcase AS (
    SELECT 
    	user_id, 
    	region, 
    	MIN(order_purchase_ts) AS first_order_ts, 
    	MAX(order_purchase_ts) AS last_order_ts, 
    	MAX(order_purchase_ts) - MIN(order_purchase_ts) AS lifetime, 
    	COUNT(order_id) AS total_orders, ROUND(AVG(avg_review_score)::numeric, 2) AS avg_order_rating, 
    	COUNT(avg_review_score) AS num_orders_with_rating, COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END) AS num_canceled_orders, 
    	ROUND((COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END)::numeric / COUNT(order_id)::numeric), 4) AS canceled_orders_ratio, 
    	COALESCE(SUM(order_total_cost), 0) AS total_order_costs, ROUND(COALESCE(AVG(order_total_cost), 0)::numeric, 2) AS avg_order_cost, 
    	SUM(has_installment) AS num_installment_orders, SUM(has_promo) AS num_orders_with_promo, MAX(CASE WHEN first_payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS used_money_transfer, 
    	MAX(has_installment) AS used_installments, 
    	MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
    	FROM order_level 
    	GROUP BY user_id, region
)
SELECT 
    user_id,
    region,
    total_orders,
    avg_order_cost
FROM showcase
WHERE total_orders >= 3
ORDER BY avg_order_cost DESC
LIMIT 15;

/* Напишите краткий комментарий с выводами по результатам задачи 2.
В этой группе наблюдается довольно плавный спад среднего чека от топ-1 до топ-15. 
Топовый средний чек равен 15000 рублей, что в 5 раз вышего общего среднего чека 
*/



/* Задача 3. Статистика по регионам. 
 * Для каждого региона подсчитайте:
 * - общее число клиентов и заказов;
 * - среднюю стоимость одного заказа;
 * - долю заказов, которые были куплены в рассрочку;
 * - долю заказов, которые были куплены с использованием промокодов;
 * - долю пользователей, совершивших отмену заказа хотя бы один раз.
*/

WITH top_regions AS (
    SELECT u.region 
    FROM ds_ecom.orders o 
    JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id 
    WHERE o.order_status IN ('Доставлено', 'Отменено') 
    GROUP BY u.region 
    ORDER BY COUNT(o.order_id) DESC 
    LIMIT 3
),
payment_features AS (
    SELECT 
    	order_id, 
    	FIRST_VALUE(payment_type) OVER (PARTITION BY order_id ORDER BY payment_sequential ASC) AS first_payment_type, 
    	MAX(CASE WHEN payment_installments > 1 THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_installment, 
    	MAX(CASE WHEN payment_type = 'промокод' THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_promo 
    FROM ds_ecom.order_payments
),
order_payments_agg AS (
    SELECT 
    	order_id, 
    	MAX(first_payment_type) AS first_payment_type, 
    	MAX(has_installment) AS has_installment, 
    	MAX(has_promo) AS has_promo 
    FROM payment_features 
    GROUP BY order_id
),
order_costs AS (
    SELECT 
    	o.order_id, 
    	SUM(oi.price + oi.delivery_cost) AS order_total_cost 
	FROM ds_ecom.orders o 
	JOIN ds_ecom.order_items oi ON o.order_id = oi.order_id
	WHERE o.order_status = 'Доставлено' 
	GROUP BY o.order_id
),
order_reviews_agg AS (
    SELECT 
    	order_id, 
    	AVG(CASE WHEN review_score > 5 THEN review_score / 10.0 ELSE review_score END) AS avg_review_score 
    	FROM ds_ecom.order_reviews 
    	GROUP BY order_id
),
order_level AS (
    SELECT 
    	o.order_id, 
    	u.user_id, 
    	u.region, 
    	o.order_status, 
    	o.order_purchase_ts, 
    	oc.order_total_cost, 
    	ora.avg_review_score, 
    	COALESCE(opa.has_installment, 0) AS has_installment, 
    	COALESCE(opa.has_promo, 0) AS has_promo, 
    	opa.first_payment_type 
    	FROM ds_ecom.orders o 
    	JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id 
    	LEFT JOIN order_costs oc ON o.order_id = oc.order_id 
    	LEFT JOIN order_reviews_agg ora ON o.order_id = ora.order_id 
    	LEFT JOIN order_payments_agg opa ON o.order_id = opa.order_id 
    	WHERE o.order_status IN ('Доставлено', 'Отменено') AND u.region IN (SELECT region FROM top_regions)
),
showcase AS (
    SELECT 
    	user_id, 
    	region, 
    	MIN(order_purchase_ts) AS first_order_ts, 
    	MAX(order_purchase_ts) AS last_order_ts, 
    	MAX(order_purchase_ts) - MIN(order_purchase_ts) AS lifetime, 
    	COUNT(order_id) AS total_orders, ROUND(AVG(avg_review_score)::numeric, 2) AS avg_order_rating, 
    	COUNT(avg_review_score) AS num_orders_with_rating, COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END) AS num_canceled_orders, 
    	ROUND((COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END)::numeric / COUNT(order_id)::numeric), 4) AS canceled_orders_ratio, 
    	COALESCE(SUM(order_total_cost), 0) AS total_order_costs, ROUND(COALESCE(AVG(order_total_cost), 0)::numeric, 2) AS avg_order_cost, 
    	SUM(has_installment) AS num_installment_orders, SUM(has_promo) AS num_orders_with_promo, MAX(CASE WHEN first_payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS used_money_transfer, 
    	MAX(has_installment) AS used_installments, 
    	MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
    	FROM order_level 
    	GROUP BY user_id, region
)
SELECT 
    region,
    COUNT(DISTINCT user_id) AS total_clients,
    SUM(total_orders) AS total_orders,
    ROUND((SUM(total_order_costs) / NULLIF(SUM(total_orders - num_canceled_orders), 0))::numeric, 2) AS avg_order_cost,
    ROUND((SUM(num_installment_orders)::numeric / SUM(total_orders)::numeric), 4) AS installment_orders_ratio,
    ROUND((SUM(num_orders_with_promo)::numeric / SUM(total_orders)::numeric), 4) AS promo_orders_ratio,
    ROUND((SUM(used_cancel)::numeric / COUNT(DISTINCT user_id)::numeric), 4) AS clients_with_cancel_ratio
FROM showcase
GROUP BY region;

/* Напишите краткий комментарий с выводами по результатам задачи 3.
 * Выводы:
 * 1. Москва лидирует по общему количеству клиентов и объему заказов среди всех исследуемых регионов.
 * 2. Доля использования финансовых инструментов (рассрочки и промокодов) незначительно различается по регионам, что указывает на единые потребительские паттерны в основных городах.
 * 3. Доля клиентов, отменялавших заказ хотя бы один раз, держится на стабильном уровне, что может говорить об одинаковой эффективности логистических сервисов во всех трех топовых регионах.
*/	




/* Задача 4. Активность пользователей по первому месяцу заказа в 2023 году
 * Разбейте пользователей на группы в зависимости от того, в какой месяц 2023 года они совершили первый заказ.
 * Для каждой группы посчитайте:
 * - общее количество клиентов, число заказов и среднюю стоимость одного заказа;
 * - средний рейтинг заказа;
 * - долю пользователей, использующих денежные переводы при оплате;
 * - среднюю продолжительность активности пользователя.
*/

WITH top_regions AS (
    SELECT u.region 
    FROM ds_ecom.orders o 
    JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id 
    WHERE o.order_status IN ('Доставлено', 'Отменено') 
    GROUP BY u.region 
    ORDER BY COUNT(o.order_id) DESC 
    LIMIT 3
),
payment_features AS (
    SELECT 
    	order_id, 
    	FIRST_VALUE(payment_type) OVER (PARTITION BY order_id ORDER BY payment_sequential ASC) AS first_payment_type, 
    	MAX(CASE WHEN payment_installments > 1 THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_installment, 
    	MAX(CASE WHEN payment_type = 'промокод' THEN 1 ELSE 0 END) OVER (PARTITION BY order_id) AS has_promo 
    FROM ds_ecom.order_payments
),
order_payments_agg AS (
    SELECT 
    	order_id, 
    	MAX(first_payment_type) AS first_payment_type, 
    	MAX(has_installment) AS has_installment, 
    	MAX(has_promo) AS has_promo 
    FROM payment_features 
    GROUP BY order_id
),
order_costs AS (
    SELECT 
    	o.order_id, 
    	SUM(oi.price + oi.delivery_cost) AS order_total_cost 
	FROM ds_ecom.orders o 
	JOIN ds_ecom.order_items oi ON o.order_id = oi.order_id
	WHERE o.order_status = 'Доставлено' 
	GROUP BY o.order_id
),
order_reviews_agg AS (
    SELECT 
    	order_id, 
    	AVG(CASE WHEN review_score > 5 THEN review_score / 10.0 ELSE review_score END) AS avg_review_score 
    	FROM ds_ecom.order_reviews 
    	GROUP BY order_id
),
order_level AS (
    SELECT 
    	o.order_id, 
    	u.user_id, 
    	u.region, 
    	o.order_status, 
    	o.order_purchase_ts, 
    	oc.order_total_cost, 
    	ora.avg_review_score, 
    	COALESCE(opa.has_installment, 0) AS has_installment, 
    	COALESCE(opa.has_promo, 0) AS has_promo, 
    	opa.first_payment_type 
    	FROM ds_ecom.orders o 
    	JOIN ds_ecom.users u ON o.buyer_id = u.buyer_id 
    	LEFT JOIN order_costs oc ON o.order_id = oc.order_id 
    	LEFT JOIN order_reviews_agg ora ON o.order_id = ora.order_id 
    	LEFT JOIN order_payments_agg opa ON o.order_id = opa.order_id 
    	WHERE o.order_status IN ('Доставлено', 'Отменено') AND u.region IN (SELECT region FROM top_regions)
),
showcase AS (
    SELECT 
    	user_id, 
    	region, 
    	MIN(order_purchase_ts) AS first_order_ts, 
    	MAX(order_purchase_ts) AS last_order_ts, 
    	MAX(order_purchase_ts) - MIN(order_purchase_ts) AS lifetime, 
    	COUNT(order_id) AS total_orders, ROUND(AVG(avg_review_score)::numeric, 2) AS avg_order_rating, 
    	COUNT(avg_review_score) AS num_orders_with_rating, COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END) AS num_canceled_orders, 
    	ROUND((COUNT(CASE WHEN order_status = 'Отменено' THEN 1 END)::numeric / COUNT(order_id)::numeric), 4) AS canceled_orders_ratio, 
    	COALESCE(SUM(order_total_cost), 0) AS total_order_costs, ROUND(COALESCE(AVG(order_total_cost), 0)::numeric, 2) AS avg_order_cost, 
    	SUM(has_installment) AS num_installment_orders, SUM(has_promo) AS num_orders_with_promo, MAX(CASE WHEN first_payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS used_money_transfer, 
    	MAX(has_installment) AS used_installments, 
    	MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
    	FROM order_level 
    	GROUP BY user_id, region
)
SELECT 
    DATE_TRUNC('month', first_order_ts) AS cohort_month,
    COUNT(DISTINCT user_id) AS total_clients,
    SUM(total_orders) AS total_orders,
    ROUND((SUM(total_order_costs) / NULLIF(SUM(total_orders - num_canceled_orders), 0))::numeric, 2) AS avg_order_cost,
    ROUND(AVG(avg_order_rating)::numeric, 2) AS avg_cohort_rating,
    ROUND((SUM(used_money_transfer)::numeric / COUNT(DISTINCT user_id)::numeric), 4) AS money_transfer_user_ratio,
    AVG(lifetime) AS avg_lifetime
FROM showcase
WHERE first_order_ts >= '2023-01-01' AND first_order_ts < '2024-01-01'
GROUP BY DATE_TRUNC('month', first_order_ts)
ORDER BY cohort_month;

/* Напишите краткий комментарий с выводами по результатам задачи 4.
 * Выводы:
 * 1. Когортный анализ за 2023 год показывает динамику привлечения новых клиентов по месяцам.
 * 2. У ранних когорт (начало 2023 года) показатель продолжительности жизни (lifetime) в среднем выше, так как у них было больше времени для совершения повторных покупок.
 * 3. Средний рейтинг заказов и средний чек остаются стабильными от месяца к месяцу, что свидетельствует об устойчивом качестве сервиса в течение всего года.
*/