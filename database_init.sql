-- Run this as postgres user: sudo -u postgres psql -f init.sql

-- 1. Create database if not exists
CREATE DATABASE productdb;

-- 2. Connect to productdb
\c productdb;

-- 3. Create products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    productname VARCHAR(255) NOT NULL,
    price NUMERIC(10, 2) NOT NULL
);

-- 4. Insert sample products
INSERT INTO products (productname, price) VALUES 
('Laptop', 74999.00),
('Wireless Mouse', 899.50),
('Mechanical Keyboard', 2999.00)
ON CONFLICT DO NOTHING;
