--NI0003EAUTO
--Aetna Phys Med Determ Activity - using ASDReportDB table
--Single client version
--Currently used for HAPA and Coventry WV
/*
select distinct(car_id), car_name
from ASDReportDB.dbo.Aetna_Phys_Med_Determs_test_01272021
group by car_id, car_name

*/

--select * from niacore..health_carrier where state = 'IA' order by car_name
-----------------------------------------------------------
--Declare variables

declare		@start_date datetime, @end_date datetime, @car_id int, @lob varchar(max)

select		@start_date = '01/01/2021',	
			@end_date =  '03/17/2021',  --cast(floor(cast(GETDATE() as float)) as datetime) -1,
			--@lob = 'EX',
			@lob = 'MC, MD, CO, OT'	,
			
		--EXCHANGE ONLY Markets
			--@car_id = 	112		--Arkansas Health and Wellness
			--@car_id = 	85		--Sunshine Health
			--@car_id = 	78		--Peach State Health Plan
			--@car_id = 	81		--Magnolia Health Plan
			--@car_id = 	163		--Ambetter of North Carolina, Inc
			--@car_id = 	149		--SilverSummit Healthplan
			--@car_id = 	156		--Pennsylvania Health and Wellness Plan
			--@car_id = 	76		--Buckeye Community Health Plan
			--@car_id = 	165		--Ambetter of Tennessee
			--@car_id = 	77		--Superior Health Plan
			--@car_id = 	162		--Western Sky Community Care
			--@car_id = 	166		--Meridian Complete Michigan
			--@car_id = 	173		--Meridian Complete Illinois
			--@car_id = 	103		--New Hampshire Healthy Families    (Centene NH)
			--@car_id = 	98		--Home State Health Plan    (Centene MO)
			--@car_id = 	141		--Managed Health Services    (Centene IN)
			--@car_id = 	83		--Absolute Total Care
			--@car_id = 	102		--Sunflower (Centene KS)
		
		-----Maryland Physicians
			@car_id = 174
		
		--Medicaid/Medicare/Commercial Markets	
			--@car_name = 'Louisiana Health Care Connections'
			--@car_name = 'New Hampshire Healthy Families'
			--@car_name = 'Home State Health Plan'   --car_id = 98   CenteneMO
			--@car_name = 'Managed Health Services'	 --car_id = 141  CenteneIN
			
			--@car_name = 'Absolute Total Care'
			--@car_name = 'IlliniCare Health/MeridianTotal'
			--@car_name = 'Sunflower Health Plan'
			
			
			--@car_name = 'Fidelis Care'				 --car_id = 169  CenteneNY
	--select car_id, car_name, DB_NAME from niacore..health_carrier where db_name = 'illini'
			
-----------------------------------------------------------
--Put variables into a table

IF OBJECT_ID('tempdb..#rpt_parms') IS NOT NULL drop table #rpt_parms

select	start_date = @start_date, end_date = @end_date, car_id = @car_id, lob = @lob
into	#rpt_parms

select * from #rpt_parms


---------------------------------------------------
--Individual Client Reports
---------------------------------------------------
--select	'**** Determ Activity Summary ****'

IF OBJECT_ID('tempdb..#summ1') IS NOT NULL drop table #summ1

select	
		Market, --Urgency,
		Provider_Type,
		Total_Episodes = count(distinct(tracking_number)),
		Total_Determs = count(auth_id),
		
		Certified = sum(case when UM_Determ_Outcome = 'Certified' then 1 else 0 end),
		PCT_Certified = cast(cast(sum(case when UM_Determ_Outcome = 'Certified' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
		Partial_Non_Certified = sum(case when UM_Determ_Outcome = 'Partially Non-Certified' then 1 else 0 end),
		PCT_Partial = cast(cast(sum(case when UM_Determ_Outcome = 'Partially Non-Certified' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
		Non_Certified = sum(case when UM_Determ_Outcome = 'Clinical Non-Certified' then 1 else 0 end),
		PCT_Non_Cert = cast(cast(sum(case when UM_Determ_Outcome = 'Clinical Non-Certified' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
		Admin_Non_Cert = sum(case when UM_Determ_Outcome = 'Administrative Non-Certified' then 1 else 0 end),
		PCT_Admin_Non_Cert = cast(cast(sum(case when UM_Determ_Outcome = 'Administrative Non-Certified' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
		Inactiv_by_Ord = sum(case when UM_Determ_Outcome = 'Inactivated by Ordering Provider' then 1 else 0 end),
		PCT_Inact_by_Ord = cast(cast(sum(case when UM_Determ_Outcome = 'Inactivated by Ordering Provider' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
						
		PCT_Clin_Den = cast(cast(sum(case when UM_Determ_Outcome in ('Partially Non-Certified', 'Clinical Non-Certified', 'Inactivated by Ordering Provider')
								 then 1 else 0 end) as decimal)/
								cast(count(auth_id) as decimal) * 1 as decimal (10,3))

into	#summ1								
from	ASDReportDB.dbo.Aetna_Phys_Med_Determs

where	car_id = @car_id
		and lob_code in (select item from adhoc.dbo.fn_SplitMulti(@lob,','))  
		and determination_date between @start_date and dateadd(dd,1,@end_date)
		
group by Market, Provider_Type

UNION ALL 


--Get Grand Total = 1 Row
select	Market = 'Grand Total',
		Provider_Type = '',
		Total_Episodes = count(distinct(tracking_number)),
		Total_Determs = count(auth_id),
		Certified = sum(case when UM_Determ_Outcome = 'Certified' then 1 else 0 end),
		PCT_Certified = cast(cast(sum(case when UM_Determ_Outcome = 'Certified' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
		Partial_Non_Certified = sum(case when UM_Determ_Outcome = 'Partially Non-Certified' then 1 else 0 end),
		PCT_Partial = cast(cast(sum(case when UM_Determ_Outcome = 'Partially Non-Certified' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
		Non_Certified = sum(case when UM_Determ_Outcome = 'Clinical Non-Certified' then 1 else 0 end),
		PCT_Non_Cert = cast(cast(sum(case when UM_Determ_Outcome = 'Clinical Non-Certified' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
		Admin_Non_Cert = sum(case when UM_Determ_Outcome = 'Administrative Non-Certified' then 1 else 0 end),
		PCT_Admin_Non_Cert = cast(cast(sum(case when UM_Determ_Outcome = 'Administrative Non-Certified' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
		Inactiv_by_Ord = sum(case when UM_Determ_Outcome = 'Inactivated by Ordering Provider' then 1 else 0 end),
		PCT_Inact_by_Ord = cast(cast(sum(case when UM_Determ_Outcome = 'Inactivated by Ordering Provider' then 1 else 0 end) as decimal)/
						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
						
		PCT_Clin_Den = cast(cast(sum(case when UM_Determ_Outcome in ('Partially Non-Certified', 'Clinical Non-Certified', 'Inactivated by Ordering Provider')
								 then 1 else 0 end) as decimal)/
								cast(count(auth_id) as decimal) * 1 as decimal (10,3))

--into	#summ1		
from	ASDReportDB.dbo.Aetna_Phys_Med_Determs
where	car_id = @car_id
		and lob_code in (select item from adhoc.dbo.fn_SplitMulti(@lob,','))  
		and determination_date between @start_date and dateadd(dd,1,@end_date)
		

select * from #summ1 ORDER BY market asc, provider_type asc

--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs_test_01272021 where tracking_number = 070685462


------------------------------------------------------------
select	'**** Auth Details - Partials on one line ****'

select	car_name,
		--market,
		auth_id,
		--linked_auth_id,
		partial_denial_flag,
		initial_or_subsequent = inital_or_subsequent,
		tracking_number,
		request_date = convert(varchar, request_date, 20),
		urgency,
		--benefit_denial,
		
		auth_origin,
		Initiated_by_Fax,
		plan_group,
		plan_id,
		plan_name,
		lob_desc,
		--client_group_number,
		--client_group_type,
		--mbr_age,
		--mbr_gender,
		Apprv_by_Algo,
		UM_Determ_Outcome,
		determination_date = convert(varchar, determination_date, 20),
		phys_tax_id,
		--provider_npi,
		client_physician_id,
		provider_name,
		provider_type,
		visits_requested,
		visits_approved,
		visits_denied,
		expedited,
		expedited_date = convert(varchar, expedited_date, 20),
		retro_flag,
		--combo_flag,
		diagnosis_code,
		client_member_id,
		mbr_dob,
		mbr_fname,
		mbr_lname,
		fac_name,
		fac_tin,
		fac_address,
		fac_city,
		fac_state,
		fac_zip,
		fac_mis,
		fac_phone,
		fac_fax,
		Validity_period_FROM,
		Validity_period_TO
		
from	ASDReportDB.dbo.Aetna_Phys_Med_Determs
where	car_id = @car_id
		and lob_code in (select item from adhoc.dbo.fn_SplitMulti(@lob,','))  
		and determination_date between @start_date and dateadd(dd,1,@end_date)
		
order by auth_id, tracking_number


--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs_test_01272021 where market = 'Home State Health Plan'

