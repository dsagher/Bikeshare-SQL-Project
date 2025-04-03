# DivvyBike SQL Queries
This repo contains two sets of SQL scripts for analyzing DivvyBike data in Chicago.

## Demographic & Spatial Queries

- **gender_age_zip_income**: Joins Chicago's demographic data with geographic info (zip codes, communities) and calculates age group percentages.

- **ranked_biklane_distances**: Measures how close bike stations are to bike lanes and sorts them into distance categories.

- **main_stations**: Combines bike station details (location, name, usage stats) with geospatial info.

- **station_distance**: Computes pairwise distances between stations in a zip, ranks them, and determines directional relationships.

- **bikelanes_view**: Cleans up bike lane data for easier use.

## Customer Segmentation & EDA

- **Ride Time & Outlier Filtering**: Uses quartiles to remove ride duration outliers.

- **Data Union**: Combines trip data from 2016 to 2019 (with and without outliers).

- **Trip Trends**: Counts trips by gender, user type (Customer vs. Subscriber), and hour (weekday/weekend).

- **Long Ride Analysis**: Counts rides lasting from 6 hours to over 6 months.

- **User Distribution & Demographics**: Shows yearly share of user types and average age/birth year trends.

- S**easonal Trends & Top Stations**: Breaks down trips by season and lists the top 10 busiest stations.

- **Missing Data & Gender Breakdown**: Summarizes null values and computes gender percentages.

### Notes
- These queries are designed to be run one after the other to create views/tables for further analysis. 
- PostGIS is required.