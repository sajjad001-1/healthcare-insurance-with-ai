CREATE DATABASE healthcare;
USE healthcare;
CREATE TABLE healthcare_benefits (
    PlanId VARCHAR(50),
    StateCode VARCHAR(10),
    BenefitName VARCHAR(255),
    BusinessYear INT,
    CopayInNetwork VARCHAR(100),
    CoinsuranceInNetwork VARCHAR(100),
    LimitQty INT DEFAULT NULL,
    LimitUnit VARCHAR(100),
    Exclusions TEXT,
    Explanation TEXT
);
SELECT * FROM healthcare_benefits;

SELECT StateCode,COUNT(*) AS Totalrecords FROM healthcare_benefits
GROUP BY StateCode
ORDER BY Totalrecords DESC;

SELECT DISTINCT BenefitName FROM healthcare_benefits
WHERE BenefitName LIKE '%Inpatient%' OR BenefitName LIKE '%Outpatient%';

SELECT 
    BusinessYear, 
    COUNT(DISTINCT PlanId) AS UniquePlansCount
FROM 
    healthcare_benefits
GROUP BY 
    BusinessYear
ORDER BY 
    BusinessYear ASC;

SELECT 
    PlanId,
    BenefitName, 
    CopayInNetwork,
    -- Convert text to a decimal value for accurate sorting
    CAST(REPLACE(REPLACE(CopayInNetwork, '$', ''), ',', '') AS DECIMAL(10,2)) AS CleanedCopay
FROM 
    healthcare_benefits
WHERE 
    CopayInNetwork IS NOT NULL 
    -- Keep only rows that contain actual numbers
    AND CopayInNetwork REGEXP '[0-9]' 
ORDER BY 
    CleanedCopay DESC
LIMIT 5;

SELECT 
    StateCode, 
    COUNT(*) AS BiotechRecordsCount
FROM 
    healthcare_benefits
WHERE 
    BenefitName LIKE '%Specialty Drug%' 
    OR BenefitName LIKE '%Biologic%'
    OR Explanation LIKE '%Specialty Drug%' 
    OR Explanation LIKE '%Biologic%'
    OR Explanation LIKE '%Genetic%'
GROUP BY 
    StateCode
ORDER BY 
    BiotechRecordsCount DESC;
    
    SELECT 
    BenefitName, 
    LimitQty, 
    LimitUnit
FROM 
    healthcare_benefits
WHERE 
    LimitQty IS NOT NULL
ORDER BY 
    LimitQty DESC;
    
    SELECT 
    StateCode,
    MIN(CAST(REPLACE(REPLACE(CopayInNetwork, '$', ''), ',', '') AS DECIMAL(10,2))) AS MinERCopay,
    MAX(CAST(REPLACE(REPLACE(CopayInNetwork, '$', ''), ',', '') AS DECIMAL(10,2))) AS MaxERCopay
FROM 
    healthcare_benefits
WHERE 
    BenefitName LIKE '%Emergency Room%'
    AND CopayInNetwork IS NOT NULL
    AND CopayInNetwork REGEXP '[0-9]'
GROUP BY 
    StateCode
ORDER BY 
    MaxERCopay DESC;
    
    WITH StateBenefitVariety AS (
    SELECT 
        StateCode,
        COUNT(DISTINCT BenefitName) AS UniqueBenefitCount,
        DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT BenefitName) DESC) AS StateRank
    FROM 
        healthcare_benefits
    WHERE 
        BusinessYear = 2016
    GROUP BY 
        StateCode
)
SELECT 
    StateCode, 
    UniqueBenefitCount, 
    StateRank
FROM 
    StateBenefitVariety
WHERE 
    StateRank <= 3;
    
    SELECT 
    COUNT(*) AS TotalRecords,
    -- Count rows where Exclusions column actually has text
    SUM(CASE WHEN Exclusions IS NOT NULL AND Exclusions != '' THEN 1 ELSE 0 END) AS RecordsWithExclusions,
    -- Calculate Percentage
    (SUM(CASE WHEN Exclusions IS NOT NULL AND Exclusions != '' THEN 1 ELSE 0 END) / COUNT(*)) * 100 AS ExclusionsPercentage
FROM 
    healthcare_benefits;
    
WITH MultiStatePlans AS (
    SELECT 
        PlanId,
        COUNT(DISTINCT StateCode) AS TotalStatesCovered
    FROM 
        healthcare_benefits
    WHERE 
        PlanId IS NOT NULL 
        AND PlanId != ''          -- 🌟 This removes the empty/blank space rows!
        AND PlanId != ' '         -- This removes hidden single spaces
    GROUP BY 
        PlanId
)
SELECT 
    PlanId, 
    TotalStatesCovered
FROM 
    MultiStatePlans
WHERE 
    TotalStatesCovered >= 1       -- Change to >= 1 to see your valid data records
ORDER BY 
    TotalStatesCovered DESC
LIMIT 10;

CREATE TABLE healthcare_rates (
    BusinessYear INT,
    StateCode VARCHAR(10),
    PlanId VARCHAR(50),
    Age VARCHAR(20),
    IndividualRate DECIMAL(10,2),
    IndividualTobaccoRate DECIMAL(10,2)
);
SELECT 
    b.StateCode,
    r.Age,
    AVG(r.IndividualRate) AS AvgInsurancePremium,
    COUNT(DISTINCT b.PlanId) AS TotalMatchingPlans
FROM 
    healthcare_benefits b
INNER JOIN 
    healthcare_rates r ON LEFT(TRIM(b.PlanId), 14) = LEFT(TRIM(r.PlanId), 14)
                      AND b.BusinessYear = r.BusinessYear
WHERE 
    b.BenefitName LIKE '%Specialty Drug%'
    AND r.IndividualRate IS NOT NULL
GROUP BY 
    b.StateCode, 
    r.Age
ORDER BY 
    AvgInsurancePremium DESC;    
    
SELECT 
    b.BusinessYear,
    b.StateCode,
    COUNT(DISTINCT r.PlanId) AS TotalActivePlans,
    ROUND(AVG(r.IndividualRate), 2) AS AvgStandardPremium,
    -- 🌟 COALESCE checks if the result is NULL and replaces it with our text label
    COALESCE(
        CAST(ROUND(MAX(r.IndividualTobaccoRate), 2) AS CHAR), 
        'No Smoker Penalty'
    ) AS MaxTobaccoPremium
FROM 
    healthcare_benefits b
INNER JOIN 
    healthcare_rates r ON LEFT(TRIM(b.PlanId), 14) = LEFT(TRIM(r.PlanId), 14)
                      AND b.BusinessYear = r.BusinessYear
WHERE 
    (b.BenefitName LIKE '%Genetic%' OR b.Explanation LIKE '%Genetic%')
    AND r.IndividualRate IS NOT NULL
GROUP BY 
    b.BusinessYear,
    b.StateCode
ORDER BY 
    b.BusinessYear ASC, 
    AvgStandardPremium DESC;    
    