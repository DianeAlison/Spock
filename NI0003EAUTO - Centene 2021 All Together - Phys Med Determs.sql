--NI0003EAUTO
--Aetna Phys Med Determ Activity - using ASDReportDB table
--Single client version
--Currently used for HAPA and Coventry WV
/*
select distinct(car_id), car_name
from asdreportdb.dbo.Aetna_phys_med_determs
group by car_id, car_name

*/

--select * from niacore..health_carrier where state = 'IA' order by car_name
-----------------------------------------------------------
--Declare variables

declare		@start_date datetime, @end_date datetime, @lob varchar(max)

select		@start_date = '10/01/2020',	
			@end_date =  '12/31/2020',  --cast(floor(cast(GETDATE() as float)) as datetime) -1,
			
			@lob = 'EX'
			--@lob = 'MC, MD, CO, OT'	
			--@lob = 'MC, MD, CO, EX'	  --Fidelis only, which has all LOBs on one report.
		
		
-----------------------------------------------------------
--Put variables into a table

IF OBJECT_ID('tempdb..#rpt_parms') IS NOT NULL drop table #rpt_parms

select	start_date = @start_date, end_date = @end_date, lob = @lob
into	#rpt_parms

--select * from #rpt_parms


---------------------------------------------------
--Individual Client Reports
---------------------------------------------------
--select	'**** Determ Activity Summary ****'

IF OBJECT_ID('tempdb..#summ1') IS NOT NULL drop table #summ1

select	car_id, car_name,
		--Market, --Urgency,
		--Provider_Type,
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
from	ASDReportDB.dbo.Aetna_Phys_Med_Determs  --_test_01272021

where	lob_code in (select item from adhoc.dbo.fn_SplitMulti(@lob,','))  
		and determination_date between @start_date and dateadd(dd,1,@end_date)
group by car_id, car_name --Market--, Provider_Type

--UNION ALL 


----Get Grand Total = 1 Row
--select	car_id, car_name, Market = 'Grand Total',
--		--Provider_Type = '',
--		Total_Episodes = count(distinct(tracking_number)),
--		Total_Determs = count(auth_id),
--		Certified = sum(case when UM_Determ_Outcome = 'Certified' then 1 else 0 end),
--		PCT_Certified = cast(cast(sum(case when UM_Determ_Outcome = 'Certified' then 1 else 0 end) as decimal)/
--						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
--		Partial_Non_Certified = sum(case when UM_Determ_Outcome = 'Partially Non-Certified' then 1 else 0 end),
--		PCT_Partial = cast(cast(sum(case when UM_Determ_Outcome = 'Partially Non-Certified' then 1 else 0 end) as decimal)/
--						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
--		Non_Certified = sum(case when UM_Determ_Outcome = 'Clinical Non-Certified' then 1 else 0 end),
--		PCT_Non_Cert = cast(cast(sum(case when UM_Determ_Outcome = 'Clinical Non-Certified' then 1 else 0 end) as decimal)/
--						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
--		Admin_Non_Cert = sum(case when UM_Determ_Outcome = 'Administrative Non-Certified' then 1 else 0 end),
--		PCT_Admin_Non_Cert = cast(cast(sum(case when UM_Determ_Outcome = 'Administrative Non-Certified' then 1 else 0 end) as decimal)/
--						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
		
--		Inactiv_by_Ord = sum(case when UM_Determ_Outcome = 'Inactivated by Ordering Provider' then 1 else 0 end),
--		PCT_Inact_by_Ord = cast(cast(sum(case when UM_Determ_Outcome = 'Inactivated by Ordering Provider' then 1 else 0 end) as decimal)/
--						cast(count(auth_id) as decimal) * 1 as decimal (10,3)),
						
--		PCT_Clin_Den = cast(cast(sum(case when UM_Determ_Outcome in ('Partially Non-Certified', 'Clinical Non-Certified', 'Inactivated by Ordering Provider')
--								 then 1 else 0 end) as decimal)/
--								cast(count(auth_id) as decimal) * 1 as decimal (10,3))

----into	#summ1		
--from	ASDReportDB.dbo.Aetna_Phys_Med_Determs
--where	lob_code in (select item from adhoc.dbo.fn_SplitMulti(@lob,','))  
--		and determination_date between @start_date and dateadd(dd,1,@end_date)
		
select * from #rpt_parms

select * from #summ1 ORDER BY car_id  --, provider_type asc

--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs where tracking_number = 070685462

--select * 
--into	ASDReportDB.dbo.Aetna_Phys_Med_Determs_test_01272021
--from ASDReportDB.dbo.Aetna_Phys_Med_Determs

--select car_id, car_name, db_name from niacore..health_carrier where car_id in (112, 85,78,81,163,149,156,76,165,77,162,166,173,103,98,141,83,102)

------------------------------------------------------------
--select	'**** Auth Details - Partials on one line ****'

--select	car_name,
--		--market,
--		auth_id,
--		--linked_auth_id,
--		partial_denial_flag,
--		initial_or_subsequent = inital_or_subsequent,
--		tracking_number,
--		urgency,
--		--benefit_denial,
--		request_date,
--		auth_origin,
--		Initiated_by_Fax,
--		plan_group,
--		plan_id,
--		plan_name,
--		--client_group_number,
--		--client_group_type,
--		mbr_age,
--		mbr_gender,
--		Apprv_by_Algo,
--		UM_Determ_Outcome,
--		determination_date,
--		phys_tax_id,
--		--provider_npi,
--		client_physician_id,
--		provider_name,
--		provider_type,
--		visits_requested,
--		visits_approved,
--		visits_denied,
--		expedited,
--		expedited_date,
--		retro_flag,
--		--combo_flag,
--		diagnosis_code,
--		client_member_id,
--		mbr_dob,
--		mbr_fname,
--		mbr_lname,
--		fac_name,
--		fac_tin,
--		fac_address,
--		fac_city,
--		fac_state,
--		fac_zip,
--		fac_mis,
--		fac_phone,
--		fac_fax,
--		Validity_period_FROM,
--		Validity_period_TO
		
--from	ASDReportDB.dbo.Aetna_Phys_Med_Determs
--where	car_name = @car_name
--		and determination_date between @start_date and dateadd(dd,1,@end_date)
		
--order by auth_id, tracking_number


--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs where market = 'Home State Health Plan'

