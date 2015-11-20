-- Documentation: https://madlib.net/design.pdf   pg. 25

-- This script will show an example of sampling with replacement.
-- Bagging requires creation of many samples which are sampled
-- with replacement from the original dataset. 

-- Because generic.bagging() in PivotalR does the bagging in 
-- sequence, it can be very slow for large amounts of data or
-- for a large number of bags. We can instead do this directly
-- using PostgreSQL and MADlib to parallelize this. 

-- Trying to resample data in PL/R posed some issues since only
-- a certain amount of memory is allocated to each node, so 
-- it cannot store a large amount of data. 


DROP TABLE IF EXISTS test_data;
CREATE TABLE test_data (x integer, y integer);

INSERT INTO test_data
VALUES (1, 2),
       (2, 4),
       (3, 6),
       (4, 8),
       (5, 10),
       (6, 12),
       (7, 14),
       (8, 16),
       (9, 18),
       (10, 20);

SELECT * FROM test_data;

DROP TABLE IF EXISTS test_data_array;
SELECT *
  INTO test_data_array
  FROM (SELECT array_agg(x) AS x,
               array_agg(y) AS y
          FROM test_data
       ) foo;

SELECT * FROM test_data_array;


-- Assign row numbers
SELECT (row_number() OVER ())::integer AS rownum, * FROM test_data;

-- Generates 1 to 10
SELECT generate_series(1, 10);

-- Samples a random number from [0,1)
SELECT random();

-- Samples 20 integers randomly from 0-10
SELECT ceiling((1 - random()) * 10)::integer AS rownum
  FROM generate_series(1, 20);


-- What this is doing is sampling indices.
-- Now we must join to sample from our desired dataset.

SELECT * 
  FROM (SELECT (row_number() OVER ())::integer AS rownum, *
          FROM test_data
       ) foo_data  -- data that is being sampled
       JOIN 
       (SELECT ceiling((1 - random()) * 10)::integer AS rownum
          FROM generate_series(1, 10)
       ) foo_row_sample  -- random indices
       ON foo_data.rownum = foo_row_sample.rownum;


-- There are two rownum columns, so we just show one.

SELECT foo_data.rownum, x,y
  FROM (SELECT (row_number() OVER ())::integer AS rownum, *
          FROM test_data
       ) foo_data
       JOIN 
       (SELECT ceiling((1 - random()) * 10)::integer AS rownum
          FROM generate_series(1, 10)
       ) foo_row_sample
       ON foo_data.rownum = foo_row_sample.rownum;

-- Now let's put this into a new table.

SELECT *
  INTO bagged_test_data
  FROM (SELECT foo_data.rownum, x,y
          FROM (SELECT (row_number() OVER ())::integer AS rownum, *
                  FROM test_data
               ) foo_data
               JOIN 
               (SELECT ceiling((1 - random()) * 10)::integer AS rownum
                  FROM generate_series(1, 10)
               ) foo_row_sample
               ON foo_data.rownum = foo_row_sample.rownum
       ) foo_bag;

SELECT * FROM bagged_test_data;

----------------------------
-- Creating multiple bags --
----------------------------

-- The section above illustrates how to create a resampled
-- copy of a dataset into a new table. Clearly this isn't
-- very efficient if we want to create multiple bags. 
-- Ideally each bag should be condensed so that each column
-- becomes an array and one single bag appears as a row. 

-- For example, our above, we can aggregate the columns 
-- of bagged_test_data like we would do for a regression

DROP TABLE IF EXISTS bagged_test_data_array;
SELECT * 
  INTO bagged_test_data_array
  FROM (SELECT array_agg(x) AS x,
               array_agg(y) AS y
          FROM bagged_test_data
       ) foo;

SELECT * FROM bagged_test_data_array;

SELECT unnest(x), unnest(y)
  FROM bagged_test_data_array;


-- The next issue is to be able to create multiple
-- bags all at once. It would be tedious to create
-- the above table multiple times with different names
-- and concatenate the bags into a single table. 

-- Instead, we can sample more copies of the
-- foo_row_sample and then group them into 
-- different bags. 

-- To be more explicit, in the previous case, we had
-- a sample of size 10 that came from an array of size
-- 10. To create multiple bags, we can create a sample
-- of size n * 10 from the array of size 10. Here, n
-- is an integer that represents the number of bags.
-- Once we have this, we can split them up into n 
-- groups and use the array_agg() function and GROUP BY.


-- Let's try and create 15 bags!

DROP TABLE IF EXISTS bagged_array;

SELECT array_agg(rownum) AS rownum,
       array_agg(x) AS x,
       array_agg(y) AS y
  INTO bagged_array
  FROM (SELECT foo_data.rownum, x,y
          FROM (SELECT (row_number() OVER ())::integer AS rownum, *
                  FROM test_data
               ) foo_data
               JOIN 
               (SELECT ceiling((1 - random()) * 10)::integer AS rownum
                  FROM generate_series(1, 10)
               ) foo_row_sample
               ON foo_data.rownum = foo_row_sample.rownum
       ) foo_bag;

SELECT * FROM bagged_test_data;
SELECT * FROM bagged_array;

------------------------------------------------

-- This next bit of code illustrates how to create the
-- sample of indices with separate groups.

-- rownum: the index to JOIN on
-- groupnum: represents which group the index belongs to


SELECT (row_number() OVER ())::integer % 10 AS groupnum, -- 10 groups
       ceiling((1 - random()) * 10) AS rownum            -- samples from 1 to 10
  FROM generate_series(1, 10 * 15)                       -- samples of size 15
 ORDER BY groupnum;

-- To avoid having too many subqueries, let's put our 
-- table of indices and data table we are sampling from
-- into two new tables.

DROP TABLE IF EXISTS foo_row_sample;
SELECT *
  INTO foo_row_sample
  FROM (SELECT (row_number() OVER ())::integer % 15 AS groupnum, -- 15 groups
               ceiling((1 - random()) * 10)::integer AS rownum   -- samples from 1 to 10
          FROM generate_series(1, 15 * 10)                       -- samples of size 10
         ORDER BY groupnum
       ) temp;

SELECT *
  FROM foo_row_sample
 ORDER BY groupnum, rownum;

DROP TABLE IF EXISTS foo_data;
SELECT *
  INTO foo_data
  FROM (SELECT (row_number() OVER ())::integer AS rownum, *
          FROM test_data
       ) temp;

SELECT * 
  FROM foo_data
 ORDER BY rownum;


-- Once we have completed that, we join the two by rownum, then
-- group by groupnum and aggregate into arrays. 

-- Joining together, we get a nice clean view of the bags

SELECT groupnum, x, y
  FROM foo_row_sample
       JOIN foo_data
       ON foo_data.rownum = foo_row_sample.rownum
 ORDER BY groupnum;


DROP TABLE IF EXISTS multiple_bags;
SELECT groupnum,
       array_agg(x) AS x,
       array_agg(y) AS y
  INTO multiple_bags
  FROM (SELECT groupnum, x, y
          FROM foo_row_sample
               JOIN foo_data
               ON foo_data.rownum = foo_row_sample.rownum
         ORDER BY groupnum
       ) foo
 GROUP BY groupnum;
 
SELECT *
  FROM multiple_bags
 ORDER BY groupnum;


-- Let's alter this so we can distribute it. This will be
-- necessary if we have a very large dataset. 

DROP TABLE IF EXISTS multiple_bags;
CREATE TABLE multiple_bags
   AS SELECT groupnum,
             array_agg(x) AS x,
             array_agg(y) AS y
        FROM (SELECT groupnum, x, y
                FROM foo_row_sample
                     JOIN foo_data
                     ON foo_data.rownum = foo_row_sample.rownum
               ORDER BY groupnum
              ) foo
        GROUP BY groupnum
  DISTRIBUTED BY (groupnum);

SELECT *
  FROM multiple_bags
 ORDER BY groupnum;

-------------------------------------------------------------
-------------------------------------------------------------
-------------------------------------------------------------
-- Let's make out dataset a lot larger to illustrate how 
-- much quicker it is when it runs in parallel. We will
-- now create 500 groups of size 750 instead.
-------------------------------------------------------------
-------------------------------------------------------------
-------------------------------------------------------------

DROP TABLE IF EXISTS foo_row_sample;
SELECT *
  INTO foo_row_sample
  FROM (SELECT (row_number() OVER ())::integer % 500 AS groupnum, -- 500 groups
               ceiling((1 - random()) * 750)::integer AS rownum   -- samples from 1 to 750
          FROM generate_series(1, 500 * 750)                      -- samples of size 750
         ORDER BY groupnum
       ) temp;

SELECT *
  FROM foo_row_sample
 ORDER BY groupnum;


DROP TABLE IF EXISTS foo_data;
SELECT *
  INTO foo_data
  FROM (SELECT generate_series(1, 750) AS rownum,
               generate_series(1, 750) AS x,
               2 * generate_series(1, 750) AS y
       ) foo;

SELECT *
  FROM foo_data
 ORDER BY rownum;


-- Sequential version: 

DROP TABLE IF EXISTS multiple_bags;
SELECT groupnum,
       array_agg(x) AS x,
       array_agg(y) AS y
  INTO multiple_bags
  FROM (SELECT groupnum, x, y
          FROM foo_row_sample
               JOIN foo_data
               ON foo_data.rownum = foo_row_sample.rownum
         ORDER BY groupnum
       ) foo
 GROUP BY groupnum;

SELECT * 
  FROM multiple_bags
 ORDER BY groupnum;


-- Distributed version:

DROP TABLE IF EXISTS multiple_bags;
CREATE TABLE multiple_bags
   AS SELECT groupnum,
             array_agg(x) AS x,
             array_agg(y) AS y
        FROM (SELECT groupnum, x, y
                FROM foo_row_sample
                     JOIN foo_data
                     ON foo_data.rownum = foo_row_sample.rownum
               ORDER BY groupnum
             ) foo
       GROUP BY groupnum
 DISTRIBUTED BY (groupnum);

SELECT * FROM multiple_bags;

-- It appears for this size of data, most of the time is spent
-- sending the query and then receiving the data, so there is not
-- too big of a difference in time. As the dataset grows, this 
-- discrepancy should grow as well. 








