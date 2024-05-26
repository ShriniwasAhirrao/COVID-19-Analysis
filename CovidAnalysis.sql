-- Querying all records from CovidDeaths$ table
SELECT * 
FROM covid_analysis..CovidDeaths$
ORDER BY 3, 4;

-- Querying all records from CovidVaccinations$ table
SELECT * 
FROM covid_analysis..CovidVaccinations$
ORDER BY 3, 4;

-- Selecting specific columns from CovidDeaths$ table
SELECT Location, date, total_cases, new_cases, total_deaths, population
FROM CovidDeaths$
ORDER BY 1, 2;

-- Calculating the death percentage for India
SELECT Location, date, total_cases, total_deaths, (total_deaths / total_cases) * 100 AS DeathPercentage
FROM CovidDeaths$
WHERE location LIKE '%india%'
ORDER BY 1, 2;

-- Calculating the infection rate for India
SELECT Location, date, population, total_cases, (total_cases / population) * 100
AS 'Infection_Rate (%)'
FROM CovidDeaths$
WHERE location LIKE '%india%'
ORDER BY 1, 2;

-- Countries with the highest infection rate compared to population
SELECT Location, population, MAX(total_cases) AS HighestInfectionCount, 
MAX((total_cases / population)) * 100 AS 'Infection_Rate (%)'
FROM CovidDeaths$
GROUP BY Location, population
ORDER BY 4 DESC;

-- Filtering results where continent is not null
SELECT * 
FROM covid_analysis..CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 3, 4;

-- Showing countries with the highest death count per population
SELECT Location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidDeaths$
WHERE continent IS NOT NULL
GROUP BY Location
ORDER BY 2 DESC;

-- Breaking down by continent to show highest death count
SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidDeaths$
WHERE continent IS NULL
GROUP BY location
ORDER BY 2 DESC;

-- Showing highest death count in continent
SELECT continent, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidDeaths$
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY 2 DESC;

-- Global numbers by date
SELECT date, SUM(new_cases) AS Total_Cases, SUM(CAST(new_deaths AS INT)) 
AS Total_Deaths, SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100 AS DeathPercentage 
FROM CovidDeaths$
WHERE continent IS NOT NULL 
GROUP BY date 
ORDER BY 1, 2;

-- Total global numbers
SELECT SUM(new_cases) AS Total_Cases, SUM(CAST(new_deaths AS INT)) 
AS Total_Deaths, SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100 AS DeathPercentage 
FROM CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 1, 2;

-- Joining CovidDeaths$ and CovidVaccinations$ tables
SELECT * 
FROM covid_analysis..CovidDeaths$ dea
JOIN covid_analysis..CovidVaccinations$ vac 
    ON dea.location = vac.location
    AND dea.date = vac.date;

-- Looking at total population vs vaccinations
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
FROM covid_analysis..CovidDeaths$ dea
JOIN covid_analysis..CovidVaccinations$ vac 
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL 
ORDER BY 1, 2, 3;

-- Using CTE to perform calculation on partition by in the previous query
WITH PopVsVac(Continent, location, Date, Population, vac_new_vaccinations, RollingPeopleVaccinated) AS
(
    SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
    SUM(CONVERT(INT, vac.new_vaccinations)) 
	OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
    FROM covid_analysis..CovidDeaths$ dea
    JOIN covid_analysis..CovidVaccinations$ vac 
        ON dea.location = vac.location
        AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT * 
FROM PopVsVac 
ORDER BY 2, 3;

-- Using Temp Table to perform calculation on partition by in the previous query
DROP TABLE IF EXISTS #PercentPopulationVaccinated;

CREATE TABLE #PercentPopulationVaccinated
(
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
    SUM(CONVERT(INT, vac.new_vaccinations)) 
	OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM covid_analysis..CovidDeaths$ dea
JOIN covid_analysis..CovidVaccinations$ vac
    ON dea.location = vac.location
    AND dea.date = vac.date;

SELECT *, (RollingPeopleVaccinated / Population) * 100 AS 'PercentPopulationVaccinated'
FROM #PercentPopulationVaccinated;

-- Creating View to store data for later visualizations
CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
    SUM(CONVERT(INT, vac.new_vaccinations)) 
	OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM covid_analysis..CovidDeaths$ dea
JOIN covid_analysis..CovidVaccinations$ vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;




-----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------



--if there's a noticeable decline in COVID-19 cases and deaths in countries with high vaccination rates over a period.
select dea.location, dea.date, 
       SUM(TRY_CAST(dea.new_cases AS int)) as TotalNewCases, 
       SUM(TRY_CAST(dea.new_deaths AS int)) as TotalNewDeaths,
       SUM(TRY_CAST(vac.new_vaccinations AS int)) as TotalNewVaccinations
from covid_analysis..CovidDeaths$ dea
join covid_analysis..CovidVaccinations$ vac 
  on dea.location = vac.location 
  and dea.date = vac.date
group by dea.location, dea.date
order by dea.location, dea.date;



-- Impact of Vaccinations on Death Rates

SELECT dea.location, 
       dea.date, 
       SUM(CAST(dea.new_cases AS int)) as TotalNewCases, 
       SUM(CAST(dea.new_deaths AS int)) as TotalNewDeaths,
       (SUM(CAST(dea.new_deaths AS int)) / NULLIF(SUM(CAST(dea.new_cases AS int)), 0)) * 100 as DeathRate,
       SUM(CAST(vac.new_vaccinations AS int)) as TotalNewVaccinations,
       (SUM(CAST(vac.new_vaccinations AS int)) / NULLIF(dea.population, 0)) * 100 as VaccinationRate
FROM covid_analysis..CovidDeaths$ dea
JOIN covid_analysis..CovidVaccinations$ vac 
  ON dea.location = vac.location 
  AND dea.date = vac.date
GROUP BY dea.location, dea.date, dea.population
ORDER BY dea.location, dea.date;


-- location with the highest vaccination rate 
WITH VaccinationRates AS (
    SELECT dea.location,
           dea.continent,
           SUM(CAST(vac.new_vaccinations AS int)) AS TotalNewVaccinations,
           (SUM(CAST(vac.new_vaccinations AS int)) / NULLIF(dea.population, 0)) * 100 AS VaccinationRate
    FROM covid_analysis..CovidDeaths$ dea
    JOIN covid_analysis..CovidVaccinations$ vac 
      ON dea.location = vac.location 
      AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
    GROUP BY dea.location, dea.continent, dea.population
)

SELECT continent,
       location,
       MAX(VaccinationRate) AS HighestVaccinationRate
FROM VaccinationRates
GROUP BY continent, location
ORDER BY continent, HighestVaccinationRate DESC;


-- top 10 locations with the highest vaccination rates where the continent is not null

WITH VaccinationRates AS (
    SELECT dea.location,
           dea.continent,
           SUM(CAST(vac.new_vaccinations AS int)) AS TotalNewVaccinations,
           (SUM(CAST(vac.new_vaccinations AS int)) / NULLIF(dea.population, 0)) * 100 AS VaccinationRate,
           ROW_NUMBER() OVER (ORDER BY (SUM(CAST(vac.new_vaccinations AS int)) / NULLIF(dea.population, 0)) DESC) AS Rank
    FROM covid_analysis..CovidDeaths$ dea
    JOIN covid_analysis..CovidVaccinations$ vac 
      ON dea.location = vac.location 
      AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
    GROUP BY dea.location, dea.continent, dea.population
)

SELECT continent ,location,
       VaccinationRate AS HighestVaccinationRate
FROM VaccinationRates
WHERE Rank <= 10
ORDER BY HighestVaccinationRate DESC;



-- to check Effectiveness of Vaccination Over Time

SELECT dea.location, 
       YEAR(dea.date) as Year, 
       MONTH(dea.date) as Month, 
       SUM(CAST(dea.new_cases AS int)) as MonthlyNewCases, 
       SUM(CAST(dea.new_deaths AS int)) as MonthlyNewDeaths,
       SUM(CAST(vac.new_vaccinations AS int)) as MonthlyNewVaccinations,
       (SUM(CAST(vac.new_vaccinations AS int)) / NULLIF(dea.population, 0)) * 100 as MonthlyVaccinationRate
FROM covid_analysis..CovidDeaths$ dea
JOIN covid_analysis..CovidVaccinations$ vac 
  ON dea.location = vac.location 
  AND dea.date = vac.date
GROUP BY dea.location, YEAR(dea.date), MONTH(dea.date), dea.population
ORDER BY dea.location, YEAR(dea.date), MONTH(dea.date);

