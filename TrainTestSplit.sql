-- This SQL file serves to provide code to split a table into a 
-- training and test set with the option to set a random seed. 
-- This is important so that the code can be reproducible. 

-------------------
-- Inexact Split --
-------------------

-- Currently, it doesn't split exactly since it takes each element
-- row by row and randomly assigns it to either the training or
-- test set.


-- To do this, we must first create a vector of random real numbers.
-- This vector will have the same length as the table we are trying
-- to split. We create an arbitrary table with the same length
-- beforehand and then join it with a setseed() call. 

-- This is done since there is an issue with generating a series
-- with a variable length within a sub-query.
DROP TABLE IF EXISTS id_table;
CREATE TABLE id_table(id integer);

INSERT INTO id_table
SELECT generate_series(1, count(*))
  FROM patients;


-- Create a table with the N random numbers. Here, we can set a seed
-- so we get reproducible results.
DROP TABLE IF EXISTS random_vector;
CREATE TABLE random_vector(row_id integer, random double precision);

INSERT INTO random_vector
SELECT (row_number() OVER ()) AS row_id,
       random()
  FROM id_table, setseed(0);


-- Once we have created the random vector, we need to join it to 
-- our desired table. Keep in mind that the length of the random 
-- vector is the same as the number of rows in the desired table
-- that we are splitting. We can assign all values with a random
-- value greater than 0.8 to the training set and anything less
-- to the test set. 
DROP TABLE IF EXISTS patients_train_test;
CREATE TABLE patients_train_test
   AS SELECT *,
             CASE WHEN random < 0.8 THEN 'train'
                  ELSE 'test'
              END AS train_test
        FROM random_vector rv
             JOIN patients p
               ON rv.row_id = p.id;

SELECT *
  FROM patients_train_test
 ORDER BY id;


-- If we don't care to use a seed, we can drastically simplify this
-- by using the following:
DROP TABLE IF EXISTS patients_train_test;
CREATE TABLE patients_train_test
   AS SELECT *,
             CASE WHEN random() < 0.8 THEN 'train'
                  ELSE 'test'
              END AS train_test
        FROM patients;


-----------------
-- Exact Split --
-----------------
-- Doing an exact split can be a bit more difficult. One way would be to
-- sample a column of random() numbers, order them, then take the top
-- 80% of them for example. It is important to note that for larger sample 
-- sizes, the inexact split will converge towards to exact split. Since we
-- would only use HAWQ to do an inexact split, it's not so important to do
-- an exact split. 








