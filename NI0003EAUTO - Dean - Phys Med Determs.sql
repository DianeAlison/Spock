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

declare		@start_date datetime, @end_date datetime, @car_id int

select		@start_date = '01/01/2021',	
			@end_date =  '01/31/2021',  --cast(floor(cast(GETDATE() as float)) as datetime) -1,
			
			@car_id = 65		
			
-----------------------------------------------------------
--Put variables into a table

IF OBJECT_ID('tempdb..#rpt_parms') IS NOT NULL drop table #rpt_parms

select	start_date = @start_date, end_date = @end_date, car_id = @car_id
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
from	adhoc.dbo.Aetna_Phys_Med_Determs

where	car_id = (select car_id from #rpt_parms)
		and determination_date >= (select start_date from #rpt_parms)
		and determination_date < DATEADD(dd,1,(select end_date from #rpt_parms))
		
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
from	adhoc.dbo.Aetna_Phys_Med_Determs
		
where	car_id = (select car_id from #rpt_parms)
		and determination_date >= (select start_date from #rpt_parms)
		and determination_date < DATEADD(dd,1,(select end_date from #rpt_parms))
		
		
select * from #summ1 ORDER BY market asc, provider_type asc

--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs where tracking_number = 070685462

/*

select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs
where car_name = 'Fidelis Care'
and determination_date >= '01/01/2021'
and determination_date < '02/01/2021'
order by determination_date

select tracking_number, count(distinct(provider_type))
from ASDReportDB.dbo.Aetna_Phys_Med_Determs
where car_name = 'Fidelis Care'
and determination_date >= '01/01/2021'
and determination_date < '02/01/2021'
group by tracking_number having count(distinct(provider_type)) > 1


select car_id, car_name, auth_id, tracking_number, determination_date, UM_Determ_Outcome, provider_type
from ASDReportDB.dbo.Aetna_Phys_Med_Determs
where car_name = 'Fidelis Care'
and determination_date >= '01/01/2021'
and determination_date < '02/01/2021'
and tracking_number = 169225585



order by determination_date



*/


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
		mbr_age,
		mbr_gender,
		Apprv_by_Algo,
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
		
from	adhoc.dbo.Aetna_Phys_Med_Determs

where	car_id = (select car_id from #rpt_parms)
		and determination_date >= (select start_date from #rpt_parms)
		and determination_date < DATEADD(dd,1,(select end_date from #rpt_parms))
				
order by auth_id, tracking_number


--select * from ASDReportDB.dbo.Aetna_Phys_Med_Determs where market = 'Home State Health Plan'

