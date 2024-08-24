-- select all columns from the artist table
SELECT *
FROM artist

-- select all columns from the canva_size table
SELECT *
FROM canvas_size

-- select all columns from the image_link table
SELECT *
FROM dbo.image_link

-- select all columns from the museum table
SELECT *
FROM museum

-- select all columns from the museum_hours table
SELECT *
FROM dbo.museum_hours

-- select all columns from the product_size table
SELECT *
FROM dbo.product_size

-- select all columns from the subject table
SELECT *
FROM dbo.subject

-- select all columns from the work  table
SELECT *
FROM dbo.work

--Fetch all the paintings which are not displayed on any museums
SELECT *
FROM dbo.work
WHERE museum_id IS NULL;

--Are there museums without any paintings
SELECT *
FROM museum
WHERE museum_id NOT IN 
    (SELECT museum_id
    FROM dbo.work);

-- How many paintings have an asking price of more than their regular price?
SELECT COUNT(work_id)
FROM product_size
WHERE sale_price > regular_price;

--Identify the paintings whose asking price is less than 50% of its regular price
SELECT *
FROM product_size
WHERE sale_price < (regular_price * 50/100) ;

-- Which canva size costs the most?
SELECT ranked.size_id, ranked.sale_price, c.label
FROM (
    SELECT *,
           RANK() OVER (ORDER BY sale_price DESC) AS price_rank
    FROM product_size
) ranked
LEFT JOIN canvas_size c
ON ranked.size_id = c.size_id
WHERE price_rank = 1;

--Delete duplicate records from work, product_size, subject and image_link tables

--work
WITH work_dup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY work_id, name, artist_id, style, museum_id ORDER BY (SELECT NULL)) AS work_row
    FROM work
)
DELETE FROM work_dup
WHERE work_row > 1;

--product_size
WITH product_dup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY work_id, size_id, sale_price, regular_price ORDER BY (SELECT NULL)) AS product_row
    FROM product_size
)
DELETE FROM product_dup
WHERE product_row > 1;

--subject
WITH subject_dup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY work_id, subject ORDER BY (SELECT NULL)) AS subject_row
    FROM subject
)
DELETE FROM subject_dup
WHERE subject_row > 1;

--image_link
WITH image_dup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY work_id, url, thumbnail_small_url, thumbnail_large_url ORDER BY (SELECT NULL)) AS image_row
    FROM image_link
)
DELETE FROM image_dup
WHERE image_row > 1;

-- Identify the museums with invalid city information in the given dataset
SELECT *
FROM museum
WHERE city LIKE '[0-9]%';
 
 --museum_hours table has 1 invalid entry. identify and remove it
WITH mhour_dup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY museum_id, day, [open], [close]  ORDER BY (SELECT NULL)) AS mhour_row
    FROM museum_hours
)
DELETE FROM mhour_dup
WHERE mhour_row > 1;

--fetch the top 10 most famous painting subject
SELECT TOP 10 COUNT(work_id) AS subject_count, subject
FROM subject
GROUP BY subject
ORDER BY subject_count DESC;

--Identify museums which are open on both Sunday and Monday. Display museum name and city 
SELECT m.name, m.city
FROM museum m
JOIN museum_hours mh 
ON m.museum_id = mh.museum_id
WHERE mh.day IN ('Sunday', 'Monday')
GROUP BY m.name, m.city
HAVING COUNT(DISTINCT mh.day) = 2
ORDER BY m.name;

-- How many museum open every single day
SELECT COUNT(museum_id) AS no_of_museums
FROM museum_hours
WHERE day IN ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday' )
HAVING COUNT(DISTINCT day) = 7;

--Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
SELECT TOP (5) m.name AS museum , m.museum_id, COUNT(w.work_id) AS no_of_paintings
FROM work   w
JOIN museum  m
ON w.museum_id  = m.museum_id
GROUP BY m.name, m.museum_id
ORDER BY no_of_paintings DESC;

SELECT m.name AS museum,m.museum_id, m_rank.no_of_painintgs
	FROM (	SELECT m.museum_id, COUNT(1) as no_of_painintgs
			, RANK() OVER(ORDER BY count(1) DESC) AS rnk
			FROM work w
			JOIN museum m ON m.museum_id=w.museum_id
			GROUP BY m.museum_id) m_rank
	JOIN museum m ON m.museum_id=m_rank.museum_id
	WHERE m_rank.rnk<=5;

--Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
SELECT a.artist_id, a.full_name, a_rnk.no_of_paintings, a_rnk.rnk
FROM (SELECT a.artist_id, COUNT(1) AS no_of_paintings, 
        RANK() OVER(ORDER BY COUNT(1) DESC) AS rnk
      FROM work w
      JOIN artist a
	  ON w.artist_id = a.artist_id
      GROUP BY a.artist_id) AS a_rnk
JOIN artist a
ON a.artist_id = a_rnk.artist_id
WHERE a_rnk.rnk <= 5;

--Display the 3 least popular canva size
SELECT ps_rnk.size_id, cs.label, rnk, ps_rnk.no_of_canvasize
FROM (
    SELECT size_id,  COUNT(1) AS no_of_canvasize, 
           DENSE_RANK() OVER(ORDER BY COUNT(1)) AS rnk 
    FROM product_size
    GROUP BY size_id
) ps_rnk
JOIN canvas_size cs
ON ps_rnk.size_id = cs.size_id
WHERE ps_rnk.rnk <= 3;


--Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
SELECT museum_name, [state], Open_time, Close_time, duration, day
FROM 
(SELECT m.name AS museum_name, m.state AS [state], mh.[open] AS Open_time, mh.[close] AS Close_time, 
      DATEDIFF(hour, mh.[open], mh.[close]) AS duration, mh.day AS day,
      RANK() OVER(ORDER BY DATEDIFF(hour, mh.[open], mh.[close]) DESC) AS rnk
FROM museum_hours mh
JOIN museum  m
ON mh.museum_id = m.museum_id) AS duration_rnk
WHERE duration_rnk.rnk = 1;

-- Which museum is open for the longest during a day. Display museum name, state, hours open, and which day
SELECT museum_name, [state], Open_time, Close_time, duration, day
FROM (
    SELECT 
        m.name AS museum_name, 
        m.state AS [state], 
        mh.[open] AS Open_time, 
        mh.[close] AS Close_time, 
        CAST((DATEDIFF(minute, mh.[open], mh.[close]) / 60) AS VARCHAR) + ' hours ' + 
        CAST((DATEDIFF(minute, mh.[open], mh.[close]) % 60) AS VARCHAR) + ' minutes' AS duration, 
        mh.day AS day,
        RANK() OVER(ORDER BY DATEDIFF(minute, mh.[open], mh.[close]) DESC) AS rnk
    FROM museum_hours mh
    JOIN museum m ON mh.museum_id = m.museum_id
) AS duration_rnk
WHERE duration_rnk.rnk = 1;


--which museum has the most no of most popular painting style

WITH pop_style AS (
    SELECT style, 
           RANK() OVER(ORDER BY COUNT(1) DESC) AS rnk
    FROM work
    GROUP BY style
),
mus AS (
    SELECT w.museum_id, 
           m.name AS museum_name, 
           w.style, 
           COUNT(1) AS No_of_Paintings,
           RANK() OVER(ORDER BY COUNT(1) DESC) AS rnk
    FROM work w
    JOIN museum m ON w.museum_id = m.museum_id
    JOIN pop_style ps ON ps.style = w.style
    WHERE ps.rnk = 1
    GROUP BY w.museum_id, m.name, w.style
)

SELECT museum_name, style, No_of_Paintings
FROM mus
WHERE rnk = 1;


-- Identify the artist whose paintings are displayed in multiple countries
WITH art AS (
    SELECT a.full_name AS artist_name,   
           m.country AS country
    FROM artist a
    JOIN work w ON a.artist_id = w.artist_id
    JOIN museum m ON w.museum_id = m.museum_id
    GROUP BY a.full_name, m.country
)

SELECT artist_name, COUNT(DISTINCT country) AS No_of_Countries
FROM art
GROUP BY artist_name
HAVING COUNT(DISTINCT country) > 1
ORDER BY No_of_Countries DESC;


--Display the country and city with most no of museums
WITH cou AS (
     SELECT country, COUNT(1) AS No_of_museum , RANK() OVER(ORDER BY COUNT(1) DESC) AS rnk
	 FROM museum
	 GROUP BY country),

	 cit AS (
	 SELECT city, COUNT(1) AS No_of_museum, RANK() OVER(ORDER BY COUNT(1) DESC) AS rnk
	 FROM museum
	 GROUP BY city)

SELECT country, city
FROM cou
CROSS JOIN cit
WHERE cou.rnk = 1 AND cit.rnk = 1;


-- Subquery for the top countries
WITH top_country AS (
    SELECT country, COUNT(1) AS No_of_museum
    FROM museum
    GROUP BY country
    HAVING COUNT(1) = (
        SELECT MAX(No_of_museum)
        FROM (
            SELECT COUNT(1) AS No_of_museum
            FROM museum
            GROUP BY country
        ) AS subquery
    )
),

-- Subquery for the top cities
top_city AS (
    SELECT city, COUNT(1) AS No_of_museum
    FROM museum
    GROUP BY city
    HAVING COUNT(1) = (
        SELECT MAX(No_of_museum)
        FROM (
            SELECT COUNT(1) AS No_of_museum
            FROM museum
            GROUP BY city
        ) AS subquery
    )
)

-- Selecting the results and aggregating multiple values
SELECT 
    (SELECT STRING_AGG(country, ', ') FROM top_country) AS top_countries, 
    (SELECT STRING_AGG(city, ', ') FROM top_city) AS top_cities;
