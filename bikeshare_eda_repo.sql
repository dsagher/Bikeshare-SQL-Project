create temp view iqr as -- view created: calculates 1st, 2nd, 3rd quartile, IQR, and upper bound, split by year 

select date_part('year', start_time) as year,
percentile_cont(.25) within group (order by age(end_time, start_time))
as Q1,
percentile_cont(.5) within group (order by age(end_time, start_time))
as Q2,
percentile_cont(.75) within group (order by age(end_time, start_time))
as Q3,
(percentile_cont(.75) within group (order by age(end_time, start_time))-
(percentile_cont(.25) within group (order by age(end_time, start_time)))) 
as IQR,
(percentile_cont(.75) within group (order by age(end_time, start_time))) + 
(1.5 * (percentile_cont(.75) within group (order by age(end_time, start_time))-
(percentile_cont(.25) within group (order by age(end_time, start_time))))) as upper_bound
from db_all_years
group by 1

--------------------------------------------

create temp table db_all_years_no_outliers as -- temp table created: all years with no ouliters 
select *
from public.divvybikes_2019 b19
where age(end_time, start_time) <= (select upper_bound from iqr where year = 2019)
union
select *
from public.divvybikes_2018 b18
where age(end_time, start_time) <= (select upper_bound from iqr where year = 2018)
union
select *
from public.divvybikes_2017 b17
where age(end_time, start_time) <= (select upper_bound from iqr where year = 2017)
union
select *
from public.divvybikes_2016 b16
where age(end_time, start_time) <= (select upper_bound from iqr where year = 2016)

----------------------------------

create temp table db_all_years as -- temp table created: all years with outliers
select *
from public.divvybikes_2019 b19
union
select *
from public.divvybikes_2018 b18
union
select *
from public.divvybikes_2017 b17
union
select *
from public.divvybikes_2016 b16

select * from db_all_years
select * from db_all_years_no_outliers

drop table db_all_years
drop table db_all_years_no_outliers

----------------------------------------- 

-- number of trips by gender over time

select count(trip_id) total_trips,
gender,
date_part('year', start_time) as year
from db_all_years_no_outliers
where gender is not null
group by 2, 3
order by 3 asc, 1 desc

----------------------------------------------------------------

-- weekday trip count by usertype 

select
	to_char(start_time, 'HH24')::integer as weekend_start_hour,
	count(case when user_type = 'Customer' then 1 end) as customer_count,
	count(case when user_type = 'Subscriber' then 1 end) as subscriber_count
from db_all_years_no_outliers
where trim(to_char(start_time, 'Day')) not in ('Saturday','Sunday')
group by 1
order by 1

-- weekend trip count by usertype

select
	to_char(start_time, 'HH24') as weekend_start_hour,
	count(case when user_type = 'Customer' then 1 end) as customer_count,
	count(case when user_type = 'Subscriber' then 1 end) as subscriber_count
from db_all_years_no_outliers
where trim(to_char(start_time, 'Day')) in ('Saturday','Sunday')
group by 1
order by 1

----------------------------------------------------------

-- count of long rides above 6 hours to above 6 months 

select sum(case when extract(hour from age(end_time, start_time)) >= 6 then 1 else 0 end) as above_6_hours,
	   sum(case when extract(day from age(end_time, start_time)) >= 1 then 1 else 0 end) as above_1_day,
	   sum(case when extract(month from age(end_time, start_time)) >= 1 then 1 else 0 end) as above_1_month,
	   sum(case when extract(month from age(end_time, start_time)) >= 2 then 1 else 0 end) as above_2_months,
	   sum(case when extract(month from age(end_time, start_time)) >= 3 then 1 else 0 end) as above_3_months,
	   sum(case when extract(month from age(end_time, start_time)) >= 4 then 1 else 0 end) as above_4_months,
	   sum(case when extract(month from age(end_time, start_time)) >= 5 then 1 else 0 end) as above_5_months,
	   sum(case when extract(month from age(end_time, start_time)) >= 6 then 1 else 0 end) as above_6_months
from db_all_years

--------------------------------------------------------------------

-- share of user_type over 4 years 

select date_part('year', start_time) as year,
user_type,
count(*) as users, 
concat((
	round(count(*)/ SUM(count(*)) over(partition by date_part('year', start_time)), 2) * 100), '%')
	as share_of_users
from db_all_years_no_outliers
where user_type != 'Dependent'
group by 1, 2, date_part('year', start_time)
order by 1, 3

-----------------------------------------------------

-- user birth year, age over time

select date_part('year', start_time) as year,
round(avg(birthyear)) avg_birthyear, 
gender, 
round(avg(date_part('year', start_time) - birthyear)) as age
from db_all_years_no_outliers
where birthyear is not null and gender is not null
group by 1,3
order by 1,3

----------------------------------------------------

-- overall numbers 2016-2019

select date_part('year', start_time) as year,
	count(*) total
from db_all_years_no_outliers
group by 1

------------------------------------------------------

-- overal number of trips by season

select 
date_part('year', start_time) as year,
count(trip_id) total_per_season,
case
	when to_char(start_time, 'MMDD')::numeric between 320 and 621 then 'Spring'
	when to_char(start_time, 'MMDD')::numeric between 621 and 922 then 'Summer'
	when to_char(start_time, 'MMDD')::numeric between 922 and 1221 then 'Fall'
	else 'Winter' end as seasons
from db_all_years
group by 1, 3
order by 1, 2 desc

------------------------------------------------------------------

-- top 10 stations by total trips, split by year and user type

select year, total_trips, id, name, row_num, subscribers, customers
from (
	select
	row_number() over(partition by date_part('year', db.start_time) order by count(db.trip_id) desc) as row_num,
	date_part('year', db.start_time) as year,
	s.id,
	s.name,
	count(case when user_type like 'Subscriber' then 1 else null end) as subscribers,
	count(case when user_type like 'Customer' then 1 else null end) as customers,
	count(db.trip_id) as total_trips
	from db_all_years_no_outliers db
	join public.divvy_stations s on db.start_station_id = s.id
	group by 2, 3, 4
	order by 2
) as t1
where row_num <= 10

-----------------------------------------------------------------

-- calculating nulls

select
  count(case when birthyear is null then 1 end) as null_count,
  count(case when birthyear is not null then 1 end) as not_null_count,
  (count(case when birthyear is null then 1 end) * 100.0 / count(*)) as total_null_percent,
  (count(case when birthyear is not null then 1 end)) * 100.0 / count(*)) as total_not_null_percent
from db_all_years;

select
  count(case when gender is null then 1 end) as null_count,
  count(case when gender is not null then 1 end) as not_null_count,
  (count(case when gender is null then 1 end) * 100.0 / count(*)) as total_null_percent,
  (count(case when gender is not null then 1 end) * 100.0 / count(*)) as total_not_null_percent
from db_all_years;

------------------------------------------------------------------

-- gender breakdown with percentage of whole 

select 
    count(case when gender = 'Male' then 1 end) as male_count,
    count(case when gender = 'Female' then 1 end) as female_count,
    100.0 * count(case when gender = 'Male' then 1 end) / sum(count(*)) over() as male_percentage,
    100.0 * count(case when gender = 'Female' then 1 end) / sum(count(*)) over() as female_percentage,
from 
    db_all_years
where 
    gender is not null
group by 
    gender;
	
----------------------------------------------------------------

-- count number of trips for each start station/end station pair with geospatial info
-- for csv export into local server for spider viz 

select 
	db.start_station_id,
	dss.name start_station_name,
	db.end_station_id,
	dse.name end_station_name,
	dss.name||'---'||dse.name route_name,
	count(trip_id) count_of_trips,
	date_part('year', db.start_time) as year,
	dss.latitude start_lat,
	dss.longitude start_long,
	dse.latitude end_lat,
	dse.longitude end_long,
from 
	db_all_years db
join
	public.divvy_stations dss on db.start_station_id = dss.id
join 
	public.divvy_stations dse on db.end_station_id = dse.id
where start_station_id != end_station_id
group by 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12
having count(trip_id) > 10
order by 7, 5, 6
