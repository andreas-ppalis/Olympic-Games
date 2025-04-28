/*
---------------------------------------------------------
README - SETUP INSTRUCTIONS FOR THIS PROJECT
---------------------------------------------------------

1. Create a database (if not already created):

   Example (in PostgreSQL):
   -------------------------------------
   CREATE DATABASE olympics_db;
   -------------------------------------

2. Connect to the newly created database:

   Example (in psql or any client):
   -------------------------------------
   \c olympics_db
   -------------------------------------

3. Create the necessary tables and views:

   Run the SQL script (this file) to create tables, views, and populate transformations.

4. Import CSV data into the tables:

   Example (for psql terminal):
   -------------------------------------
   \copy olympics_history FROM '/your/path/athlete_events.csv' DELIMITER ',' CSV HEADER;
   \copy olympics_history_noc_regions FROM '/your/path/noc_regions.csv' DELIMITER ',' CSV HEADER;
   -------------------------------------

   Notes:
   - Ensure the CSV files are properly formatted.
   - Adjust the file paths accordingly to your system.

5. Now you can run all the queries safely.

---------------------------------------------------------
*/


DROP TABLE IF EXISTS OLYMPICS_HISTORY;

CREATE TABLE OLYMPICS_HISTORY
(
    id          INT,
    name        VARCHAR(255),
    sex         VARCHAR(10),
    age         VARCHAR(10),
    height      VARCHAR(10),
    weight      VARCHAR(10),
    team        VARCHAR(100),
    noc         VARCHAR(10),
    games       VARCHAR(50),
    year        INT,
    season      VARCHAR(10),
    city        VARCHAR(100),
    sport       VARCHAR(100),
    event       VARCHAR(500),
    medal       VARCHAR(10)
);

DROP TABLE IF EXISTS OLYMPICS_HISTORY_NOC_REGIONS;

CREATE TABLE OLYMPICS_HISTORY_NOC_REGIONS
(
    noc         VARCHAR(10),
    region      VARCHAR(100),
    notes       VARCHAR(255)
);



-- Chech that data has been imported correctly
select * from OLYMPICS_HISTORY;
select * from OLYMPICS_HISTORY_NOC_REGIONS;

-- Replace "NA" with NULL in the columns Age, Height and Weight
UPDATE OLYMPICS_HISTORY
SET
    age = CASE WHEN age = 'NA' THEN NULL ELSE age END,
    height = CASE WHEN height = 'NA' THEN NULL ELSE height END,
    weight = CASE WHEN weight = 'NA' THEN NULL ELSE weight END;

-- Change data type of Age & Height to INTEGER and data type of Weight to NUMERIC
ALTER TABLE OLYMPICS_HISTORY
    ALTER COLUMN age TYPE INTEGER USING age::INTEGER,
    ALTER COLUMN height TYPE INTEGER USING height::INTEGER,
    ALTER COLUMN weight TYPE NUMERIC USING weight::NUMERIC;


-- SQL queries

-- Task 1
-- How many olympics games have been held?
SELECT COUNT(DISTINCT games) AS TOTAL_OLYMPICS_GAMES FROM OLYMPICS_HISTORY;


-- Task 2
-- List down all Olympic games held so far
SELECT  DISTINCT year, season, city FROM OLYMPICS_HISTORY
ORDER BY year;


-- Task 3
-- Mention the total number of countries who participated in each olympics game
SELECT games, COUNT(DISTINCT noc) AS no_of_countries FROM OLYMPICS_HISTORY
GROUP BY games
ORDER BY games;


-- Task 4
-- Show the number of Male (M) and Female (F) athletes that participated in each olympics game
SELECT games, sex, COUNT(DISTINCT name) AS unique_athletes FROM OLYMPICS_HISTORY
GROUP BY games, sex
ORDER BY games, sex;


-- Task 5
-- Which year saw the highest and lowest no of countries participating in Olympics
-- Create a view for having the number of participating countries
CREATE VIEW CountryParticipation AS 
SELECT year, season,COUNT(DISTINCT noc) AS country_count FROM OLYMPICS_HISTORY
GROUP BY year,season;

-- SELECT * FROM CountryParticipation;
SELECT year, season, country_count,
       CASE
	       WHEN country_count = (SELECT MAX(country_count) FROM CountryParticipation) THEN 'Highest' -- identify highest number of participating countries
		   WHEN country_count = (SELECT MIN(country_count) FROM CountryParticipation) THEN 'Lowest' -- identify lowest number of participating countries
	   END AS participation_type
FROM CountryParticipation
WHERE country_count = (SELECT MAX(country_count) FROM CountryParticipation) OR country_count = (SELECT MIN(country_count) FROM CountryParticipation);


-- Task 6
-- Which Olympic games had more than 200 countries participating?
SELECT year,season FROM CountryParticipation
WHERE country_count > 200;


-- Task 7
-- Which nations have participated in all of the olympic games?
-- Create a view on combining the two tables on noc
CREATE VIEW allregions AS 
SELECT oh.noc, nr.region, oh.year FROM olympics_history AS oh
JOIN olympics_history_noc_regions AS nr
ON oh.noc = nr.noc;
-- CTE creation for counting the distinct years of participation for each nation
WITH GameParticipation AS (                                                           
	SELECT noc,region,COUNT(DISTINCT year) AS years_participated FROM allregions
	GROUP BY noc, region
),
-- CTE that calculates the total number of Olympic games held by counting distinct year 
TotalGames AS (
	SELECT COUNT(DISTINCT year) AS total_games FROM olympics_history)
	SELECT gp.noc, gp.region FROM GameParticipation AS gp  -- filtering nations whose years_particiated matches the total number of olympic games
	JOIN TotalGames AS tg
	ON gp.years_participated = tg.total_games
	ORDER BY gp.region;


-- Task 8
-- Identify the sport which was played in all summer olympics.
WITH SummerOlympics AS (  
	SELECT DISTINCT year FROM olympics_history -- get all distinct years for Summer Olympics
	WHERE season = 'Summer'
),
SportParticipation AS (
	SELECT sport, COUNT(DISTINCT year) AS years_participated FROM olympics_history --counts distinct Summer Olympics per sport
	WHERE season = 'Summer'
	GROUP BY sport
),
TotalSummerGames AS (
	SELECT COUNT(*) AS total_summer_games FROM SummerOlympics
)
SELECT sp.sport FROM SportParticipation AS sp
JOIN TotalSummerGames AS tsg 
ON sp.years_participated = tsg.total_summer_games;


-- Task 9
-- Which Sports were just played only once in the olympics?
SELECT sport, COUNT(DISTINCT year) FROM olympics_history
GROUP BY sport
HAVING COUNT(DISTINCT year) = 1
ORDER BY sport;


-- Task 10
-- Get the total number of sports played in each olympics game
SELECT games, COUNT(DISTINCT sport) AS no_of_sports FROM olympics_history
GROUP BY games
ORDER BY no_of_sports DESC;


-- Task 11
-- Oldest athlete to win a gold medal
WITH GoldMedalists AS (
    SELECT name, age, sport, event, games, RANK() OVER (ORDER BY age DESC) AS rank FROM olympics_history
    WHERE medal = 'Gold' AND age IS NOT NULL
)
SELECT name, age, sport, event, games FROM GoldMedalists
WHERE rank = 1;


-- Task 12
-- Find the Ratio of male and female athletes participated in all olympic games.
WITH t1 AS (
	SELECT sex, COUNT(*) AS cnt FROM olympics_history -- counting athletes for each sex
	GROUP BY sex
),
t2 AS (
	SELECT *, ROW_NUMBER() OVER (ORDER by cnt) AS rn FROM t1
),
min_cnt AS (
	SELECT cnt FROM t2
	WHERE rn=1
),
max_cnt AS (
	SELECT cnt FROM t2 
	WHERE rn=2
)
SELECT CONCAT('1 : ',ROUND(max_cnt.cnt::decimal/min_cnt.cnt,2)) AS RATIO FROM min_cnt, max_cnt;
    

-- Task 13
-- Find the top 5 athletes who have won the most gold medals.
WITH GoldMedalCounts AS (
	SELECT name, COUNT(*) AS goldmedals FROM olympics_history
	WHERE medal='Gold'
	GROUP BY name
),
RankedAthletes AS (
	SELECT name,goldmedals, RANK() OVER (ORDER BY goldmedals DESC) AS rank FROM GoldMedalCounts
)
SELECT name, goldmedals FROM RankedAthletes
WHERE rank <= 5
ORDER BY rank;


-- Task 14
-- Find the top 5 athletes who have won the most medals.
WITH MedalCounts AS (
	SELECT name, COUNT(*) AS total_medals FROM olympics_history
	WHERE medal IN ('Gold','Silver','Bronze')
	GROUP BY name
),
RankedAthletes AS (
	SELECT name,total_medals, RANK() OVER (ORDER BY total_medals DESC) AS rank FROM MedalCounts
)
SELECT name, total_medals FROM RankedAthletes
WHERE rank <= 5
ORDER BY rank;


-- Task 15 
-- Find the top 5 most successful countries in olympics. Success is defined by number of medals won
WITH CountryMedalCounts AS (
    SELECT noc, COUNT(*) AS total_medals FROM olympics_history
    WHERE medal IN ('Gold', 'Silver', 'Bronze')
    GROUP BY noc
),
RankedCountries AS (
    SELECT noc, total_medals, RANK() OVER (ORDER BY total_medals DESC) AS rank FROM CountryMedalCounts
)
SELECT noc AS country, total_medals FROM RankedCountries
WHERE rank <= 5
ORDER BY rank;



-- Task 16
-- List down total gold, silver and bronze medals won by each country.
SELECT 
    nr.region AS country,
    COUNT(CASE WHEN medal = 'Gold' THEN 1 END) AS gold_medals, -- 1 is a placeholder value that is returned when the condition is met
    COUNT(CASE WHEN medal = 'Silver' THEN 1 END) AS silver_medals,
    COUNT(CASE WHEN medal = 'Bronze' THEN 1 END) AS bronze_medals,
    COUNT(CASE WHEN medal IN ('Gold', 'Silver', 'Bronze') THEN 1 END) AS total_medals
FROM olympics_history AS oh
JOIN olympics_history_noc_regions AS nr
ON oh.noc = nr.noc
GROUP BY nr.region
ORDER BY total_medals DESC;


-- Task 17
-- List down total gold, silver and bronze medals won by each country corresponding to each olympic games.
SELECT 
    oh.games, nr.region AS country,
    COUNT(CASE WHEN medal = 'Gold' THEN 1 END) AS gold_medals, -- 1 is a placeholder value that is returned when the condition is met
    COUNT(CASE WHEN medal = 'Silver' THEN 1 END) AS silver_medals,
    COUNT(CASE WHEN medal = 'Bronze' THEN 1 END) AS bronze_medals,
    COUNT(CASE WHEN medal IN ('Gold', 'Silver', 'Bronze') THEN 1 END) AS total_medals
FROM olympics_history AS oh
JOIN olympics_history_noc_regions AS nr
ON oh.noc = nr.noc
WHERE oh.medal IN ('Gold', 'Silver', 'Bronze')
GROUP BY oh.games, nr.region
ORDER BY oh.games, nr.region;


-- Task 18
-- Which country won the most gold, most silver and most bronze medals in each olympic games.
-- We can use window functions or aggregation combined with filtering
WITH MedalCounts AS (
    SELECT oh.games AS olympic_games, nr.region AS country,
        COUNT(CASE WHEN oh.medal = 'Gold' THEN 1 END) AS gold_medals,
        COUNT(CASE WHEN oh.medal = 'Silver' THEN 1 END) AS silver_medals,
        COUNT(CASE WHEN oh.medal = 'Bronze' THEN 1 END) AS bronze_medals
    FROM olympics_history AS oh
    JOIN olympics_history_noc_regions AS nr ON oh.noc = nr.noc
    WHERE oh.medal IN ('Gold', 'Silver', 'Bronze')
    GROUP BY oh.games, nr.region
),
RankedMedals AS (
    SELECT olympic_games, country, gold_medals, silver_medals, bronze_medals,
        RANK() OVER (PARTITION BY olympic_games ORDER BY gold_medals DESC) AS gold_rank,
        RANK() OVER (PARTITION BY olympic_games ORDER BY silver_medals DESC) AS silver_rank,
        RANK() OVER (PARTITION BY olympic_games ORDER BY bronze_medals DESC) AS bronze_rank
    FROM MedalCounts
)
SELECT 
    olympic_games,
    MAX(CASE WHEN gold_rank = 1 THEN country || ' - ' || gold_medals END) AS most_gold, -- || operator used to concatenate strings
    MAX(CASE WHEN silver_rank = 1 THEN country || ' - ' || silver_medals END) AS most_silver,
    MAX(CASE WHEN bronze_rank = 1 THEN country || ' - ' || bronze_medals END) AS most_bronze
FROM RankedMedals
GROUP BY olympic_games
ORDER BY olympic_games;



-- Task 19
-- Which country won the most gold, most silver, most bronze medals and the most medals in each olympic games.
WITH MedalCounts AS (
    SELECT oh.games AS olympic_games, nr.region AS country,
        COUNT(CASE WHEN oh.medal = 'Gold' THEN 1 END) AS gold_medals,
        COUNT(CASE WHEN oh.medal = 'Silver' THEN 1 END) AS silver_medals,
        COUNT(CASE WHEN oh.medal = 'Bronze' THEN 1 END) AS bronze_medals,
        COUNT(CASE WHEN oh.medal IN ('Gold', 'Silver', 'Bronze') THEN 1 END) AS total_medals
    FROM olympics_history AS oh
    JOIN olympics_history_noc_regions AS nr ON oh.noc = nr.noc
    WHERE oh.medal IN ('Gold', 'Silver', 'Bronze')
    GROUP BY oh.games, nr.region
),
RankedMedals AS (
    SELECT olympic_games,country,gold_medals,silver_medals,bronze_medals,total_medals,
        RANK() OVER (PARTITION BY olympic_games ORDER BY gold_medals DESC) AS gold_rank,
        RANK() OVER (PARTITION BY olympic_games ORDER BY silver_medals DESC) AS silver_rank,
        RANK() OVER (PARTITION BY olympic_games ORDER BY bronze_medals DESC) AS bronze_rank,
        RANK() OVER (PARTITION BY olympic_games ORDER BY total_medals DESC) AS total_rank
    FROM MedalCounts
)
SELECT 
    olympic_games,
    MAX(CASE WHEN gold_rank = 1 THEN country || ' - ' || gold_medals END) AS most_gold,
    MAX(CASE WHEN silver_rank = 1 THEN country || ' - ' || silver_medals END) AS most_silver,
    MAX(CASE WHEN bronze_rank = 1 THEN country || ' - ' || bronze_medals END) AS most_bronze,
    MAX(CASE WHEN total_rank = 1 THEN country || ' - ' || total_medals END) AS most_total_medals
FROM RankedMedals
GROUP BY olympic_games
ORDER BY olympic_games;


-- Task 20
-- Which countries have never won gold medal but have won silver/bronze medals?
WITH MedalCounts AS (
    SELECT nr.region AS country,
        COUNT(CASE WHEN oh.medal = 'Gold' THEN 1 END) AS gold_medals,
        COUNT(CASE WHEN oh.medal = 'Silver' THEN 1 END) AS silver_medals,
        COUNT(CASE WHEN oh.medal = 'Bronze' THEN 1 END) AS bronze_medals
    FROM olympics_history AS oh
    JOIN olympics_history_noc_regions AS nr ON oh.noc = nr.noc
    WHERE oh.medal IN ('Gold', 'Silver', 'Bronze')
    GROUP BY nr.region
)
SELECT country, silver_medals, bronze_medals
FROM MedalCounts
WHERE gold_medals = 0 AND (silver_medals > 0 OR bronze_medals > 0)
ORDER BY country;


-- Task 21
-- In which sports USA has won highest medals? Get top 3
WITH USAMedalCounts AS (
	SELECT oh.sport, COUNT(1) AS total_medals FROM olympics_history AS oh
	JOIN olympics_history_noc_regions AS nr 
	ON oh.noc = nr.noc
	WHERE oh.noc = 'USA' AND oh.medal IN ('Gold', 'Silver', 'Bronze')
	GROUP BY oh.sport
)
SELECT sport, total_medals FROM USAMedalCounts
ORDER BY total_medals DESC
LIMIT 3;


-- Task 22
-- Break down all olympic games where USA won medal for its top sport and how many medals in each olympic game
SELECT noc, sport, games, count(*) AS total_medals FROM olympics_history
WHERE medal IN ('Gold', 'Bronze', 'Silver') AND noc = 'USA' AND sport = 'Athletics'
GROUP BY noc, sport, games
ORDER BY total_medals DESC;






