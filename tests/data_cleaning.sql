-- Check for Nulls or Duplicates in Primary Key
-- Expectation: No Result
--===============================================================================================
SELECT 
	cst_id,
	COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL

--for silver
SELECT 
	cst_id,
	COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL

-- WE CAN SEE THERE ARE MULTIPLE SUPLICATE VALUES SO WE ARE GOING TAKE EARLIEST BY RANKING IT BASED ON DATE

SELECT * FROM(
SELECT *,
	ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM bronze.crm_cust_info
WHERE cst_id IS NOT NULL) AS t
WHERE flag_last = 1 

--XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- Check Unwanted Spaces
--firstname
SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)

--lastname
SELECT cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname)

--gender
SELECT cst_gndr
FROM bronze.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr)

--gender
SELECT cst_key
FROM bronze.crm_cust_info
WHERE cst_key != TRIM(cst_key)

-- Data Standardization and consistemcy
SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info

-- no abbreivaed terms
SELECT  
	cst_gndr,
	CASE WHEN cst_gndr='F' THEN 'FEMALE'
		 WHEN cst_gndr='M' THEN 'MALE'
		 ELSE 'N/A'
	END AS Gender
FROM bronze.crm_cust_info

SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE 
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				ELSE 'n/a'
			END AS cst_marital_status, -- Normalize marital status values to readable format
			CASE 
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a'
			END AS cst_gndr, -- Normalize gender values to readable format
			cst_create_date
		FROM (
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		) t
		WHERE flag_last = 1;



select * from silver.crm_cust_info

select * from silver.crm_prd_info

SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, -- Extract category ID
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,        -- Extract product key
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost,
			CASE 
				WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
				WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
				WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
				WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
				ELSE 'n/a'
			END AS prd_line, -- Map product line codes to descriptive values
			CAST(prd_start_dt AS DATE) AS prd_start_dt,
			CAST(
				LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 
				AS DATE
			) AS prd_end_dt -- Calculate end date as one day before the next start date
		FROM bronze.crm_prd_info; 

DROP TABLE silver.crm_prd_info
CREATE TABLE silver.crm_prd_info(
prd_id INT,
cat_id NVARCHAR(50),
prd_key NVARCHAR(50),
prd_nm NVARCHAR(50),
prd_cost INT,
prd_line NVARCHAR(50),
prd_start_dt DATE,
prd_end_dt DATE,
dwh_create_date DATETIME2 DEFAULT GETDATE()
);


select * from silver.crm_prd_info
where prd_end_dt < prd_start_dt
--================================================================
--silver.crm_sales_details
--================================================================
select * from silver.crm_sales_details
DROP TABLE silver.crm_sales_details
CREATE TABLE silver.crm_sales_details(
	sls_ord_num NVARCHAR(50),
	sls_prd_key NVARCHAR(50),
	sls_cust_id INT,
	sls_order_dt DATE,
	sls_ship_dt DATE,
	sls_due_dt DATE,
	sls_sales INT,
	sls_quantity INT,
	sls_price INT,
	dwh_create_date DATETIME2 DEFAULT GETDATE()
)

--==============================================================
-- INSERT VALUES 
--==============================================================
INSERT INTO silver.crm_sales_details(
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
)
SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	CASE WHEN sls_order_dt=0 OR LEN(sls_order_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
	END AS sls_order_dt,
	CASE WHEN sls_ship_dt=0 OR LEN(sls_ship_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
	END AS sls_ship_dt,
	CASE WHEN sls_due_dt=0 OR LEN(sls_due_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
	END AS sls_due_dt,
	CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity * ABS(sls_price)
		ELSE sls_sales
	END AS sls_sales,
	sls_quantity,
	CASE WHEN sls_price IS NULL OR sls_price <= 0
			THEN sls_sales/NULLIF(sls_quantity,0)
	     ELSE sls_price
	END AS sls_price
FROM bronze.crm_sales_details

--==============================================================
-- vIEW tABLE 
--==============================================================
SELECT * FROM silver.crm_sales_details


--=============================================================
SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	CASE WHEN sls_order_dt=0 OR LEN(sls_order_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
	END AS sls_order_dt,
	CASE WHEN sls_ship_dt=0 OR LEN(sls_ship_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
	END AS sls_ship_dt,
	CASE WHEN sls_due_dt=0 OR LEN(sls_due_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
	END AS sls_due_dt,
	CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity * ABS(sls_price)
		ELSE sls_sales
	END AS sls_sales,
	sls_quantity,
	CASE WHEN sls_price IS NULL OR sls_price <= 0
			THEN sls_sales/NULLIF(sls_quantity,0)
	     ELSE sls_price
	END AS sls_price
FROM bronze.crm_sales_details

-- check invalid dates 
SELECT 
	NULLIF(sls_order_dt,0) as sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 
OR LEN(sls_order_dt) != 8 
OR sls_order_dt >20500101
OR sls_order_dt < 19000101

SELECT 
	NULLIF(sls_ship_dt,0) as sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt <= 0 
OR LEN(sls_ship_dt) != 8 
OR sls_ship_dt >20500101
OR sls_ship_dt < 19000101

SELECT 
	NULLIF(sls_due_dt,0) as sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0 
OR LEN(sls_due_dt) != 8 
OR sls_due_dt >20500101
OR sls_due_dt < 19000101

-- check invalid dates 
SELECT 
*
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

-- check data consistency : between sales, quaniy and price
-- >> Sales = Quantity * Price
-- >> Values must no be null , zero , or negative
-- If sales is negative zero or null derive it using quantity and price
-- if price is zero or null calculate it using sales and quantity 
-- if price is neagtive convert it to positive value 
SELECT 
sls_sales AS sls_old_sales,
sls_quantity,
sls_price AS sls_old_price,
CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
	THEN sls_quantity * ABS(sls_price)
	ELSE sls_sales
END AS sls_sales,
CASE WHEN sls_price IS NULL OR sls_price <= 0
      THEN sls_sales/NULLIF(sls_quantity,0)
	 ELSE sls_price
END AS sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL
OR sls_quantity IS NULL 
OR sls_price IS NULL 
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales,sls_quantity

--=============================================================
--silver.erp_cust_az12
--=============================================================

SELECT 
*
FROM bronze.erp_cust_az12 
WHERE cid like '%AW00011000'

SELECT * FROM silver.crm_cust_info
--xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
-- we saw that in ID we NAS in start of every id
-- we have to clean it
--xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

SELECT 
	cid,
	CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(CID,4,LEN(CID))
		 ELSE cid
	END AS cid,
	bdate,
	gen
FROM bronze.erp_cust_az12 
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(CID,4,LEN(CID))
		 ELSE cid
	  END NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info)

--===================================================================
-- IDENTIFY OUT OF RANGE DATE
SELECT DISTINCT bdate
FROM bronze.erp_cust_az12
WHERE bdate<'1924-01-01' OR bdate > GETDATE()

-- Data Standardization & consistency 
SELECT DISTINCT gen,
	CASE WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
		 WHEN UPPER(TRIM(gen)) IN ('M','female') THEN 'Male'
		 ELSE 'n/a'
	END AS gen
FROM bronze.erp_cust_az12
--======================================================================
-- insert values silver
--========================================================================
SELECT 
*
FROM silver.erp_cust_az12 

INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
)
SELECT 
	CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(CID,4,LEN(CID))
		 ELSE cid
	END AS cid,
	CASE WHEN bdate > GETDATE() THEN NULL 
		 ELSE bdate 
	END AS bdate,
	CASE WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
		 WHEN UPPER(TRIM(gen)) IN ('M','female') THEN 'Male'
		 ELSE 'n/a'
	END AS gen
FROM bronze.erp_cust_az12

SELECT * FROM silver.erp_cust_az12 
--***************************************************************************

--=============================================================
--silver.erp_loc_a101
--=============================================================

SELECT 
	REPLACE(cid,'-','') as cid,
	cntry
FROM bronze.erp_loc_a101 
WHERE REPLACE(cid,'-','') NOT IN
(SELECT cst_key FROM silver.crm_cust_info)

-- data standadrdization and consistency 
SELECT DISTINCT cntry 
FROM bronze.erp_loc_a101 
ORDER BY cntry

--=============================================================
-- INSERT VALUES INTO silver.erp_loc_a101
--=============================================================
INSERT INTO silver.erp_loc_a101(
	cid,
	cntry
)
SELECT 
	REPLACE(cid,'-','') AS CID,
	CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		 WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
		 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		 ELSE TRIM(cntry)
	END AS cntry
FROM bronze.erp_loc_a101;

-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

SELECT 
	REPLACE(cid,'-','') as cid,
	cntry
FROM silver.erp_loc_a101 
WHERE REPLACE(cid,'-','') NOT IN
(SELECT cst_key FROM silver.crm_cust_info)

-- data standadrdization and consistency 
SELECT DISTINCT cntry 
FROM silver.erp_loc_a101 
ORDER BY cntry

SELECT cst_key FROM silver.crm_cust_info;
select cid,cntry FROM bronze.erp_loc_a101;
SELECT * FROM  silver.erp_loc_a101 


--=============================================================
--silver.erp_PX_CAT_G1V2
--=============================================================

SELECT 
	id,
	cat,
	subcat,
	maintenance
FROM bronze.erp_px_cat_g1v2

--check for unwanted spaces

SELECT *  FROM  bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat)

SELECT *  FROM  bronze.erp_px_cat_g1v2
WHERE subcat != TRIM(subcat)

SELECT *  FROM  bronze.erp_px_cat_g1v2
WHERE maintenance != TRIM(maintenance)

-- data standadrdization and consistency 
SELECT DISTINCT cat 
FROM bronze.erp_px_cat_g1v2 
ORDER BY cat

SELECT DISTINCT subcat 
FROM bronze.erp_px_cat_g1v2 
ORDER BY subcat

SELECT DISTINCT maintenance 
FROM bronze.erp_px_cat_g1v2 
ORDER BY maintenance


--=============================================================
-- INSERT VALUES INTO silver.erp_px_cat_g1v2
--=============================================================
INSERT INTO silver.erp_px_cat_g1v2(
	id,
	cat,
	subcat,
	maintenance
)
SELECT 
	id,
	cat,
	subcat,
	maintenance
FROM bronze.erp_px_cat_g1v2

SELECT * FROM silver.erp_px_cat_g1v2

























