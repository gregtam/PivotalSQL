-- In Greenplum, PL/R functions will do the following:
-- 1. Take SQL data types as input
-- 2. Converts SQL data types to R data types
-- 3. Outputs results as R data types
-- 4. Converts the R data type output as SQL data types

-- PL/Python functions work in the same way.

-- To illustrate this, we first create table 
-- named houses and insert values
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



-- First, we create a simple function that takes doubles x and y 
-- and returns "(x,y)"

DROP FUNCTION IF EXISTS coordR(x double precision, y double precision);

CREATE OR REPLACE FUNCTION coordR(x double precision, y double precision)
                   RETURNS text AS
                           $$
                             # R code
                             print(paste("(", x, ", ", y, ")", sep=""))
                           $$
                  LANGUAGE 'plr' IMMUTABLE;

SELECT coordR(tax, size), tax, size 
  FROM houses;

-- We can create a similar function using Python

DROP FUNCTION IF EXISTS coordPy(x double precision, y double precision);

CREATE OR REPLACE FUNCTION coordPy(x double precision, y double precision)
                   RETURNS text as
                           $$
                             return "(" + str(x) + ", " + str(y) + ")"
                           $$
                  LANGUAGE 'plpythonu' IMMUTABLE;

SELECT coordPy(tax, size), tax, size
  FROM houses;


---------------------------------------
---------------------------------------

SELECT * FROM houses;

-- In order to do regressions, which require
-- all entries in a given column, we must
-- transform the houses table.

DROP TABLE IF EXISTS houses_array;

CREATE TABLE houses_array
          AS (SELECT array_agg(tax) AS tax,
                     array_agg(bedroom) AS bedroom,
                     array_agg(bath) AS bath,
                     array_agg(price) AS price,
                     array_agg(size) AS size,
                     array_agg(lot) AS lot
                FROM houses);

-- Note that we now only have one row in this table.
-- Each entry is now an array that represented an 
-- entire column in the houses table
SELECT * FROM houses_array;


-- Let's create a random test function
-- The function will take two arrays x and y
-- and return the sum of all their entries

DROP FUNCTION IF EXISTS test(x double precision[], y double precision[]);

CREATE OR REPLACE FUNCTION test(x double precision[], y double precision[])
                   RETURNS double precision AS
                           $$
                             sum(x) + sum(y)
                           $$
                  LANGUAGE 'plr' IMMUTABLE;


SELECT test(tax, bedroom), tax, bedroom
  FROM houses_array;


-- Next, we will do a simple linear regression in R
-- Our return type will contain both text (for variable names)
-- and doubles (for the different statistics). Since we will
-- print them all together, we create a new data type that is
-- simply an array that contains all this information

DROP TYPE IF EXISTS lm_type CASCADE;

CREATE TYPE lm_type AS
            (Variable text,
             Coef_est float, 
             Std_error float,
             T_stat float,
             P_value float);

DROP FUNCTION IF EXISTS lm_houses_plr(price double precision[], tax double precision[], bath double precision[], size double precision[]);

CREATE OR REPLACE FUNCTION lm_houses_plr(price double precision[], tax double precision[], bath double precision[], size double precision[])
             RETURNS SETOF lm_type AS
                           $$
                             fit = lm(price ~ tax + bath + size)
                             coefs = summary(fit)$coef
                             return(data.frame(rownames(coefs), coefs))
                           $$
                  LANGUAGE 'plr' IMMUTABLE;

SELECT (lm_houses_plr(price, tax, bath, size)).*
  FROM houses_array;

-- Let's try the same thing, but in Python

DROP FUNCTION IF EXISTS lm_houses_plpythonu(price double precision[], tax double precision[], bath double precision[], size double precision[]);

CREATE OR REPLACE FUNCTION lm_houses_plpythonu(price double precision[], tax double precision[], bath double precision[], size double precision[])
             RETURNS SETOF double precision AS
                           $$
                             import numpy as np
                             from sklearn.linear_model import LinearRegression

                             model = LinearRegression()
                             X = np.column_stack((tax, bath, size))
                             y = np.array(price).reshape(-1,1)
                             model.fit(X,y)
                             result = []
                             result.append(model.intercept_[0])
                             for i in model.coef_[0]:
                                 result.append(i)
                             return result
                           $$
                  LANGUAGE 'plpythonu' IMMUTABLE;

SELECT lm_houses_plpythonu(price, tax, bath, size)
  FROM houses_array;

-- Note: This does not look as nice. The sklearn.linear_model.LinearRegression()
-- function is not as good. It does not give standard erorrs or the variable
-- names in the results. It would be much better to import the statsmodels
-- library, but it is not available.


------------------
-- Text Example --
------------------

DROP TABLE IF EXISTS text_table;
CREATE TABLE text_table (id INT PRIMARY KEY,
                         words text);

INSERT INTO text_table
VALUES (1, 'At eight o''clock on Thursday morning, Arthur didn''t feel very good.'),
       (2, 'John took a nice leisurely stroll in the park.');

SELECT * FROM text_table;

DROP TYPE IF EXISTS text_tuple;
CREATE TYPE text_tuple AS
            (id INT,
             word text,
             pos text);


DROP FUNCTION IF EXISTS text_example(words text);
CREATE OR REPLACE FUNCTION text_example(sentence text)
             RETURNS SETOF text_tuple AS
                           $$
                             import nltk
                             #nltk.download()
                             tokens = nltk.word_tokenize(sentence)
                             tagged = nltk.pos_tag(tokens)
                             temp = [(1,2,3),(4,5,6)]
                             return(temp)
                           $$
                  LANGUAGE 'plpythonu' IMMUTABLE;

SELECT text_example(words)
  FROM text_table;

-- Can't do nltk.download() here...




