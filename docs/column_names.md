# Cleaned column names

**Status:** agreed on Nov 23, 2026 (Suchita, dbt owner). Gouri and Sourav use these names in the staging views. Any later change goes through a pull request.

**What this is:** the column names and types in the cleaned staging views (`fd_staging.stg_*`). The dims, `fct_orders`, the summary tables and Phil's Text-to-SQL all use these names, so we agree on them once.

**Source:** the dataset comes from Darshil Parmar's "Zomato AI Data Analytics" project ([video](https://www.youtube.com/watch?v=kYwaNMQ3XT8), [code](https://github.com/darshilparmar/zomato-ai-data-engineering-end-to-end-project)).

---

## 1. Naming rules

- Lowercase `snake_case`, in English, with no abbreviations except `id`.
- Keys are named `<thing>_id`: `user_id`, `restaurant_id`, `food_id`, `order_id`, `order_item_id`, `review_id`. They have the same name in every table, so joins are obvious. (The raw files use `r_id`, `id` and `f_id`.)
- Numeric IDs are `INT64`. Food IDs (`fd0`) and menu IDs (`mn0`) contain letters, so they stay `STRING`.
- Amounts are `NUMERIC` in rupees (₹), with no currency symbol.
- Dates are `DATE`, and date + time is `DATETIME` in India time.
- Yes/no columns start with `is_`, for example `is_veg`.

## 2. General cleaning rules (all views)

- Convert with `SAFE_CAST`, so a bad value becomes empty instead of failing. Then the **failed-conversion check** finds it: the raw value isn't empty, but the cleaned value is.
- **Values with decimals** like `29.0`, `4.0`, `40.0`: `SAFE_CAST('29.0' AS INT64)` gives an empty value. Cast to `FLOAT64` (or `NUMERIC`) first, and for a whole number use `CAST(SAFE_CAST(x AS FLOAT64) AS INT64)`.
- Text: `TRIM` it, and turn empty text into NULL with `NULLIF(TRIM(x), '')`.
- Never use `row_index`; it's the blank pandas column.

## 3. Table by table

### stg_orders (from `fd_raw.orders`)
| Raw column | Cleaned name | Type | Rule |
|---|---|---|---|
| order_id | `order_id` | INT64 | |
| order_timestamp | `order_datetime` | DATETIME | India time; no conversion (**Decision 1**) |
| order_date | `order_date` | DATE | Should equal the date part of `order_datetime` |
| user_id | `user_id` | INT64 | |
| r_id | `restaurant_id` | INT64 | |
| restaurant_city | `area` | STRING | Text before the last comma; NULL if there's no comma (**Decision 2**) |
| restaurant_city | `city` | STRING | Text after the last comma: `Ameerpet,Hyderabad` → Hyderabad |
| cuisine | `cuisines` | STRING | Full list as given: `Sweets,Desserts` (**Decision 3**) |
| cuisine | `main_cuisine` | STRING | First item in the list: Sweets |
| items_count | `items_count` | INT64 | Number of item lines |
| sales_qty | `sales_qty` | INT64 | Total units |
| subtotal | `subtotal` | NUMERIC | ₹ |
| discount | `discount` | NUMERIC | ₹ |
| delivery_fee | `delivery_fee` | NUMERIC | ₹ |
| gst | `gst` | NUMERIC | ₹ |
| sales_amount | `sales_amount` | NUMERIC | ₹, what the customer pays |
| currency | `currency` | STRING | `UPPER(TRIM(...))`; expected to be INR |
| payment_method | `payment_method` | STRING | Seen so far: UPI, Card, COD, Wallet |
| order_status | `order_status` | STRING | `LOWER(TRIM(...))`: delivered, cancelled, refunded |
| (new) | `is_delivered` | BOOL | `order_status = 'delivered'`. Makes GMV and delivery queries simpler. |
| customer_rating | `customer_rating` | FLOAT64 | `4.0` → 4.0; empty for many orders |
| delivery_time_min | `delivery_time_min` | INT64 | `29.0` → 29; empty for cancelled and refunded orders |

Also remove exact duplicate rows.

### stg_order_items (from `fd_raw.order_items`)
| Raw column | Cleaned name | Type | Rule |
|---|---|---|---|
| order_item_id | `order_item_id` | INT64 | Unique key. The same dish can appear twice in one order, so `order_id` + `food_id` is **not** unique. |
| order_id | `order_id` | INT64 | |
| r_id | `restaurant_id` | INT64 | |
| f_id | `food_id` | STRING | e.g. `fd538029` |
| price | `price` | NUMERIC | ₹ per unit |
| quantity | `quantity` | INT64 | |
| line_amount | `line_amount` | NUMERIC | `price × quantity` |

### stg_reviews (from `fd_raw.reviews`)
| Raw column | Cleaned name | Type | Rule |
|---|---|---|---|
| review_id | `review_id` | INT64 | |
| order_id | `order_id` | INT64 | |
| user_id | `user_id` | INT64 | |
| restaurant_id | `restaurant_id` | INT64 | |
| rating | `rating` | INT64 | 1–5 |
| comment | `review_text` | STRING | Trimmed (**Decision 4**) |
| review_date | `review_date` | DATE | |
| (new) | `rating_label` | STRING | 1–2 negative, 3 neutral, 4–5 positive (used by the NLP model) |

Some reviews have no text. Keep them here, because they still have a rating. Gemini tagging, embeddings and the NLP model filter them out with `review_text IS NOT NULL`.

### stg_users (from `fd_raw.users`, after Gouri's cleaning)
| Raw column | Cleaned name | Type | Rule |
|---|---|---|---|
| user_id | `user_id` | INT64 | |
| age | `age` | INT64 | |
| gender | `gender` | STRING | Trimmed |
| marital_status | `marital_status` | STRING | Trimmed |
| occupation | `occupation` | STRING | Trimmed |
| monthly_income | `monthly_income` | STRING | Income bands stay as text; check the values while profiling |
| educational_qualifications | `education` | STRING | Shorter name |
| family_size | `family_size` | INT64 | |

There is no signup date, so "orders before signup" can't be tested.

### stg_restaurants (from `fd_raw.restaurants`)
| Raw column | Cleaned name | Type | Rule |
|---|---|---|---|
| id | `restaurant_id` | INT64 | |
| name | `restaurant_name` | STRING | Trimmed |
| city | `area`, `city` | STRING | Same split as in stg_orders |
| rating | `rating` | FLOAT64 | `--` → empty |
| rating_count | `rating_count` | INT64 | The number at the start: `50+ ratings` → 50, `Too Few Ratings` → empty |
| cost | `cost_for_two` | NUMERIC | `₹ 200` → 200 |
| cuisine | `cuisines`, `main_cuisine` | STRING | Same rule as in stg_orders |
| address | `address` | STRING | Trimmed |
| lic_no, link, menu, row_index | (dropped) | | Not used (**Decision 5**) |

### stg_food (from `fd_raw.food`)
| Raw column | Cleaned name | Type | Rule |
|---|---|---|---|
| f_id | `food_id` | STRING | e.g. `fd0` |
| item | `food_name` | STRING | Trimmed |
| veg_or_non_veg | `is_veg` | BOOL | TRUE when the value is `Veg`; check the distinct values first (**Decision 6**) |
| row_index | (dropped) | | |

### stg_menu_items (from `fd_raw.menu`)
| Raw column | Cleaned name | Type | Rule |
|---|---|---|---|
| (new) | `menu_item_id` | STRING | `restaurant_id-food_id`, e.g. `158203-fd0`. Unique key (**Decision 7**) |
| r_id | `restaurant_id` | INT64 | |
| f_id | `food_id` | STRING | |
| cuisine | `cuisines` | STRING | As given |
| price | `price` | NUMERIC | `40.0` → 40 |
| menu_id, row_index | (dropped) | | `menu_id` isn't unique and order items don't use it |

Keep **one row per restaurant + food**: the raw menu has duplicates, for example restaurant 158203 + `fd0` appears twice. If the prices differ, take the lowest and count how often that happens.

### Messy rows in the 4 real files

The restaurant, user, food and menu files come from real scraped data and have some broken rows. Each cleaning view drops them:

| View | Drop rows where |
|---|---|
| stg_restaurants | `restaurant_id` isn't a number |
| stg_users | `user_id` isn't a number |
| stg_food | `food_id` is empty |
| stg_menu_items | `restaurant_id` isn't a number, or `price` is empty or 0 |

Count the dropped rows in the failed-conversion check, so we know how many there are.

## 4. Keys the later tables use

| Table | Key | Links to |
|---|---|---|
| `dim_users` | `user_id` | |
| `dim_restaurants` | `restaurant_id` | |
| `dim_menu_items` | `menu_item_id` | `dim_restaurants` (`restaurant_id`) |
| `dim_date` | `date_day` | |
| `fct_orders` | `order_id` | `user_id` → dim_users, `restaurant_id` → dim_restaurants, `order_date` → dim_date.date_day |
| `stg_order_items` | `order_item_id` | `order_id` → fct_orders, `restaurant_id` + `food_id` → dim_menu_items |

## 5. Decisions made

| # | Question | Decision |
|---|---|---|
| 1 | Rename `order_timestamp`, and choose its type | `order_datetime`, DATETIME, India time |
| 2 | Split the restaurant city | `area` + `city`, with `city` used for the dashboard filter |
| 3 | Cuisine | Keep the full list (`cuisines`) and add `main_cuisine` for filters |
| 4 | Rename the review `comment` | `review_text` (Phil's tagging script must use the same name) |
| 5 | Drop unused restaurant columns | Drop `lic_no`, `link`, `menu` |
| 6 | Veg column | `is_veg` (TRUE/FALSE) |
| 7 | Menu item key | `menu_item_id` = restaurant + food, one row each |
| 8 | Customer key name | Keep **`user_id`**, the same as in our raw files and reviews |
