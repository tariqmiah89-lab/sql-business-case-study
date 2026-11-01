DROP TABLE IF EXISTS order_items; DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;    DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
  customer_id INTEGER PRIMARY KEY, region TEXT, signup_date TEXT, channel TEXT);
CREATE TABLE products (
  product_id INTEGER PRIMARY KEY, product_name TEXT, category TEXT, unit_price REAL);
CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY, customer_id INTEGER REFERENCES customers(customer_id),
  order_date TEXT, discount_rate REAL, payment_method TEXT);
CREATE TABLE order_items (
  order_id INTEGER REFERENCES orders(order_id), product_id INTEGER REFERENCES products(product_id),
  quantity INTEGER);
