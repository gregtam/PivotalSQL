-- Documentation: http://doc.madlib.net/latest/group__grp__array.html
-- This file serves to provide the code from the above link so that
-- a user can run the queries directly from this file.

-- Selects all entries from the dt_abalone_test table
SELECT * FROM madlibtestdata.dt_abalone_test;

----------------------
-- Array operations --
----------------------

-- Create table and insert values
DROP TABLE IF EXISTS array_tbl;

CREATE TABLE array_tbl ( id integer,
                         array1 integer[],
                         array2 integer[]
                       );
INSERT INTO array_tbl 
VALUES ( 1, '{1,2,3,4,5,6,7,8,9}', '{9,8,7,6,5,4,3,2,1}' ),
       ( 2, '{1,1,0,1,1,2,3,99,8}','{0,0,0,-5,4,1,1,7,6}' );

-- Print out of table
SELECT * 
  FROM array_tbl
 ORDER BY id;

-- Basic statistics (min, max, mean, standard deviation)
SELECT id,
       madlib.array_min(array1),
       madlib.array_max(array1),
       madlib.array_mean(array1),
       madlib.array_stddev(array1)
  FROM array_tbl
 ORDER BY id;

-- Add and subtract arrays term by term
SELECT id,
       madlib.array_add(array1,array2),
       madlib.array_sub(array1,array2)
  FROM array_tbl
 ORDER BY id;


----------------
-- Regression --
----------------

-- Create table named houses and insert values
DROP TABLE IF EXISTS houses;

CREATE TABLE houses (id INT,
                     tax INT,
                     bedroom INT,
                     bath FLOAT,
                     price INT,
                     size INT,
                     lot INT);

INSERT INTO houses
VALUES (  1 ,  590 ,       2 ,    1 ,  50000 ,  770 , 22100),
       (  2 , 1050 ,       3 ,    2 ,  85000 , 1410 , 12000),
       (  3 ,   20 ,       3 ,    1 ,  22500 , 1060 ,  3500),
       (  4 ,  870 ,       2 ,    2 ,  90000 , 1300 , 17500),
       (  5 , 1320 ,       3 ,    2 , 133000 , 1500 , 30000),
       (  6 , 1350 ,       2 ,    1 ,  90500 ,  820 , 25700),
       (  7 , 2790 ,       3 ,  2.5 , 260000 , 2130 , 25000),
       (  8 ,  680 ,       2 ,    1 , 142500 , 1170 , 22000),
       (  9 , 1840 ,       3 ,    2 , 160000 , 1500 , 19000),
       ( 10 , 3680 ,       4 ,    2 , 240000 , 2790 , 20000),
       ( 11 , 1660 ,       3 ,    1 ,  87000 , 1030 , 17500),
       ( 12 , 1620 ,       3 ,    2 , 118600 , 1250 , 20000),
       ( 13 , 3100 ,       3 ,    2 , 140000 , 1760 , 38000),
       ( 14 , 2070 ,       2 ,    3 , 148000 , 1550 , 14000),
       ( 15 ,  650 ,       3 ,  1.5 ,  65000 , 1450 , 12000);



SELECT * 
  FROM houses
 ORDER BY id;


-- Runs the regression. Extracts data from houses 
-- and puts results into houses_linregr

DROP TABLE IF EXISTS houses_linregr, houses_linregr_summary;

SELECT madlib.linregr_train('houses',
                            'houses_linregr',
                            'price',
                            'array[1, tax, bath, size]'
                           );
                           
SELECT * FROM houses_linregr;
SELECT * FROM houses_linregr_summary;

-- When you run "SELECT * FROM houses_linregr;", the 
-- coefficients, standard errors, t-stats, and p values
-- all appear in one row as arrays. This is very messy.

-- Instead, we can use the unnest() function to provide
-- a cleaner view of the results:
SELECT unnest(array['intercept','tax','bath','size']) AS attribute,
       unnest(coef) AS coefficient,
       unnest(std_err) AS standard_error,
       unnest(t_stats) AS t_stat,
       unnest(p_values) AS p_value
  FROM houses_linregr;


-- Does 3 separate regressions, one for each bedroom size
-- Results go into houses_linregr_bedroom table
DROP TABLE IF EXISTS houses_linregr_bedroom, houses_linregr_bedroom_summary;

SELECT madlib.linregr_train( 'houses',
                             'houses_linregr_bedroom',
                             'price',
                             'array[1, tax, bath, size]',
                             'bedroom'
                           );
SELECT * FROM houses_linregr_bedroom;
SELECT * FROM houses_linregr_bedroom_summary;


-- Cleaner view
SELECT bedroom,
       unnest(array['intercept','tax','bath','size']) AS attribute,
       unnest(coef) AS coefficient,
       unnest(std_err) AS standard_error,
       unnest(t_stats) AS t_stat,
       unnest(p_values) as pvalue
  FROM houses_linregr_bedroom;

-- Note that bedroom=4 is missing because it does not have p-values
-- If we remove it, we get bedroom=4 in the results.

SELECT bedroom,
       unnest(array['intercept','tax','bath','size']) AS attribute,
       unnest(coef) AS coefficient,
       unnest(std_err) AS standard_error,
       unnest(t_stats) AS t_stat
  FROM houses_linregr_bedroom;

                           
-------------------------
-- Logistic Regression --
-------------------------

-- Create table named patients and insert values
DROP TABLE IF EXISTS patients;

CREATE TABLE patients( id INTEGER NOT NULL,
                       second_attack INTEGER,
                       treatment INTEGER,
                       trait_anxiety INTEGER);
INSERT INTO patients
VALUES (  1 ,             1 ,         1 ,            70),
       (  3 ,             1 ,         1 ,            50),
       (  5 ,             1 ,         0 ,            40),
       (  7 ,             1 ,         0 ,            75),
       (  9 ,             1 ,         0 ,            70),
       ( 11 ,             0 ,         1 ,            65),
       ( 13 ,             0 ,         1 ,            45),
       ( 15 ,             0 ,         1 ,            40),
       ( 17 ,             0 ,         0 ,            55),
       ( 19 ,             0 ,         0 ,            50),
       (  2 ,             1 ,         1 ,            80),
       (  4 ,             1 ,         0 ,            60),
       (  6 ,             1 ,         0 ,            65),
       (  8 ,             1 ,         0 ,            80),
       ( 10 ,             1 ,         0 ,            60),
       ( 12 ,             0 ,         1 ,            50),
       ( 14 ,             0 ,         1 ,            35),
       ( 16 ,             0 ,         1 ,            50),
       ( 18 ,             0 ,         0 ,            45),
       ( 20 ,             0 ,         0 ,            60);

SELECT * 
  FROM patients
 ORDER BY id;


-- Run logistic regression
-- Results go into patients_logregr table
DROP TABLE IF EXISTS patients_logregr, patients_logregr_summary;
SELECT madlib.logregr_train( 'patients',
                             'patients_logregr',
                             'second_attack',
                             'ARRAY[1, treatment, trait_anxiety]',
                             NULL,
                             20,
                             'irls'
                           );

-- Print results
SELECT * FROM patients_logregr;
SELECT * FROM patients_logregr_summary;


-- Cleaner form of results
SELECT unnest(array['intercept', 'treatment', 'trait_anxiety']) AS attribute,
       unnest(coef) AS coefficient,
       unnest(std_err) AS standard_error,
       unnest(z_stats) AS z_stat,
       unnest(p_values) AS pvalue,
       unnest(odds_ratios) AS odds_ratio
  FROM patients_logregr;

-- Display prediction value along with the original value
SELECT p.id,
       madlib.logregr_predict(coef, array[1, treatment, trait_anxiety]),
       p.second_attack
  FROM patients p, patients_logregr m
 ORDER BY p.id;

-- Displays the same result, but shows logregr_predict as 1 or 0 
-- so that it is easier to see whether the prediction is correct.


SELECT p.id,
       CAST(madlib.logregr_predict(m.coef, array[1,treatment,trait_anxiety]) AS INT),
       second_attack
  FROM patients p, patients_logregr m
 ORDER BY p.id;


-- We move these into a new table called patients_logregr_results.

DROP TABLE IF EXISTS patients_logregr_results;

SELECT * 
  INTO patients_logregr_results
  FROM  (SELECT p.id,
                CAST(madlib.logregr_predict(m.coef, array[1,treatment,trait_anxiety]) AS INT) AS logr_predict,
                second_attack
           FROM patients p, patients_logregr m
          ORDER BY p.id) foo;

-- Now, we have our results with an additional column named correct, 
-- which is equal to 1 if the prediction is correct and 0 otherwise.

SELECT *,
       CAST(logr_predict = second_attack AS INT) AS correct
  FROM patients_logregr_results
 ORDER BY id;


-- We can simply take the average of the correct column to get the 
-- accuracy of the logistic regression.

SELECT AVG(CAST(logr_predict = second_attack AS INT)) AS accuracy
  FROM patients_logregr_results;



-----------------
-- Elastic Net --
-----------------

-- Runs elastic net regularization
DROP TABLE IF EXISTS houses_en;

SELECT madlib.elastic_net_train( 'houses', --tbl_source
                                 'houses_en', --tbl_result
                                 'price', --col_dep_var
                                 'array[tax, bath, size]', --col_ind_var
                                 'gaussian', --regress_family
                                 0.5, --alpha
                                 0.1, --lambda_value
                                 TRUE, --standardize
                                 NULL, --grouping_col
                                 'fista', --optimizer
                                 'warmup=TRUE, warmup_lambda_no=3', --optimizer_params
                                 NULL, --excluded
                                 10000, --max_iter
                                 1e-6 --tolerance
                               );

SELECT * FROM houses_en;

-- Prints results cleanly
SELECT unnest(features_selected) as attributes,
       unnest(coef_nonzero) as coef
  FROM houses_en
 UNION
SELECT 'intercept',
       intercept
  FROM houses_en;


-------------
-- K-means --
-------------

-- Create table named km_sample
DROP TABLE IF EXISTS km_sample CASCADE;

CREATE TABLE km_sample( pid int,
                        points double precision[]);
INSERT INTO km_sample 
VALUES (1,  array[14.23, 1.71, 2.43, 15.6, 127, 2.8, 3.0600, 0.2800, 2.29, 5.64, 1.04, 3.92, 1065]),
       (2,  array[13.2, 1.78, 2.14, 11.2, 1, 2.65, 2.76, 0.26, 1.28, 4.38, 1.05, 3.49, 1050]),
       (3,  array[13.16, 2.36,  2.67, 18.6, 101, 2.8,  3.24, 0.3, 2.81, 5.6799, 1.03, 3.17, 1185]),
       (4,  array[14.37, 1.95, 2.5, 16.8, 113, 3.85, 3.49, 0.24, 2.18, 7.8, 0.86, 3.45, 1480]),
       (5,  array[13.24, 2.59, 2.87, 21, 118, 2.8, 2.69, 0.39, 1.82, 4.32, 1.04, 2.93, 735]),
       (6,  array[14.2, 1.76, 2.45, 15.2, 112, 3.27, 3.39, 0.34, 1.97, 6.75, 1.05, 2.85, 1450]),
       (7,  array[14.39, 1.87, 2.45, 14.6, 96, 2.5, 2.52, 0.3, 1.98, 5.25, 1.02, 3.58, 1290]),
       (8,  array[14.06, 2.15, 2.61, 17.6, 121, 2.6, 2.51, 0.31, 1.25, 5.05, 1.06, 3.58, 1295]),
       (9,  array[14.83, 1.64, 2.17, 14, 97, 2.8, 2.98, 0.29, 1.98, 5.2, 1.08, 2.85, 1045]),
       (10, array[13.86, 1.35, 2.27, 16, 98, 2.98, 3.15, 0.22, 1.8500, 7.2199, 1.01, 3.55, 1045]);

-- Print data
SELECT * FROM km_sample
ORDER BY pid;

-- Do k-means
DROP TABLE IF EXISTS km_sample_results;

SELECT * 
  INTO km_sample_results
  FROM madlib.kmeanspp( 'km_sample',
                        'points',
                        2,
                        'madlib.squared_dist_norm2',
                        'madlib.avg',
                        20,
                        0.001);

-- Show results
SELECT * FROM km_sample_results;

