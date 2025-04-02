# DivvyBike Bikeshare Project
## Overview
### Objective
The goal of this project was to develop a SQL codebase and visual tool to determine the most effective placement of new bike-sharing stations for Chicago's DivvyBike system. Key factors considered included:

* **Customer Segmentation**
* **Socioeconomic Indicators**
* **Chicago Population Demographics**
* **Inter-Station Proximity**
* **Station Proximity to Bike Lanes**
  
### Data
Data for this project came from multiple sources:

* **Bikeshare data**: Queried from a General Assembly database (read-only access).
* **Socioeconomic and demographic data**: Sourced from Chicago's public data portal.
  
Due to the read-only nature of the General Assembly database, bikeshare data was queried, exported as CSV files, and then merged with population data in Tableau for visualization and analysis.

### SQL Queries
1. `population_zip_community_income_geom`
Joins population statistics (age) and socioeconomic information (per capita income) by zipcode and community boundaries.

2. `ranked_buffer_distances`
Calculates the distance between stations and bikelanes, ranking results from shortest to longest.

3. `main_stations`
Maps station location and performance data to corresponding zipcodes and community boundaries.

4. `station_distance`
Measures distances between a station and all other stations within the same zipcode, ranking station pairs by shortest to longest distance in the four cardinal directions. Outputs:

    * Aggregated min, max, and average distances for station pairs within a zipcode.
    * Classification of stations as below/above the average distance or as the min/max station within their zipcode.
  
### Outputs

* [Blog Post & Visualizations](https://medium.com/@daniel.sagher1/divvybike-expansion-project-dfa427869b93)    
* [Interactive Dashboard](https://public.tableau.com/app/profile/dan.sagher/viz/DivvyDash_17143258974750/Dashboard2)
