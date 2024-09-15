
SELECT 
    ad_date,
    spend,
    clicks,
    spend / clicks AS spend_per_click
FROM 
    facebook_ads_basic_daily
WHERE 
    clicks > 0
ORDER BY 
    ad_date DESC;

SELECT 
    ad_date,
    campaign_id,
    SUM(spend) AS total_cost,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(value) AS total_value,
    SUM(spend) / SUM(clicks) AS CPC,
    (SUM(spend) / SUM(impressions)) * 1000 AS CPM,
    (SUM(clicks) / SUM(impressions)) * 100 AS CTR,
    SUM(value) / SUM(spend) AS ROMI
FROM 
    facebook_ads_basic_daily
GROUP BY 
    ad_date,
    campaign_id
HAVING 

    SUM(clicks) > 0 AND 
    SUM(impressions) > 0 AND 
    SUM(spend) > 0;

SELECT 
    campaign_id,
    SUM(spend) AS total_cost,
    SUM(value) / SUM(spend) AS ROMI
FROM 
    facebook_ads_basic_daily
GROUP BY 
    campaign_id
HAVING 
    SUM(spend) > 500000
ORDER BY 
    ROMI DESC
LIMIT 1;

with all_ads_data as (select
fabd.ad_date,
fc.campaign_name,
fabd.spend,
fabd.impressions,
fabd.reach,
fabd.clicks,
fabd.leads,
fabd.value
from facebook_ads_basic_daily fabd
left join facebook_campaign fc
on fabd.campaign_id = fc.campaign_id
left join facebook_adset fa
on fabd.adset_id = fa.adset_id
union all
select 
	ad_date,
	campaign_name,
	spend,
	impressions,
	reach,
	clicks,
	leads,
	value
from google_ads_basic_daily gabd)
select
	ad_date,
	campaign_name,
	sum(spend) as total_spend,
	sum(impressions)as total_impressions,
	sum(clicks) as total_click,
	Sum(value) as total_values
from google_ads_basic_daily gabd
group by 1,2

WITH all_ads_data AS (
    SELECT
        fabd.ad_date,
        fa.adset_name,
        fc.campaign_name,
        fabd.spend,
        fabd.impressions,
        fabd.reach,
        fabd.clicks,
        fabd.leads,
        fabd.value
    FROM facebook_ads_basic_daily fabd
    LEFT JOIN facebook_campaign fc ON fabd.campaign_id = fc.campaign_id
    LEFT JOIN facebook_adset fa ON fabd.adset_id = fa.adset_id    
    UNION ALL    
    SELECT 
        gabd.ad_date,
        gabd.adset_name,
        gabd.campaign_name,
        gabd.spend,
        gabd.impressions,
        gabd.reach,
        gabd.clicks,
        gabd.leads,
        gabd.value
    FROM google_ads_basic_daily gabd)
    SELECT
    campaign_name,
    adset_name,
    SUM(spend) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_click,
    SUM(value) AS total_value,
	(SUM(value)::numeric - SUM(spend)::numeric)/SUM(spend)::numeric AS ROMI
FROM 
    all_ads_data
GROUP BY 
    campaign_name, adset_name
HAVING 
    SUM(spend) > 500000
ORDER BY 
    ROMI DESC
LIMIT 1;

CREATE OR REPLACE FUNCTION pg_temp.decode_url_part3(p varchar) RETURNS varchar AS $$
SELECT convert_from(CAST(E'\\x' || array_to_string(ARRAY(
    SELECT CASE WHEN length(r.m[1]) = 1 THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex') ELSE substring(r.m[1] from 2 for 2) END
    FROM regexp_matches($1, '%[0-9a-f][0-9a-f]|.', 'gi') AS r(m)
), '') AS bytea), 'UTF8');
$$ LANGUAGE SQL IMMUTABLE STRICT;

with all_ads_data as (
	select fabd.ad_date, fabd.url_parameters ,fc.campaign_name, fa.adset_name, fabd.spend, fabd.impressions, fabd.reach, fabd.clicks, fabd.leads, fabd.value
	from facebook_ads_basic_daily fabd 
	left join facebook_adset fa on fa.adset_id  = fabd.adset_id 
	left join facebook_campaign fc on fc.campaign_id  = fabd.campaign_id 
	union all
	select ad_date, url_parameters,campaign_name, adset_name, spend, impressions, reach, clicks, leads, value
	from google_ads_basic_daily gabd
)
select
	ad_date,
	case 
		when lower(substring(url_parameters,'utm_campaign=([^\&]+)')) = 'nan' then null
		when lower(substring(url_parameters,'utm_campaign=([^\&]*)')) = '' then null
		else decode_url_part3((substring(url_parameters,'utm_campaign=([^\&]+)')))
	end as utm_campaign,
	/*sum(spend) as total_spend, 
	sum(impressions) as total_impressions,
	sum(reach) as total_reach,
	sum(clicks) as total_clicks,
	sum(leads) as total_leads,
	sum(value) as total_value,*/
	case 
		when sum(clicks) > 0 then sum(spend)/sum(clicks)
	end as cpc,
	case 
		when sum(impressions) > 0 then sum(spend)::numeric/sum(impressions)*1000
	end as cpm,
	case 
		when sum(impressions) > 0 then sum(clicks)::numeric/sum(impressions)*100
	end as ctr,
	case 
		when sum(spend) > 0 then round((sum(value)::numeric-sum(spend))/sum(spend)*100,2)
	end as romi
from all_ads_data
where spend > 0
group by 1, 2
order by ad_date;

CREATE OR REPLACE FUNCTION pg_temp.decode_url_part3(p varchar) RETURNS varchar AS $$
SELECT convert_from(CAST(E'\\x' || array_to_string(ARRAY(
    SELECT CASE WHEN length(r.m[1]) = 1 THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex') ELSE substring(r.m[1] from 2 for 2) END
    FROM regexp_matches($1, '%[0-9a-f][0-9a-f]|.', 'gi') AS r(m)
), '') AS bytea), 'UTF8');
$$ LANGUAGE SQL IMMUTABLE STRICT;
-- Pasul 1: CTE-ul inițial pentru a combina datele din Facebook și Google Ads
WITH all_ads_data AS (
    SELECT 
        fabd.ad_date, 
        fabd.url_parameters, 
        fc.campaign_name, 
        fa.adset_name, 
        fabd.spend, 
        fabd.impressions, 
        fabd.reach, 
        fabd.clicks, 
        fabd.leads, 
        fabd.value
    FROM facebook_ads_basic_daily fabd 
    LEFT JOIN facebook_adset fa ON fa.adset_id = fabd.adset_id 
    LEFT JOIN facebook_campaign fc ON fc.campaign_id = fabd.campaign_id 
    UNION ALL
    SELECT 
        ad_date, 
        url_parameters, 
        campaign_name, 
        adset_name, 
        spend, 
        impressions, 
        reach, 
        clicks, 
        leads, 
        value
    FROM google_ads_basic_daily gabd
),
-- Pasul 2: Agregarea datelor la nivel lunar și calcularea metricilor necesare
monthly_ads_data AS (
    SELECT
        DATE_TRUNC('month', ad_date) AS ad_month,
        CASE 
            WHEN lower(substring(url_parameters,'utm_campaign=([^\&]+)')) = 'nan' THEN NULL
            WHEN lower(substring(url_parameters,'utm_campaign=([^\&]*)')) = '' THEN NULL
            ELSE decode_url_part3((substring(url_parameters,'utm_campaign=([^\&]+)')))
        END AS utm_campaign,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(value) AS total_value,
        CASE 
            WHEN SUM(clicks) > 0 THEN SUM(spend) / SUM(clicks)
            ELSE NULL
        END AS cpc,
        CASE 
            WHEN SUM(impressions) > 0 THEN (SUM(spend)::numeric / SUM(impressions)) * 1000
            ELSE NULL
        END AS cpm,
        CASE 
            WHEN SUM(impressions) > 0 THEN (SUM(clicks)::numeric / SUM(impressions)) * 100
            ELSE NULL
        END AS ctr,
        CASE 
            WHEN SUM(spend) > 0 THEN ROUND((SUM(value)::numeric - SUM(spend)) / SUM(spend) * 100, 2)
            ELSE NULL
        END AS romi
    FROM all_ads_data
    WHERE spend > 0
    GROUP BY 1, 2
),
-- Pasul 3: Calcularea diferențelor procentuale ale metricilor față de luna anterioară
monthly_ads_data_with_differences AS (
    SELECT
        ad_month,
        utm_campaign,
        total_spend,
        total_impressions,
        total_clicks,
        total_value,
        cpc,
        cpm,
        ctr,
        romi,
        LAG(cpm) OVER (PARTITION BY utm_campaign ORDER BY ad_month) AS prev_cpm,
        LAG(ctr) OVER (PARTITION BY utm_campaign ORDER BY ad_month) AS prev_ctr,
        LAG(romi) OVER (PARTITION BY utm_campaign ORDER BY ad_month) AS prev_romi
    FROM monthly_ads_data
)
-- Selecția finală
SELECT
    ad_month,
    utm_campaign,
    total_spend,
    total_impressions,
    total_clicks,
    total_value,
    cpc,
    cpm,
    ctr,
    romi,
    CASE 
        WHEN prev_cpm IS NOT NULL THEN ((cpm - prev_cpm) / prev_cpm) * 100
        ELSE NULL
    END AS cpm_diff_pct,
    CASE 
        WHEN prev_ctr IS NOT NULL THEN ((ctr - prev_ctr) / prev_ctr) * 100
        ELSE NULL
    END AS ctr_diff_pct,
    CASE 
        WHEN prev_romi IS NOT NULL THEN ((romi - prev_romi) / prev_romi) * 100
        ELSE NULL
    END AS romi_diff_pct
FROM monthly_ads_data_with_differences
ORDER BY ad_month, utm_campaign;

