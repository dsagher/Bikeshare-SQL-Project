/*=======================================================================

    Title:       <demographic_spatial_queries>
    Author:      <Dan Sagher>
    Date:        <04/01/2024>
    Description:
		This file contains SQL queries, joining Chicago demographic and
		geographic information via spatial joins. This was used to create
		 a map to underlay Chicago's DivvyBike stations to help visualize 
		 correlations between ridership, age, and socioeconomic status.

========================================================================*/
/*
View: gender_age_zip_income
- Population statistics and socioeconomic information by zipcode and community name
- Zipcode and community joined by spatial join
- Population statistics connected by zip code
- Per capita income joined by community/neighborhood name 
*/

create view gender_age_zip_income as 
select distinct z.id zip_id,
	z.zip,
	year,
	sei.per_capita_income,
	initcap(cb.community) community,
	cp."0-17",
	round((cp."0-17"::numeric / cp.total) * 100)||'%' pct_0_17,
	cp."18-29",
	round((cp."18-29"::numeric / cp.total) * 100)||'%' pct_18_29,
	cp."30-39",
	round((cp."30-39"::numeric / cp.total) * 100)||'%' pct_30_39,
	cp."40-49",
	round((cp."40-49"::numeric / cp.total) * 100)||'%' pct_40_49,
	cp."50-59",
	round((cp."50-59"::numeric / cp.total) * 100)||'%' pct_50_59,
	cp."60-69",
	round((cp."60-69"::numeric / cp.total) * 100)||'%' pct_60_69,
	cp."70-79",
	round((cp."70-79"::numeric / cp.total) * 100)||'%' pct_70_79,
	cp."80+",
	round((cp."80+"::numeric / cp.total) * 100)||'%' pct_80_up,
	cp.female,
	cp.male,
	cp.total,
	z.geom as zip_geom,
	cb.geom as boundary_geom
from public.zipcode_4326 z
join 
	public.chicago_population_count cp on cp.zipcode = z.zip
join
	community_boundary cb on st_intersects(cb.geom, z.geom)
join 
	public.socioeconomic_indicators sei on initcap(cb.community) = sei.community_area_name
order by 3

------------------------------------------------------------------
/*
View: ranked_biklane_distances
- Measures distance between stations and bikelanes, ranking list sorted from smallest distance to largest
 */

create view ranked_biklane_distances as
with ranked_distances as (
select 
	s.id,
	ST_Distance(ST_Transform(s.geom, 26916), ST_Transform(bl.geom, 26916)) AS distance,
	s.geom,
	row_number() over (partition by s.id order by ST_Distance(ST_Transform(s.geom, 26916), ST_Transform(bl.geom, 26916))) AS rank
from
	public.all_stations_4326 s
join
	public.bikelane_4326 bl ON ST_DWithin(
		ST_Transform(s.geom, 26916),
		ST_Transform(bl.geom, 26916), 1000)
)
select
    id,
    case
        when distance <= 5 then 'within 5 meters'
        when distance <= 25 then 'within 25 meters'
        when distance <= 50 then 'within 50 meters' 
        when distance <= 100 then 'within 100 meters'
        when distance <= 250 then 'within 250 meters'
        else 'further than 250 meters'
    end as distance_from_bikelane
from
    ranked_distances
where
    rank = 1 
	
------------------------------------------------------------------
/* 
View: main_stations
- View of stations with geospatial description segmented by zipcode and neighborhood
- Top 50 popularity segmented on customer type
*/

create view main_stations as
select 
	s.id station_id,
	s.name,
	s.latitude,
	s.longitude,
	s.docks,
	bc.distance_from_bikelane,
	case when s.id = tc.id then 'top_50_customers' 
		 when s.id = ts.id then 'top_50_subscribers'
		 else 'not_top_50' end as clsf,
	z.zip,
	initcap(ca.community) community,
	s.geom station_geom
from public.all_stations_4326 s
left join 
	public.top_50_customers_4326 tc on tc.id = s.id
left join 
	public.top_50_subscribers_4326 ts on ts.id = s.id
left join 
	ranked_biklane_distances bc on bc.id = s.id
join 
	public.zipcode_4326 z on st_contains(z.geom,s.geom)
join 
	public.community_area_4326 ca on st_contains(ca.geom, s.geom)
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13

------------------------------------------------------------------
/*
View: station_distance
- CTE distance: Creates cartesian product between all stations within one zip code
				measures distance in meters, and ranks each pairing by distance
- CTE distance_stats: Aggregates min, max, avg of distances between paired stations
-- final query: 
	- Pulls together relevant station info, stats info
	- Classifies each station pairing as above or below zip code average
	- Determines direction between station pairs
*/

create view station_distance as

with distance as (
	
	select a.id station_1,
		a.name station_1_name,
		b.id station_2,
		b.name station_2_name,
		z.zip,
		st_distance(st_transform(a.geom, 26916), st_transform(b.geom, 26916)) distance_meters,
		rank() over(partition by a.name order by st_distance(st_transform(a.geom, 26916), st_transform(b.geom, 26916))) as rank,
		st_transform(a.geom, 26916) transform_a_geom,
		st_transform(b.geom, 26916) transform_b_geom
	from 
		public.all_stations_4326 a
	cross join 
		public.all_stations_4326 b
	join 
		public.zipcode_4326 z on st_contains(z.geom, a.geom) and st_contains(z.geom, b.geom)
	where a.id != b.id
	order by 2, 5

), distance_stats as (
	
	select
		zip,
		avg(distance_meters) avg_meters_per_zip,
		min(distance_meters) min_meters_per_zip,
		max(distance_meters) max_meters_per_zip
	from 
		distance
	group by zip
)

select 
	d.rank,
	d.station_1,
	d.station_1_name,
	d.station_2,
	d.station_2_name,
	d.zip,
	d.distance_meters,
	ds.avg_meters_per_zip,
	ds.min_meters_per_zip,
	ds.max_meters_per_zip, 
	case
		when d.distance_meters = ds.max_meters_per_zip then 'Maximum'
		when d.distance_meters = ds.min_meters_per_zip then 'Minimum'
		when d.distance_meters >= ds.avg_meters_per_zip then 'Greater Than Average'
		when d.distance_meters <= ds.avg_meters_per_zip then 'Less Than Average' 
		else 'n/a' end as proximity_comparison_zip,
	case 
		when degrees(st_azimuth(d.transform_a_geom, d.transform_b_geom)) > 315 or 
		degrees(st_azimuth(d.transform_a_geom, d.transform_b_geom)) < 45 then 'North'
		when degrees(st_azimuth(d.transform_a_geom, d.transform_b_geom)) > 45 and 
		degrees(st_azimuth(d.transform_a_geom, d.transform_b_geom)) < 135 then 'East'
		when degrees(st_azimuth(d.transform_a_geom, d.transform_b_geom)) > 135 and 
		degrees(st_azimuth(d.transform_a_geom, d.transform_b_geom)) < 225 then 'South'
		when degrees(st_azimuth(d.transform_a_geom, d.transform_b_geom)) > 225 and 
		degrees(st_azimuth(d.transform_a_geom, d.transform_b_geom)) < 315 then 'West'
		end as direction
from 
	distance d
join 
	distance_stats ds on d.zip = ds.zip
	
------------------------------------------------------------------
/* 
View bikelanes_view: reformat and clean columns and and exclude unnecessary fields 
*/

create view bikelanes_view as 

select initcap(street) street,
initcap(displayrou) route_type,
initcap(f_street) f_street,
initcap(t_street) t_street,
br_oneway,
oneway_dir,
geom
from bikelanes