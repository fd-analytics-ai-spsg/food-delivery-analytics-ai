-- =====================================================================
-- Raw tables (dataset fd_raw): exact copies of the CSV files.
-- Every column is STRING; types are converted later in the fd_staging views.
-- Columns follow the CSV header order (BigQuery loads CSV columns by position).
-- row_index: the unnamed row-number column (0, 1, 2...) that pandas added to
--            some files. Not real data; the staging views don't use it.
-- users: to be added once the cleaned users.csv is ready.
-- =====================================================================

-- food.csv (has the blank first column)
CREATE TABLE fd_raw.food (
  row_index       STRING,
  f_id            STRING,
  item            STRING,
  veg_or_non_veg  STRING
);

-- menu.csv (has the blank first column)
CREATE TABLE fd_raw.menu (
  row_index  STRING,
  menu_id    STRING,
  r_id       STRING,
  f_id       STRING,
  cuisine    STRING,
  price      STRING
);

-- restaurant.csv (has the blank first column; the table name is plural - restaurants to match the sources file)
CREATE TABLE fd_raw.restaurants (
  row_index     STRING,
  id            STRING,
  name          STRING,
  city          STRING,
  rating        STRING,
  rating_count  STRING,
  cost          STRING,
  cuisine       STRING,
  lic_no        STRING,
  link          STRING,
  address       STRING,
  menu          STRING
);

-- reviews.csv (no blank first column)
CREATE TABLE fd_raw.reviews (
  -- row_index STRING,
  review_id      STRING,
  order_id       STRING,
  user_id        STRING,
  restaurant_id  STRING,
  rating         STRING,
  comment        STRING,
  review_date    STRING
);

-- orders.csv (check the header again after the upload)
CREATE TABLE fd_raw.orders (
  -- row_index STRING,
  order_id           STRING,
  order_timestamp    STRING,
  order_date         STRING,
  user_id            STRING,
  r_id               STRING,
  restaurant_city    STRING,
  cuisine            STRING,
  items_count        STRING,
  sales_qty          STRING,
  subtotal           STRING,
  discount           STRING,
  delivery_fee       STRING,
  gst                STRING,
  sales_amount       STRING,
  currency           STRING,
  payment_method     STRING,
  order_status       STRING,
  customer_rating    STRING,
  delivery_time_min  STRING
);

-- order_items.csv (check the header again after the upload)
CREATE TABLE fd_raw.order_items (
  -- row_index STRING,
  order_item_id  STRING,
  order_id       STRING,
  r_id           STRING,
  f_id           STRING,
  price          STRING,
  quantity       STRING,
  line_amount    STRING
);
