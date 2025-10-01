DROP TABLE IF EXISTS healthcare_patients;

CREATE TABLE healthcare_patients (
    visit_date TIMESTAMP NOT NULL,
    patient_id VARCHAR(20) PRIMARY KEY,
    patient_gender VARCHAR(10),
    patient_age INT CHECK (patient_age >= 0),
    patient_sat_score INT,
    patient_first_initial CHAR(1),
    patient_last_name VARCHAR(100),
    patient_race VARCHAR(100),
    patient_admin_flag BOOLEAN,
    patient_waittime INT CHECK (patient_waittime >= 0),
    department_referral VARCHAR(100)
);


-- Business Problems to Solve with SQL Queries
-- -------------------------------------------


-- 1. Patient Satisfaction Analysis:
--    - Which departments have the highest and lowest average patient satisfaction scores?
WITH dept_avg AS (
    SELECT
        department_referral,
        ROUND(AVG(patient_sat_score), 2) AS avg_satisfaction,
        RANK() OVER (ORDER BY AVG(patient_sat_score) DESC) AS rank_high,
        RANK() OVER (ORDER BY AVG(patient_sat_score) ASC) AS rank_low
    FROM healthcare_patients
    WHERE department_referral != 'None'
    GROUP BY department_referral
)
SELECT department_referral, avg_satisfaction, 'Highest' AS category
FROM dept_avg
WHERE rank_high = 1
UNION ALL
SELECT department_referral, avg_satisfaction, 'Lowest' AS category
FROM dept_avg
WHERE rank_low = 1;


-- 2. Wait Time Efficiency:
--    - Is there a correlation between patient wait time and satisfaction score?
SELECT
    ROUND(corr(patient_waittime, patient_sat_score)::NUMERIC, 3) AS correlation
FROM healthcare_patients
WHERE patient_waittime IS NOT NULL AND patient_sat_score IS NOT NULL;


-- FOLLOW-UP PROBLEM
-- Wait Time Buckets vs Satisfaction
-- Helps reveal non-linear patterns that correlation alone may miss.
SELECT
    CASE 
        WHEN patient_waittime BETWEEN 0 AND 10 THEN '0-10 min'
        WHEN patient_waittime BETWEEN 11 AND 20 THEN '11-20 min'
        WHEN patient_waittime BETWEEN 21 AND 30 THEN '21-30 min'
        WHEN patient_waittime BETWEEN 31 AND 40 THEN '31-40 min'
        WHEN patient_waittime BETWEEN 41 AND 50 THEN '41-50 min'
        WHEN patient_waittime > 50 THEN '50+ min'
    END AS wait_time_bucket,
    COUNT(*) AS patient_count,
    ROUND(AVG(patient_sat_score)::numeric, 2) AS avg_satisfaction
FROM healthcare_patients
WHERE patient_waittime IS NOT NULL 
  AND patient_sat_score IS NOT NULL
GROUP BY wait_time_bucket
ORDER BY MIN(patient_waittime);

-- 3. High-Risk Age Groups:
--    - Which age groups (children, adults, seniors) visit most often, 
--      and what are their average satisfaction scores?
SELECT	
	CASE 
        WHEN patient_age BETWEEN 0 AND 17 THEN 'children'
        WHEN patient_age BETWEEN 18 AND 65 THEN 'adults'
        WHEN patient_age > 64 THEN 'seniors'
    END AS age_bucket,
	COUNT(*) AS patient_count,
    ROUND(AVG(patient_sat_score)::numeric, 2) AS avg_satisfaction
FROM healthcare_patients
WHERE patient_age IS NOT NULL 
  AND patient_sat_score IS NOT NULL
GROUP BY age_bucket
ORDER BY avg_satisfaction DESC;

-- 4. Racial Equity in Care:
--    - Do patient wait times or satisfaction differ significantly by race?
SELECT
	patient_race,
	AVG(patient_sat_score) AS avg_satisfaction,
	AVG(patient_waittime) AS avg_waittime
FROM healthcare_patients
WHERE patient_race != 'Declined to Identify'
GROUP BY patient_race
ORDER BY avg_satisfaction DESC, avg_waittime DESC;


-- 5. Referral Patterns:
--    - Which departments receive the most referrals, and do they correlate with longer wait times?
SELECT
	department_referral,
	COUNT(department_referral) AS referral_count,
	ROUND(AVG(patient_waittime),3) AS avg_waittime
FROM healthcare_patients
WHERE department_referral != 'None'
GROUP BY department_referral
ORDER BY referral_count DESC;

-- 6. Administrative Impact:
--    - Do patients with patient_admin_flag = TRUE experience longer wait times 
--      or lower satisfaction?
SELECT
	'Admin Flag = TRUE' AS admin_status,
	AVG(patient_waittime) AS avg_waittime_flag,
	AVG(patient_sat_score) AS avg_satisfaction_flag
FROM healthcare_patients
WHERE patient_admin_flag = TRUE
UNION ALL
SELECT
	'Admin Flag = FALSE' AS admin_status,
	AVG(patient_waittime) AS avg_waittime_noflag,
	AVG(patient_sat_score) AS avg_satisfaction_noflag
FROM healthcare_patients
WHERE patient_admin_flag = FALSE;


-- 7. Top Departments by Satisfaction:
--    - Which departments have the highest average patient satisfaction scores?
WITH dept_avg AS (
    SELECT
        department_referral,
        ROUND(AVG(patient_sat_score)::numeric, 2) AS avg_satisfaction
    FROM healthcare_patients
    WHERE department_referral IS NOT NULL
      AND department_referral != 'None'
    GROUP BY department_referral
)
SELECT
    department_referral,
    avg_satisfaction,
    RANK() OVER (ORDER BY avg_satisfaction DESC) AS satisfaction_rank
FROM dept_avg
ORDER BY satisfaction_rank;


-- 8. Trend Over Time:
--    - How have patient satisfaction and wait times changed over months/years?

WITH monthly_stats AS (
    SELECT
        EXTRACT(YEAR FROM visit_date) AS year,
        EXTRACT(MONTH FROM visit_date) AS month,
        ROUND(AVG(patient_sat_score)::numeric, 2) AS avg_satisfaction,
        ROUND(AVG(patient_waittime)::numeric, 2) AS avg_waittime,
        COUNT(*) AS patient_count
    FROM healthcare_patients
    WHERE patient_sat_score IS NOT NULL 
      AND patient_waittime IS NOT NULL
    GROUP BY EXTRACT(YEAR FROM visit_date), EXTRACT(MONTH FROM visit_date)
)
SELECT
    year,
    month,
    avg_satisfaction,
    avg_waittime,
    patient_count
FROM monthly_stats
ORDER BY year, month;
