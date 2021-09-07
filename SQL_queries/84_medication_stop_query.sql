# get a table of all rows of medication 84 in the therapy table
CREATE TABLE oliver.therapy_84_single_row AS
SELECT * FROM 17_205R_Providencia.therapy
WHERE bnfcode = 84;

# get a list of patients that recieve medication 84 at some point in their therapy
CREATE TABLE oliver.patids_84 AS
SELECT DISTINCT patid FROM oliver.therapy_84_single_row;

# add indexing in on eventdate in therapy_single_row
ALTER TABLE `oliver`.`therapy_84_single_row` 
ADD INDEX `eventdate_idx` (`eventdate` ASC);

# get dates of first and last instances of 84 coded in the therapy data for this group of patients
CREATE TABLE oliver.eventdates_84 AS
SELECT patid, max(eventdate) AS max_eventdate_84, min(eventdate) AS min_eventdate_84
FROM oliver.therapy_84_single_row
GROUP BY patid;

# get date of last entry in therapy table for this list of patients
CREATE TABLE oliver.enddate_84 AS
SELECT t.patid, max(t.eventdate) AS max_eventdate
FROM 17_205R_Providencia.therapy AS t
INNER JOIN oliver.eventdates_84 AS s ON s.patid=t.patid
GROUP BY t.patid;

# join the eventdates and enddate tables and create a new flag:
	# 1 if last date of data entry more than 84 days after last date of medication 84
	# 0 if last date of medication 84 is within 84 days of last data entry
CREATE TABLE oliver.flags_84 AS
SELECT t.patid, s.min_eventdate_84, 
	   IF(s.max_eventdate_84 - INTERVAL 6 MONTH < s.min_eventdate_84, 
		  s.min_eventdate_84, s.max_eventdate_84 - INTERVAL 6 MONTH) AS max_eventdate_84_less_6_month,
	   s.max_eventdate_84, t.max_eventdate,
	   IF(t.max_eventdate > (s.max_eventdate_84 + INTERVAL 84 DAY), 1, 0) AS stopped_in_data
FROM oliver.enddate_84 AS t
INNER JOIN oliver.eventdates_84 AS s ON s.patid=t.patid;

#################################################################################################################

# this code is going straight in to command prompt on idhs server

# need clinical data from last instance of 84 to 84 days after AS clinical_84_max_84_after
# need clinical data from prior to 84 days after last instance of 84 to start AS clinical_84
# need therapy data for 84 days prior to first instance of 84 AS therapy_84_min_84_before
# need therapy data for 84 days prior to 6 months before the last instance of 84 AS therapy_84_max_6_mnth_84_before
# need flags data AS flags_84
# need patient data AS patient_84

SELECT s.* FROM oliver.flags_84 AS t
LEFT JOIN 17_205R_Providencia.clinical AS s
ON t.patid=s.patid
WHERE s.eventdate BETWEEN t.max_eventdate_84
					  AND t.max_eventdate_84 + INTERVAL 84 DAY 
INTO OUTFILE '/data/mysql-files/clinical_84_max_84_after.txt';

SELECT s.* FROM oliver.flags_84 AS t
LEFT JOIN 17_205R_Providencia.clinical AS s
ON t.patid=s.patid
WHERE s.eventdate <= t.max_eventdate_84 + INTERVAL 84 DAY 
INTO OUTFILE '/data/mysql-files/clinical_84.txt';

SELECT s.* FROM oliver.flags_84 AS t
LEFT JOIN 17_205R_Providencia.therapy AS s
ON t.patid=s.patid
WHERE s.eventdate BETWEEN t.min_eventdate_84 - INTERVAL 84 DAY
					  AND t.min_eventdate_84 
INTO OUTFILE '/data/mysql-files/therapy_84_min_84_before.txt';

SELECT s.* FROM oliver.flags_84 AS t
LEFT JOIN 17_205R_Providencia.therapy AS s
ON t.patid=s.patid
WHERE s.eventdate BETWEEN t.max_eventdate_84_less_6_month - INTERVAL 84 DAY
					  AND t.max_eventdate_84_less_6_month 
INTO OUTFILE '/data/mysql-files/therapy_84_max_6_mnth_84_before.txt';

SELECT * FROM 17_205R_Providencia.patient
WHERE patid IN (SELECT patid FROM oliver.flags_84)


