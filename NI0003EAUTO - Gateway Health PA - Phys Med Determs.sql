
--Aetna Phys Med Determ Activity - using ASDReportDB table
--Single client version
-- *** Gateway Health PA - Medicaid ***


-----------------------------------------------------------
--Declare variables

declare		@start_date datetime, @end_date datetime, @car_name varchar(100), @plan_id varchar(max)

select		@start_date = '10/01/2020',	
			@end_date =  '12/31/2020',  --cast(floor(cast(GETDATE() as float)) as datetime) -1,
			
			@car_name = 'Gateway Health',			 --car_id = 129	 Gateway
			
			@plan_id = '27133, 27134, 27135, 27136, 27610, 27611'		--Gateway Health PA - Medicaid
			--@plan_id = '27525, 27526, 27911'							--Gateway Health PA - Medicare
			
			
			
	--select car_id, car_name, DB_NAME from niacore..health_carrier where db_name = 'Gateway'
	
	--select top 10 * from asdreportdb.dbo.Aetna_Phys_Med_Determs
			
-----------------------------------------------------------
--Put variables into a table

IF OBJECT_ID('tempdb..#rpt_parms') IS NOT NULL drop table #rpt_parms

select	start_date = @start_date, end_date = @end_date
into	#rpt_parms


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

where	car_name = @car_name
		and determination_date between @start_date and dateadd(dd,1,@end_date)
		and plan_id in (select item from adhoc.dbo.fn_SplitMulti(@plan_id,','))  
		
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
where	car_name = @car_name
		and determination_date between @start_date and dateadd(dd,1,@end_date)
		and plan_id in (select item from adhoc.dbo.fn_SplitMulti(@plan_id,','))  

select * from #summ1 ORDER BY market asc, provider_type asc

--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs where tracking_number = 070685462


------------------------------------------------------------
select	'**** Auth Details - Partials on one line ****'

select	car_name,
		--market,
		auth_id,
		--linked_auth_id,
		partial_denial_flag,
		initial_or_subsequent = inital_or_subsequent,
		tracking_number,
		urgency,
		--benefit_denial,
		request_date,
		auth_origin,
		Initiated_by_Fax,
		plan_group,
		plan_id,
		plan_name,
		--client_group_number,
		--client_group_type,
		--mbr_age,					--Remove per David Deater
		--mbr_gender,				--Remove per David Deater
		--Apprv_by_Algo,			--Remove per David Deater
		UM_Determ_Outcome,
		determination_date,
		phys_tax_id,
		--provider_npi,
		client_physician_id,
		provider_name,
		provider_type,
		visits_requested,
		visits_approved,
		visits_denied,
		expedited,
		expedited_date,
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
where	car_name = @car_name
		and determination_date between @start_date and dateadd(dd,1,@end_date)
		and plan_id in (select item from adhoc.dbo.fn_SplitMulti(@plan_id,','))  
		
order by auth_id, tracking_number


--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs where market = 'Home State Health Plan'

