-- Connect to pivotalr_demodb database on gpadmin@dca1-mdw1.dan.dh.greenplum.com


------------
-- MADlib --
------------

SELECT COUNT(*) FROM census1; -- 2 million row data set

-- Training the linear regression

DROP TABLE IF EXISTS census1_linregr, census1_linregr_summary;
SELECT madlib.linregr_train('census1',
                            'census1_linregr',
                            'earns',
                            'ARRAY[1, hours, bachelor, married]'
                            );
SELECT * FROM census1_linregr;

-- Looking at the results/summary statistics

SELECT unnest(ARRAY['1', 'hours', 'bachelor', 'married']) AS attribute,
       unnest(coef) AS coef,
       unnest(std_err) AS std_err,
       unnest(t_stats) AS t_stats,
       unnest(p_values) AS p_values
  FROM census1_linregr;

-- We can do this entire fit on a much bigger dataset. 
-- The census1billion_rand table contains 1 billion entries. 
-- Let's run the same regression, but on the larger data set.

SELECT COUNT(*) FROM census1billion_rand; -- 1 billion row data set

-- Training the linear regression: Note that it runs a linear
-- regression on a 1 billion row data set in minutes!

DROP TABLE IF EXISTS census1billion_linregr, census1billion_linregr_summary;
SELECT madlib.linregr_train('census1billion_rand',
                            'census1billion_linregr',
                            'earns',
                            'ARRAY[1, hours, bachelor, married]'
                            );
SELECT * FROM census1billion_linregr;

-- Looking at the results/summary statistics

SELECT unnest(ARRAY['1', 'hours', 'bachelor', 'married']) AS attribute,
       unnest(coef) AS coef,
       unnest(std_err) AS std_err,
       unnest(t_stats) AS t_stats,
       unnest(p_values) AS p_values
  FROM census1billion_linregr;


-- Prediction

SELECT census1.*, 
       madlib.linregr_predict(ARRAY[1, hours, bachelor, married],
                              m.coef
                             ) AS predict,
       earns - madlib.linregr_predict(ARRAY[1, hours, bachelor, married],
                                      m.coef
                                     ) AS residual
  FROM census1, census1_linregr m;


----------
-- PL/R --
----------

-- Create TYPE to store model results
DROP TYPE IF EXISTS lm_type CASCADE;

CREATE TYPE lm_type AS
            (Variable text,
             Coef_est float, 
             Std_error float,
             T_stat float,
             P_value float);

-- Create PL/R function
DROP FUNCTION IF EXISTS lm_census_R(earns integer[],
                                    hours integer[],
                                    bachelor integer[],
                                    married integer[]);

CREATE OR REPLACE FUNCTION lm_census_R(earns integer[],
                                       hours integer[],
                                       bachelor integer[],
                                       married integer[])
             RETURNS SETOF lm_type AS
                           $$
                             fit = lm(earns ~ hours + bachelor + married)
                             coef = summary(fit)$coef
                             return(data.frame(rownames(coef), coef))
                           $$
                  LANGUAGE 'plr' IMMUTABLE;

-- The function we created takes integer arrays as
-- inputs. We must transform our census1 table
-- into a table where the columns are compressed
-- into an array. We can use the array_agg() function.

DROP TABLE IF EXISTS census1_array;
CREATE TABLE census1_array
   AS SELECT array_agg(earns) AS earns, 
             array_agg(hours) AS hours,
             array_agg(bachelor) AS bachelor,
             array_agg(married) AS married
        FROM census1;

-- Compare this
SELECT * FROM census1_array;
-- to this
SELECT * 
  FROM census1
 LIMIT 10;


SELECT (lm_census_R(earns, hours, bachelor, married)).*
  FROM census1_array;


-- Create PL/Python function
DROP FUNCTION IF EXISTS lm_census_py(earns integer[],
                                     hours integer[],
                                     bachelor integer[],
                                     married integer[]);

CREATE OR REPLACE FUNCTION lm_census_py(earns integer[],
                                        hours integer[],
                                        bachelor integer[],
                                        married integer[])
             RETURNS SETOF double precision AS
                           $$
                             import numpy as np
                             from sklearn.linear_model import LinearRegression

                             model = LinearRegression()
                             X = np.column_stack((hours, bachelor, married))
                             y = np.array(earns).reshape(-1,1)
                             model.fit(X,y)
                             result = []
                             result.append(model.intercept_[0])
                             for i in model.coef_[0]:
                                 result.append(i)
                             return result
                           $$
                  LANGUAGE 'plpythonu' IMMUTABLE;

SELECT lm_census_py(earns, hours, bachelor, married)
  FROM census1_array;



