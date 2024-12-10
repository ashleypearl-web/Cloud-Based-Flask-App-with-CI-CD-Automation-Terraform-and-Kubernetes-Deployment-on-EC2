-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS employees_db;

-- Use the employees_db database
USE employees_db;

-- Drop the table if it already exists to ensure a clean slate
DROP TABLE IF EXISTS employees;

-- Create the employees table
CREATE TABLE employees (
    id INT AUTO_INCREMENT PRIMARY KEY,  -- Auto-incrementing primary key
    employee_id VARCHAR(80) NOT NULL UNIQUE,  -- Employee ID (unique)
    name VARCHAR(100) NOT NULL,  -- Name of the employee
    role VARCHAR(50) NOT NULL,  -- Role of the employee
    email VARCHAR(120) NOT NULL UNIQUE,  -- Employee's email (unique)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,  -- Timestamp for creation
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP  -- Timestamp for last update
);

-- Insert some sample employees
INSERT INTO employees (employee_id, name, role, email)
VALUES
    ('EMP001', 'John Doe', 'Engineer', 'john.doe@example.com'),
    ('EMP002', 'Jane Smith', 'Manager', 'jane.smith@example.com'),
    ('EMP003', 'Alice Johnson', 'HR', 'alice.johnson@example.com'),
    ('EMP004', 'Bob Brown', 'Sales', 'bob.brown@example.com');