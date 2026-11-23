# Metric definitions

**Status:** draft for the Nov 23 check-in, checked against the video's code. Rows marked **Decision** need the team's OK; the recommended option is filled in.

**Why this file exists:** the dashboard, the Ask view (Text-to-SQL), the tests and the slides must all calculate each number the same way.

**Source:** the dataset comes from Darshil Parmar's "Zomato AI Data Analytics" project ([video](https://www.youtube.com/watch?v=kYwaNMQ3XT8), [code](https://github.com/darshilparmar/zomato-ai-data-engineering-end-to-end-project)). Where our definition is the same as that project's, it says *(same as the video)*.

> All results come from simulated data. Label them that way in the dashboard and slides.

---

## 1. Ground rules

- **Currency:** every amount is in Indian rupees (₹, INR). After the load, check that no order uses another currency.
- **Time zone:** `order_datetime` is local India time (IST) and is never converted. Order times fall between about 7 am and 11 pm, which fits local time.
- **Which date:** order metrics use `order_date`; review metrics use `review_date`. The orders run from 2024 to 2026; the video's calendar table covers 2024-01-01 to 2026-12-31.
- **Order status** (lowercase after cleaning): `delivered`, `cancelled`, `refunded`. The video's tests allow exactly these 3 values.
- **Completed order** = `order_status = 'delivered'`.
  - Cancelled and refunded orders still have amounts in the data, so **every money metric must filter on status**.
  - Cancelled and refunded orders have no delivery time and no customer rating.
  - The customer rating is optional, so some delivered orders don't have one either.

## 2. What the amount columns mean

Checked on the first rows of `orders.csv` and `order_items.csv`; confirm on the full data after the load.

| Column | Meaning |
|---|---|
| `subtotal` | Food value before the discount. Equals the sum of `line_amount` for the order's items. |
| `discount` | Discount on the order |
| `delivery_fee` | Delivery charge |
| `gst` | Tax: 5% of `subtotal` (before the discount), rounded |
| `sales_amount` | What the customer pays: `subtotal - discount + delivery_fee + gst` |
| `items_count` | Number of item lines in the order. The same dish can appear on two lines. |
| `sales_qty` | Total units: the sum of `quantity` over the order's items |
| `line_amount` (order items) | `price × quantity` |

## 3. Order metrics

| Metric | Plain meaning | How to calculate | Orders included |
|---|---|---|---|
| Orders | Orders placed | `COUNT(order_id)` | All |
| Delivered orders | Orders that reached the customer | `COUNTIF(order_status = 'delivered')` | All |
| **GMV** | Money customers paid for delivered orders: after discounts, including delivery fee and GST *(same as the video)* | `SUM(sales_amount)` | Delivered |
| Net food sales | Food value after discounts, without delivery fee and GST | `SUM(subtotal - discount)` | Delivered |
| **AOV** (average order value) | Average amount paid per delivered order *(same as the video)* | `SUM(sales_amount) / COUNT(order_id)` | Delivered |
| Items sold | Units sold | `SUM(sales_qty)` | Delivered |
| Discount rate | Share of food value given as discount | `SUM(discount) / SUM(subtotal)` | Delivered |
| **Cancellation rate** | Share of orders cancelled *(same as the video)* | `COUNTIF(order_status = 'cancelled') / COUNT(*)` | All |
| Refund rate | Share of orders refunded | `COUNTIF(order_status = 'refunded') / COUNT(*)` | All |
| **Delivery time** (median and 90th percentile) | Typical and slow delivery times, in minutes | `APPROX_QUANTILES(delivery_time_min, 100)[OFFSET(50)]` and `[OFFSET(90)]` | Delivered |
| **On-time rate** | Share of deliveries within the SLA (45 min) | `COUNTIF(delivery_time_min <= 45) / COUNT(delivery_time_min)` | Delivered |
| Average customer rating | Average rating given on orders | `AVG(customer_rating)` | Delivered, with a rating |
| Active customers | Customers with at least one delivered order in the period | `COUNT(DISTINCT user_id)` | Delivered |
| Cohort month | Month of a customer's first delivered order | `DATE_TRUNC(MIN(order_date), MONTH)` per `user_id` | Delivered |
| Retention, month N | % of a cohort who have a delivered order N months after their cohort month | cohort users with a delivered order in month N ÷ cohort size (month 0 = 100%) | Delivered |

## 4. Review metrics

| Metric | Plain meaning | How to calculate | Reviews included |
|---|---|---|---|
| Average review rating | Average star rating (1–5) | `AVG(rating)` | All |
| Tagged share | How many reviews Gemini has tagged | `COUNTIF(is_tagged) / COUNT(*)` | All |
| Sentiment share | Share of reviews tagged positive, neutral or negative | count per sentiment ÷ tagged reviews | Tagged |
| Negative review rate | Share of tagged reviews that are negative | `COUNTIF(sentiment = 'negative') / COUNTIF(is_tagged)` | Tagged |
| Topic share | Share of reviews per topic | count per topic ÷ tagged reviews | Tagged |
| Rating label (for the NLP model) | Turns stars into a sentiment label | 1–2 = negative, 3 = neutral, 4–5 = positive | All |

**Topic list** (Phil's, approved at the check-in). A good starting point is the video's list: food quality, delivery, pricing, service, packaging, other.

Some reviews have no text. They still count in the average review rating, but Gemini tagging, embeddings and the NLP model skip them.

**Delivery time vs. negative reviews (research question 3):** a **late delivery** is one that took longer than 45 min. Join the reviews to the orders on `order_id`, then compare the negative review rate for late and on-time deliveries.

## 5. Breakdowns (dashboard filters)

| Breakdown | Rule | Example |
|---|---|---|
| City | Text after the last comma in the restaurant city | `Ameerpet,Hyderabad` → Hyderabad; `Panipat` → Panipat |
| Main cuisine | First cuisine in the list | `Sweets,Desserts` → Sweets |
| Hour of day | `EXTRACT(HOUR FROM order_datetime)`, India time | 19 = 7–8 pm |
| Day / week / month | From `order_date` | |

## 6. Where each metric lives

| Summary table | Metrics | One row per |
|---|---|---|
| `mart_daily_gmv` | orders, delivered orders, GMV, net food sales, items sold (AOV is worked out from these) | day × city × main cuisine |
| `mart_delivery_sla` | median and p90 delivery time, on-time rate | day × city |
| `mart_cancellations` | orders, cancelled, refunded, cancellation rate, refund rate | day × city × hour |
| `mart_user_cohorts` | cohort size, retention by month | cohort month × months since first order |
| `mart_review_insights` | review rating, Gemini sentiment and topic, model sentiment, delivery time | review |

> [!IMPORTANT]
> **When adding up rows** (for example, a whole month or all cities):
> - Never average averages or rates. Recompute them from the totals: AOV = `SUM(gmv) / SUM(delivered_orders)`, cancellation rate = `SUM(cancelled) / SUM(orders)`.
> - Medians and p90 can't be combined across rows at all. Calculate them from `fct_orders` at the level you need.
>
> This matters for the dashboard and for Phil's Text-to-SQL prompt.

## 7. Decisions for the check-in

| # | Decision | Recommended | Why |
|---|---|---|---|
| 1 | Does GMV include the delivery fee and GST? | **Yes:** GMV = `SUM(sales_amount)` | It's what customers actually paid, and the video's project defines it the same way. Net food sales is also available if someone wants food value only. |
| 2 | How do refunded orders count? | **Not completed:** left out of GMV, AOV and delivery metrics, and shown as a refund rate | The money was returned. The video also counts only delivered orders in GMV. |
| 3 | What is the cancellation rate divided by? | **All orders** | Simple, standard, and the same as the video |
| 4 | SLA minutes | **45** | In the first 36 delivered orders, 86% arrived within 45 min but only 47% within 30. It matches Gouri's original buckets: fast < 25, normal 25–45, late > 45. |
| 5 | Cohorts are based on | **The first delivered order** | Consistent with "completed order" |
| 6 | Time zone | **India time, no conversion** | See the ground rules |

## 8. Checks to run after the load (they confirm the rules above)

- [ ] Row counts match the video's numbers: orders = 10,000,000, order items ≈ 23 million, reviews = 300,000, restaurants ≈ 148,541
- [ ] Orders with a currency other than INR = 0
- [ ] `sales_amount = subtotal - discount + delivery_fee + gst` on every order
- [ ] Full list of `order_status` values, and delivery time is empty only for cancelled and refunded orders
- [ ] `order_date` = the date part of `order_datetime`
- [ ] `items_count` = number of order item rows, `sales_qty` = sum of `quantity`, `subtotal` = sum of `line_amount`
- [ ] Median and p90 delivery time on the full data, to confirm the 45-minute SLA
