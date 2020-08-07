CREATE TABLE [dbo].[D2LGradeData](
	[ROWNUMBER] [nvarchar](100) NOT NULL,
	[GRADEITMID] [nvarchar](50) NOT NULL,
	[ORGUNITID.x] [nvarchar](200) NOT NULL,
	[TYPE] [nvarchar](150) NOT NULL,
	[COURSENAME] [nvarchar](150) NOT NULL,
	[STARTDATE] [nvarchar](100) NOT NULL,
	[ENDDATE] [nvarchar](75) NOT NULL,
	[ROLENAME] [ntext] NOT NULL,
	[ENROLLMENTDATE] [nvarchar](75) NOT NULL,
	[ASSIGNMENTNAME] [nvarchar](75) NOT NULL,
	[NAME.y] [nvarchar](1000) NOT NULL,
	[DUEDATE] [datetime2](7) NOT NULL,
	[PARENTGRADEOBJECTID] [nvarchar](100) NOT NULL,
	[NAME] [nvarchar](500) NOT NULL,
	[TYPENAME] [nvarchar](150) NOT NULL,
	[CATAGORYNAME] [nvarchar](500) NOT NULL,
	[MAXPOINTS] [nvarchar](200) NOT NULL,
	[ORGUNTID x.1] [nvarchar](50) NOT NULL,
	[SCORE] [nvarchar](100) NULL,
	[ISGRADED] [nvarchar](100) NOT NULL,
	[LASTSUBMISSIONDATE] [datetime2] NOT NULL,
	[ORGUNTID.y.1] [nvarchar](100) NOT NULL,
	[POINTSNUMERATOR] [numeric](10, 5) NOT NULL,
	[POINTSDENOMINATOR] [numeric](10,5) NOT NULL,
	[WEIGHTEDDENOMINATOR] [numeric](10,5) NULL,
	[ISDROPPED] [nvarchar](50) NULL,
	[new_ID] [nvarchar](200) NULL
)

USE UAHub
BULK INSERT D2LGradeData
FROM 'F:\Imports\D2Lgradedata_Deidentified.txt'
WITH (FIELDTERMINATOR = ‘\t’, FIRSTROW=2)
ALTER TABLE D2LGradeData 
ADD [GradePercentage] [numeric](10,5)

UPDATE D2LGradeData
SET GradePercentage = [POINTSNUMERATOR]/[POINTSDENOMINATOR]
WHERE POINTSDENOMINATOR <> 0

ALTER TABLE D2LGradeData 
ADD [COURSENAMELENGTH][int]

UPDATE D2LGradeData 
SET COURSENAMELENGTH = LEN(COURSENAME)



CREATE TABLE Enrollment(
[new_ID] [nvarchar](200) NULL, 
[COURSEID] [nvarchar](200) NOT NULL,)

INSERT INTO Enrollment
SELECT DISTINCT new_ID, [ORGUNITID.x]
FROM D2LGradeData


USE UAHub
CREATE TABLE OrgunitsWithParents (
[ORGUNITID][numeric],
[PARENTORGUNITID][nvarchar](50),
[ROWVERSION][nvarchar](75),
[LOAD_ERROR][nvarchar](25),
[DATA_ORIGIN][nvarchar](25),
[CREATED_EW_DTTM][date], 
[LASTUPD_EW_DTTM][date], 
[BATCH_SID][int])

BULK INSERT OrgunitsWithParents 
FROM 'F:\Imports\20200731_orgunits_with_parents.csv'
WITH(FIRSTROW = 2 , FIELDTERMINATOR = ',')

UPDATE OrgunitsWithParents
SET PARENTORGUNITID = TRIM('""' FROM PARENTORGUNITID )
FROM OrgunitsWithParents


USE UAHub
CREATE TABLE [dbo].[CourseNameAssignments](
	[PARENTORGUNITID] [nvarchar](50) NULL,
	[TYPE] [nvarchar](500) NULL,
	[COURSENAME] [nvarchar](500) NULL,
	[CODE] [nvarchar](500) NULL,
	[ISACTIVE] [nvarchar](10) NULL
) ON [PRIMARY]
GO


BULK INSERT CourseNameAssignments
FROM 'F:\Imports\20200720_units_v2.txt'
WITH(FIRSTROW = 2 , FIELDTERMINATOR = '\t')

CREATE TABLE TempTable4 (
[ORGUNITID][int],
[PARENTORGUNITID][nvarchar](75))

INSERT INTO TempTable4
SELECT DISTINCT D2LGradeData.[ORGUNITID.x], OrgunitsWithParents.PARENTORGUNITID
FROM D2LGradeData 
INNER JOIN OrgunitsWithParents ON D2LGradeData.[ORGUNITID.x] = OrgunitsWithParents.ORGUNITID


USE UAHub
INSERT INTO Course
SELECT DISTINCT TempTable4.ORGUNITID,CourseNameAssignments.COURSENAME
FROM TempTable4
JOIN CourseNameAssignments ON TempTable4.PARENTORGUNITID = CourseNameAssignments.PARENTORGUNITID
WHERE CourseNameAssignments.[TYPE] = 'Course Template'

Assignment Table 
CREATE TABLE [dbo].[Assignment](
	[COURSEID] [nvarchar](200) NOT NULL,
	[ASSIGNMENTID] [nvarchar](50) NOT NULL,
	[ASSIGNMENTNAME] [nvarchar](1000) NOT NULL,
	[WEIGHT] [nvarchar](50) NULL,
	[DUEDATE] [datetime2](7) NULL,
) ON [PRIMARY]
GO


USE UAHub
INSERT INTO Assignment
SELECT DISTINCT
       D2LGradeData.[ORGUNITID.x]
	  ,D2LGradeData.GRADEITMID
	  ,D2lGradedata.[NAME.y]
	  ,D2LGradeData.WEIGHTEDDENOMINATOR
	  ,D2LGradeData.DUEDATE
	  FROM  (SELECT TempTable2.COURSEID, TempTable2.[ASSIGNMENTID], MAX(D2LGradeData.DUEDATE) AS DUEDATE, MIN(D2LGradeData.WEIGHTEDDENOMINATOR) AS WEIGHTEDDENOMINATOR FROM D2LGradeData JOIN TempTable2 ON  D2LGradeData.[GRADEITMID] = TempTable2.[ASSIGNMENTID] WHERE TempTable2.[ASSIGNMENTID] = D2LGradeData.[gradeitmid] GROUP BY temptable2.COURSEID, temptable2.[ASSIGNMENTID]) AS A LEFT JOIN D2LGradeData ON	  D2LGradeData.[ORGUNITID.x]=A.COURSEID AND D2LGradeData.[GRADEITMID]=A.[ASSIGNMENTID] AND D2LGradeData.DUEDATE = A.DUEDATE AND D2LGradeData.WEIGHTEDDENOMINATOR=A.WEIGHTEDDENOMINATOR
ORDER BY [NAME.y]

ALTER TABLE Assignment 
ADD [IsVerified][bit]

UPDATE Assignment 
SET IsVerified = 1 


CREATE TABLE Grade(
[new_ID] [nvarchar](200) NULL, 
[COURSEID] [nvarchar](200) NOT NULL,
[ASSIGNMENTID][nvarchar](50) NOT NULL,
[GRADE] [numeric](10, 5) NULL)

INSERT INTO Grade 
SELECT DISTINCT  D2LGradeData.new_ID, D2LGradeData.[ORGUNITID.x], D2LGradeData.[GRADEITMID], GradeDataExport.GRADEPERCENTAGE
FROM D2LGradeData
RIGHT JOIN GradeDataExport ON D2LGradeData.new_ID = .GradeDataExport.new_ID

USE UAHub 
INSERT INTO Grade
SELECT DISTINCT
	   D2LGradeData.[new_ID] 
	  ,D2LGradeData.[ORGUNTID x.1]
	  ,D2LGradeData.[GRADEITMID]
	  ,D2LGradeData.[GradePercentage]
	  FROM  (SELECT TempTable1.new_ID, TempTable1.[ASSIGNMENTID], MAX(GradePercentage) AS GradePercentage FROM D2LGradeData JOIN TempTable1 ON  D2LGradeData.[GRADEITMID] = TempTable1.[ASSIGNMENTID] WHERE TempTable1.[New_ID] = D2LGradeData.[New_ID] GROUP BY temptable1.New_ID, temptable1.[ASSIGNMENTID]) AS A LEFT JOIN D2LGradeData ON D2LGradeData.new_ID=A.New_ID AND D2LGradeData.[GRADEITMID]=A.ASSIGNMENTID AND D2LGradeData.GradePercentage = A.GradePercentage


