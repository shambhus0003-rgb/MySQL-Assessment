USE ecomm;
SET SQL_SAFE_UPDATES = 0;
--- Step 1: Data Cleaning ---
-- 1. Impute mean for WarehouseToHome (rounded to nearest integer)
UPDATE customer_churn
SET WarehouseToHome = (
    SELECT ROUND(AVG(WarehouseToHome)) 
    FROM (SELECT WarehouseToHome FROM customer_churn WHERE WarehouseToHome IS NOT NULL) AS temp
)
WHERE WarehouseToHome IS NULL;

-- 2. Impute mean for HourSpendOnApp
UPDATE customer_churn
SET HourSpendOnApp = (
    SELECT ROUND(AVG(HourSpendOnApp)) 
    FROM (SELECT HourSpendOnApp FROM customer_churn WHERE HourSpendOnApp IS NOT NULL) AS temp
)
WHERE HourSpendOnApp IS NULL;

-- 3. Impute mean for OrderAmountHikeFromlastYear
UPDATE customer_churn
SET OrderAmountHikeFromlastYear = (
    SELECT ROUND(AVG(OrderAmountHikeFromlastYear)) 
    FROM (SELECT OrderAmountHikeFromlastYear FROM customer_churn WHERE OrderAmountHikeFromlastYear IS NOT NULL) AS temp
)
WHERE OrderAmountHikeFromlastYear IS NULL;

-- 4. Impute mean for DaySinceLastOrder
UPDATE customer_churn
SET DaySinceLastOrder = (
    SELECT ROUND(AVG(DaySinceLastOrder)) 
    FROM (SELECT DaySinceLastOrder FROM customer_churn WHERE DaySinceLastOrder IS NOT NULL) AS temp
)
WHERE DaySinceLastOrder IS NULL;

-- 5. Impute mode values for Tenure, CouponUsed, OrderCount
UPDATE customer_churn 
SET Tenure = 0 WHERE Tenure IS NULL;

UPDATE customer_churn 
SET CouponUsed = 1 WHERE CouponUsed IS NULL;

UPDATE customer_churn 
SET OrderCount = 2 WHERE OrderCount IS NULL;

-- 6. Delete rows where WarehouseToHome is greater than 100
DELETE FROM customer_churn 
WHERE WarehouseToHome > 100;

-- 7. Standardize string inconsistencies
UPDATE customer_churn 
SET PreferredLoginDevice = 'Mobile Phone' 
WHERE PreferredLoginDevice = 'Phone';

UPDATE customer_churn 
SET PreferedOrderCat = 'Mobile Phone' 
WHERE PreferedOrderCat = 'Mobile';

UPDATE customer_churn 
SET PreferredPaymentMode = 'Cash on Delivery' 
WHERE PreferredPaymentMode = 'COD';

UPDATE customer_churn 
SET PreferredPaymentMode = 'Credit Card' 
WHERE PreferredPaymentMode = 'CC';

--- Step 2: Data Transformation ----
-- Rename columns for consistency and spelling correction
ALTER TABLE customer_churn 
CHANGE COLUMN PreferedOrderCat PreferredOrderCat VARCHAR(20);

ALTER TABLE customer_churn 
CHANGE COLUMN HourSpendOnApp HoursSpentOnApp INT;

-- Create new derived columns
ALTER TABLE customer_churn 
ADD COLUMN ComplaintReceived VARCHAR(5),
ADD COLUMN ChurnStatus VARCHAR(20);

UPDATE customer_churn 
SET ComplaintReceived = CASE WHEN Complain = 1 THEN 'Yes' ELSE 'No' END,
    ChurnStatus = CASE WHEN Churn = 1 THEN 'Churned' ELSE 'Active' END;

-- Drop original bit columns
ALTER TABLE customer_churn 
DROP COLUMN Churn,
DROP COLUMN Complain;

--- Step 3: Data Exploration and Analysis ---
-- 1. Retrieve the count of churned and active customers
SELECT ChurnStatus, COUNT(*) AS CustomerCount 
FROM customer_churn 
GROUP BY ChurnStatus;

-- 2. Display the average tenure and total cashback amount of customers who churned
SELECT AVG(Tenure) AS AvgTenure, SUM(CashbackAmount) AS TotalCashback 
FROM customer_churn 
WHERE ChurnStatus = 'Churned';

-- 3. Determine the percentage of churned customers who complained
SELECT 
    (SUM(CASE WHEN ComplaintReceived = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*) AS ComplaintPercentage 
FROM customer_churn 
WHERE ChurnStatus = 'Churned';

-- 4. Identify the city tier with the highest number of churned customers whose preferred order category is Laptop & Accessory
SELECT CityTier, COUNT(*) AS ChurnedCount 
FROM customer_churn 
WHERE ChurnStatus = 'Churned' AND PreferredOrderCat = 'Laptop & Accessory' 
GROUP BY CityTier 
ORDER BY ChurnedCount DESC 
LIMIT 1;

-- 5. Identify the most preferred payment mode among active customers
SELECT PreferredPaymentMode, COUNT(*) AS ActiveCount 
FROM customer_churn 
WHERE ChurnStatus = 'Active' 
GROUP BY PreferredPaymentMode 
ORDER BY ActiveCount DESC 
LIMIT 1;

-- 6. Calculate the total order amount hike from last year for customers who are single and prefer mobile phones for ordering
SELECT SUM(OrderAmountHikeFromlastYear) AS TotalOrderHike 
FROM customer_churn 
WHERE MaritalStatus = 'Single' AND PreferredLoginDevice = 'Mobile Phone';

-- 7. Find the average number of devices registered among customers who used UPI as their preferred payment mode
SELECT AVG(NumberOfDeviceRegistered) AS AvgDevicesRegistered 
FROM customer_churn 
WHERE PreferredPaymentMode = 'UPI';

-- 8. Determine the city tier with the highest number of customers
SELECT CityTier, COUNT(*) AS TotalCustomers 
FROM customer_churn 
GROUP BY CityTier 
ORDER BY TotalCustomers DESC 
LIMIT 1;

-- 9. Identify the gender that utilized the highest number of coupons
SELECT Gender, SUM(CouponUsed) AS TotalCouponsUsed 
FROM customer_churn 
GROUP BY Gender 
ORDER BY TotalCouponsUsed DESC 
LIMIT 1;

-- 10. List the number of customers and the maximum hours spent on the app in each preferred order category
SELECT PreferredOrderCat, COUNT(*) AS CustomerCount, MAX(HoursSpentOnApp) AS MaxHoursSpent 
FROM customer_churn 
GROUP BY PreferredOrderCat;

-- 11. Calculate the total order count for customers who prefer using credit cards and have the maximum satisfaction score
SELECT SUM(OrderCount) AS TotalOrders 
FROM customer_churn 
WHERE PreferredPaymentMode = 'Credit Card' 
  AND SatisfactionScore = (SELECT MAX(SatisfactionScore) FROM customer_churn);

-- 12. What is the average satisfaction score of customers who have complained?
SELECT AVG(SatisfactionScore) AS AvgSatisfactionScore 
FROM customer_churn 
WHERE ComplaintReceived = 'Yes';

-- 13. List the preferred order category among customers who used more than 5 coupons
SELECT DISTINCT PreferredOrderCat 
FROM customer_churn 
WHERE CouponUsed > 5;

-- 14. List the top 3 preferred order categories with the highest average cashback amount
SELECT PreferredOrderCat, AVG(CashbackAmount) AS AvgCashback 
FROM customer_churn 
GROUP BY PreferredOrderCat 
ORDER BY AvgCashback DESC 
LIMIT 3;

-- 15. Find the preferred payment modes of customers whose average tenure is 10 months and have placed more than 500 orders
SELECT PreferredPaymentMode 
FROM customer_churn 
GROUP BY PreferredPaymentMode 
HAVING AVG(Tenure) = 10 AND SUM(OrderCount) > 500;

-- 16. Categorize customers based on distance and display the churn status breakdown
SELECT 
    CASE 
        WHEN WarehouseToHome <= 5 THEN 'Very Close Distance'
        WHEN WarehouseToHome <= 10 THEN 'Close Distance'
        WHEN WarehouseToHome <= 15 THEN 'Moderate Distance'
        ELSE 'Far Distance' 
    END AS DistanceCategory,
    ChurnStatus,
    COUNT(*) AS CustomerCount
FROM customer_churn
GROUP BY DistanceCategory, ChurnStatus
ORDER BY DistanceCategory, ChurnStatus;

-- 17. List the customer’s order details who are married, live in City Tier-1, and order counts are more than average
SELECT CustomerID, Tenure, OrderCount, CityTier, MaritalStatus 
FROM customer_churn 
WHERE MaritalStatus = 'Married' 
  AND CityTier = 1 
  AND OrderCount > (SELECT AVG(OrderCount) FROM customer_churn);

-- 18. Customer Returns Table Operation & Joined Analysis
CREATE TABLE customer_returns (
    ReturnID INT PRIMARY KEY,
    CustomerID INT,
    ReturnDate DATE,
    RefundAmount INT
);

INSERT INTO customer_returns (ReturnID, CustomerID, ReturnDate, RefundAmount) VALUES
(1001, 50022, '2023-01-01', 2130),
(1002, 50316, '2023-01-23', 2000),
(1003, 51099, '2023-02-14', 2290),
(1004, 52321, '2023-03-08', 2510),
(1005, 52928, '2023-03-20', 3000),
(1006, 53749, '2023-04-17', 1740),
(1007, 54206, '2023-04-21', 3250),
(1008, 54838, '2023-04-30', 1990);

-- Display return details along with customer details for those who churned and complained
SELECT r.*, c.* 
FROM customer_returns r
JOIN customer_churn c ON r.CustomerID = c.CustomerID
WHERE c.ChurnStatus = 'Churned' AND c.ComplaintReceived = 'Yes';

SET SQL_SAFE_UPDATES = 1;