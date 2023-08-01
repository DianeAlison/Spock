
--Aetna Phys Med Determ Activity - using ASDReportDB table
--Single client version
--Currently used for HAPA and Coventry WV


-----------------------------------------------------------
--Declare variables

declare		@start_date datetime, @end_date datetime, @car_name varchar(100)

select		@start_date = '10/01/2019',	
			@end_date =  '12/31/2019',  --cast(floor(cast(GETDATE() as float)) as datetime) -1,
			
			--@car_name = 'HealthAmerica of PA'
			@car_name = 'Coventry Health Care of West Virginia'
			
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
		

select * from #summ1 ORDER BY market asc, provider_type asc

--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs where tracking_number = 070685462


------------------------------------------------------------
select	'**** Auth Details - Partials on one line ****'

select	car_name,
		market,
		auth_id,
		linked_auth_id,
		partial_denial_flag,
		initial_or_subsequent = inital_or_subsequent,
		tracking_number,
		urgency,
		benefit_denial,
		request_date,
		auth_origin,
		Initiated_by_Fax,
		plan_group,
		plan_id,
		plan_name,
		client_group_number,
		client_group_type,
		mbr_age,
		mbr_gender,
		Apprv_by_Algo,
		UM_Determ_Outcome,
		determination_date,
		phys_tax_id,
		provider_npi,
		client_physician_id,
		provider_name,
		provider_type,
		a97035_apprv_units,
		a97035_den_units,
		a97110_apprv_units,
		a97110_den_units,
		a97140_apprv_units,
		a97140_den_units,
		a97535_apprv_units,
		a97535_den_units,
		a97750_apprv_units,
		a97750_den_units,
		a97760_apprv_units,
		a97760_den_units,
		a98940_apprv_units,
		a98940_den_units,
		other_cpt,
		expedited,
		expedited_date,
		retro_flag,
		combo_flag,
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
		
order by auth_id, tracking_number


--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs

