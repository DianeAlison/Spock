

/*******************************************************
Dean Physical Medicine
Determinations Activity Report query
Created By:  Michelle Boggs
Created Date:  04/12/2019

I took Chris Bleikardt's code for Aetna and Centene and 
converted it to Dean.

65  Dean
********************************************************/


USE Dean

IF OBJECT_ID('Adhoc.dbo.Dean_Phys_Med_Determs') IS NOT NULL drop table Adhoc.dbo.Dean_Phys_Med_Determs;
IF OBJECT_ID('Adhoc.dbo.Dean_Phys_Med_Links') IS NOT NULL drop table Adhoc.dbo.Dean_Phys_Med_Links;


IF OBJECT_ID('tempdb..#rpt_parms') IS NOT NULL drop table #rpt_parms
IF OBJECT_ID('tempdb..#pm') IS NOT NULL drop table #pm
IF OBJECT_ID('tempdb..#pmm') IS NOT NULL drop table #pmm
IF OBJECT_ID('tempdb..#pmmm') IS NOT NULL drop table #pmmm
IF OBJECT_ID('tempdb..#pm2') IS NOT NULL drop table #pm2
IF OBJECT_ID('tempdb..#pm3') IS NOT NULL drop table #pm3
IF OBJECT_ID('tempdb..#pm4') IS NOT NULL drop table #pm4    ---NEW
IF OBJECT_ID('tempdb..#pm5') IS NOT NULL drop table #pm5    ---NEW
IF OBJECT_ID('tempdb..#max_queue') IS NOT NULL drop table #max_queue
IF OBJECT_ID('tempdb..#summ1') IS NOT NULL drop table #summ1
IF OBJECT_ID('tempdb..#auths') IS NOT NULL drop table #auths
IF OBJECT_ID('tempdb..#offer') IS NOT NULL drop table #offer
IF OBJECT_ID('tempdb..#units_combined') IS NOT NULL drop table #units_combined
IF OBJECT_ID('tempdb..#units_auth') IS NOT NULL drop table #units_auth
IF OBJECT_ID('tempdb..#units_link') IS NOT NULL drop table #units_link
IF OBJECT_ID('tempdb..#links1') IS NOT NULL drop table #links1
IF OBJECT_ID('tempdb..#links2') IS NOT NULL drop table #links2
IF OBJECT_ID('tempdb..#links3') IS NOT NULL drop table #links3
IF OBJECT_ID('tempdb..#imp') IS NOT NULL drop table #imp
IF OBJECT_ID('tempdb..#hab') IS NOT NULL drop table #hab

---------------------------------------------------------------------------------------------------
-- Declare variables

declare		@start_date datetime, @end_date datetime, @car_id varchar(max)

select		@start_date = '01/01/2018',	
			@end_date =  cast(floor(cast(GETDATE() as float)) as datetime) -1,
			@car_id = '65'
				
---------------------------------------------------------------------------------------------------
-- Put variables into a table

select	start_date = @start_date, end_date = @end_date
into	#rpt_parms


--------------------------------------------------------------------------------------------------
-- Get units count for all auths
-- Approved + Denied units into a single count for each auth_id.
-- Dean doesn't track units, just visits (physical_medicine_therapy_plan).  Keeping this as a holding 
-- place so I can match the Aetna/Centene table.

;with cte_a as 
(
select	car_id = '65',
		auth_id, 
		a97035_units = sum(case when cpt4_code = '97035' then approved_units + denied_units else 0 end),
		a97110_units = sum(case when cpt4_code = '97110' then approved_units + denied_units else 0 end),
		a97140_units = sum(case when cpt4_code = '97140' then approved_units + denied_units else 0 end),
		a97535_units = sum(case when cpt4_code = '97535' then approved_units + denied_units else 0 end),
		a97750_units = sum(case when cpt4_code = '97750' then approved_units + denied_units else 0 end),
		a97755_units = sum(case when cpt4_code = '97755' then approved_units + denied_units else 0 end),
		a97760_units = sum(case when cpt4_code = '97760' then approved_units + denied_units else 0 end),
		a98940_units = sum(case when cpt4_code = '98940' then approved_units + denied_units else 0 end),
		a99714_units = sum(case when cpt4_code = '99714' then approved_units + denied_units else 0 end),
		a99771_units = sum(case when cpt4_code = '99771' then approved_units + denied_units else 0 end),
		Total_Units = sum(approved_units) + sum(denied_units)

from Dean.dbo.auth_treatmentplan 
where withdrawn_flag = 0
group by auth_id
)

-- Put CTE results into table
select * into #units_combined from cte_a


---------------------------------------------------------------------------------------------------
-- Get APPROVED/DENIED units count for each individual auth
-- Separate counts for approved and denied units for each auth_id.
-- Doesn't apply to Dean.

;with cte_b as 
(
select	car_id = '65',
		auth_id, 
		a97035_apprv_units = sum(case when cpt4_code = '97035' then approved_units else 0 end),
		a97035_den_units = sum(case when cpt4_code = '97035' then denied_units else 0 end),
		
		a97110_apprv_units = sum(case when cpt4_code = '97110' then approved_units else 0 end),
		a97110_den_units = sum(case when cpt4_code = '97110' then denied_units else 0 end),
		
		a97140_apprv_units = sum(case when cpt4_code = '97140' then approved_units else 0 end),
		a97140_den_units = sum(case when cpt4_code = '97140' then denied_units else 0 end),
		
		a97535_apprv_units = sum(case when cpt4_code = '97535' then approved_units else 0 end),
		a97535_den_units = sum(case when cpt4_code = '97535' then denied_units else 0 end),
		
		a97750_apprv_units = sum(case when cpt4_code = '97750' then approved_units else 0 end),
		a97750_den_units = sum(case when cpt4_code = '97750' then denied_units else 0 end),
		
		a97760_apprv_units = sum(case when cpt4_code = '97760' then approved_units else 0 end),
		a97760_den_units = sum(case when cpt4_code = '97760' then denied_units else 0 end),
		
		a98940_apprv_units = sum(case when cpt4_code = '98940' then approved_units else 0 end),
		a98940_den_units = sum(case when cpt4_code = '98940' then denied_units else 0 end)
		

from	Dean.dbo.auth_treatmentplan 
where   withdrawn_flag = 0
group by auth_id
)

-- Put CTE results into table
select * into #units_auth from cte_b

---------------------------------------------------------------------------------------------------
-- Get APPROVED/DENIED units count for each individual LINK_ID
-- Auths with partial denials only, to get a single count of
-- approved and denied units for the set of auths represented by a link_id.
-- Does not apply to Dean.

;with cte_c as 
(
select	car_id = '65',
		apl.link_id, 
		a97035_apprv_units = sum(case when cpt4_code = '97035' then approved_units else 0 end),
		a97035_den_units = sum(case when cpt4_code = '97035' then denied_units else 0 end),
		
		a97110_apprv_units = sum(case when cpt4_code = '97110' then approved_units else 0 end),
		a97110_den_units = sum(case when cpt4_code = '97110' then denied_units else 0 end),
		
		a97140_apprv_units = sum(case when cpt4_code = '97140' then approved_units else 0 end),
		a97140_den_units = sum(case when cpt4_code = '97140' then denied_units else 0 end),
		
		a97535_apprv_units = sum(case when cpt4_code = '97535' then approved_units else 0 end),
		a97535_den_units = sum(case when cpt4_code = '97535' then denied_units else 0 end),
		
		a97750_apprv_units = sum(case when cpt4_code = '97750' then approved_units else 0 end),
		a97750_den_units = sum(case when cpt4_code = '97750' then denied_units else 0 end),
		
		a97760_apprv_units = sum(case when cpt4_code = '97760' then approved_units else 0 end),
		a97760_den_units = sum(case when cpt4_code = '97760' then denied_units else 0 end),
		
		a98940_apprv_units = sum(case when cpt4_code = '98940' then approved_units else 0 end),
		a98940_den_units = sum(case when cpt4_code = '98940' then denied_units else 0 end)
		

from	Dean.dbo.auth_treatmentplan atp with(nolock)
		join Dean.dbo.auth_partial_link apl with(nolock) on (atp.auth_id = apl.auth_id)

where	atp.withdrawn_flag = 0

group by apl.link_id
)

--Put CTE results into table
select * into #units_link from cte_c


---------------------------------------------------------------------------------------------------
-- Get Physical Medicine Auth ID's - Post Service only

;with cte_auths as 
(select	car_id = '65', a.auth_id
from Dean.dbo.authorizations a with(nolock)
where	a.authorization_type_id = 16
		and a.retro_flag <> 'c'
				
)

select * into #auths from cte_auths

/*
---------------------------------------------------------------------------------------------------
-- Get max queue for each auth

;with cte_d as 
(
select	car_id = '65', qa.auth_id, qa.queue_code, queue_date = max(qa.date_queued)
from	Dean.dbo.auth_queue_history_arch qa with(nolock)
		join #auths a with(nolock) on (qa.auth_id = a.auth_id)
where	qa.isfinal = 1
group by qa.auth_id, qa.queue_code

union all

select	car_id = '65', qa.auth_id, qa.queue_code, queue_date = max(qa.date_queued)
from	Dean.dbo.auth_queue_history qa with(nolock)
		join #auths a with(nolock) on (qa.auth_id = a.auth_id)
where	qa.isfinal = 1
group by qa.auth_id, qa.queue_code

)

select * into #max_queue from cte_d

*/
---------------------------------------------------------------------------------------------------
-- Determine if algo offer is accepted/declined.
-- Does not apply to Dean.  Just using as a holding place so I can match Aetna/Centene table.

;with cte_e as
(
select	car_id = '65', 
		an.auth_id,
		max_offer_note_date = max(an.date_entered)

from	#auths a with(nolock)
		join Dean.dbo.auth_notes an with(nolock) on (a.auth_id = an.auth_id)
where	note in ('Requester accepted offered treatment plan', 'Requester declined offered treatment plan')
group by an.auth_id
)

,
cte_f as
(
select	car_id = '65',
		an.auth_id, 
		an.note,
		offer_note_date = an.date_entered
		
from	cte_e e with(nolock)
		join Dean.dbo.auth_notes an with(nolock) on (e.auth_id = an.auth_id 
							and e.max_offer_note_date = an.date_entered)		
)

select * into #offer from cte_f

---------------------------------------------------------------------------------------------------
--Identify auths that are "Hab" based on ICD10 codes
--Any auth where one of the icd10 codes matches a row in the side table is HABILITATIVE

;with cte_i as (

select	distinct i.auth_id

from	Dean.dbo.auth_icd10_codes i with(nolock)
		join asdreportdb.dbo.TherapyHabCodes t with(nolock) on (i.icd10_code = t.TherapyHabCodes)

)

select * into #hab from cte_i

--select * from #hab
--select * from asdreportdb.dbo.TherapyHabCodes
---------------------------------------------------------------------------------------------------
-- Get authorization data

select	car_id = '65',
		hc.car_name,
		a.auth_id,
		apl.link_id, 
		a.tracking_number,
		a.client_auth_id,
		a.combo_flag,
		a.expedite_flag,
		a.retro_flag,
		retro_type = r.description,
		mbr_name = m.lname + ', ' + m.fname,
		a.date_call_rcvd,
		a.authorization_type_id,
		auth_type = aty.description,
		a.cpt4_code,
		a.proc_desc,
		auth_origin = case when a.is_user_id = '1998' then 'RadMD' else 'CallCenter' end,
		a.case_outcome,
		
		final_status_code = ascd.auth_status,
		final_status_desc = ascd.status_desc,
		final_status_outcome = ascd.auth_outcome,
		final_outcome_desc = aout.description,
		final_status_date = aschg.date_changed,
		
		case
			when cd.customer_group_determination_code in ('1','5') then 'Certified'
			when cd.customer_group_determination_code in ('2','6','7','8') then 'Clinical Non-Certified'
			when cd.customer_group_determination_code = '3' then 'Administrative Non-Certified'
			when cd.customer_group_determination_code = '4' then 'Inactivated by Ordering Provider'
		end as UM_Outcome,	
		
		ca.a97035_apprv_units,
		ca.a97035_den_units,
		
		ca.a97110_apprv_units,
		ca.a97110_den_units,
		
		ca.a97140_apprv_units,
		ca.a97140_den_units,
		
		ca.a97535_apprv_units,
		ca.a97535_den_units,
		
		ca.a97750_apprv_units,
		ca.a97750_den_units,
		
		ca.a97760_apprv_units,
		ca.a97760_den_units,
		
		ca.a98940_apprv_units,
		ca.a98940_den_units,
		
		
		dos = convert (char(20), a.dos, 101),
		mbrs_plan_id = m.plan_id,
		mbrs_plan_name = rtrim(hp.plan_name),
		mbrs_plan_group = hpg.description,
		mbrs_plan_state = hp.state,
		mbrs_plan_lob = hp.line_of_business,			---NEW
		mbrs_plan_lob_desc = lob.description,			---NEW
		
		ma.client_group_number,
		m.gender,
		diagnosis = upper(a.icd10_code),

		all_ICD10_codes = LTRIM((Select distinct substring(
						(Select ',  ' + UPPER(ST1.icd10_code)  AS [text()]
						 From Dean.dbo.auth_icd10_codes ST1 with(nolock)
						 Where ST1.auth_id = ST2.auth_id
						 ORDER BY ST1.auth_id
						 For XML PATH ('')
						 ), 2, 1000) 
							From Dean.dbo.auth_icd10_codes ST2 with(nolock)
							where auth_id = a.auth_id)),

		m.member_id,
		m.client_member_id,
		mbr_dob = convert (char(10), m.dob, 101),
		mbr_fname = m.fname,
		mbr_lname = m.lname,
		mbr_age = datediff(yy, m.dob, a.date_call_rcvd),
		
		a.phys_id,
		phys_tax_id = p.tax_id,
		phys_npi = p.npi,
		p.client_physician_id,
		provider_name = p.lname + ', ' + p.fname,
		provider_type = ads.data, 
		
		oon_flag = case when a.fac_id = 1 then 'Yes' else '' end,
		
		
		fac_id = case when a.fac_id = 1 then afg.fac_id else a.fac_id end,
		fac_name = case when a.fac_id = 1 then afg.facility_name else f.facility_name end,
		fac_tin = case when a.fac_id = 1 then afg.provider_tax_id else f.provider_tax_id end,
		fac_npi = case when a.fac_id = 1 then NULL else app.provider_npi end,
		fac_address = case when a.fac_id = 1 then afg.address1 else f.address1 end,
		fac_city = case when a.fac_id = 1 then afg.city else f.city end,
		fac_state = case when a.fac_id = 1 then afg.state else f.state end,
		fac_zip = case when a.fac_id = 1 then afg.zip else f.zip end,
		fac_mis = case when a.fac_id = 1 then NULL else app.provider_mis end,
		fac_phone = case when a.fac_id = 1 then afg.contact_ac + '-' + afg.contact_phone else f.ac + '-' + f.phone end,
		fac_fax = case when a.fac_id = 1 then afg.fax_ac + '-' + afg.fax_phone else f.ac_fax + '-' + f.fax end,
		
		--clinical_rationale_orig = adhoc.dbo.uf_get_clinical_rationale_NIACOMBINE(au.car_id, au.auth_id),
		
		a1302_date = (select min(aal.date_action) from Dean.dbo.auth_action_log aal with(nolock) 
						where aal.auth_id = a.auth_id and aal.auth_action_code = 1302 and aal.date_action < a.date_call_rcvd),  --Date and Time Fax received recorded during auth entry (used for timeliness rules)
		
		--a1567_date = (select min(aal.date_action) from Dean.dbo.auth_action_log aal with(nolock) 
		--				where aal.auth_id = a.auth_id and aal.auth_action_code = 1567),  --Member has exceeded benefit limit based on prior history
		
		a1525_date = (select min(aal.date_action) from Dean.dbo.auth_action_log aal with(nolock) 
						where aal.auth_id = a.auth_id and aal.auth_action_code = 1525),  --Benefits Exhausted - Denial issued after Magellan has verified that benefits are exhausted
		
		--select * from niacore..auth_action_codes where auth_action_code in (1302, 1567, 1525)

		auth_validity_start = avs.start_date,
		auth_validity_end = avs.end_date,
		
		hab_or_rehab = case when hh.auth_id is not null then 'Habilitative' else 'Rehabilitative' end


into	#pm

from	#auths au with(nolock)
		join Dean.dbo.authorizations a with(nolock) on (au.auth_id = a.auth_id)
		join niacore..auth_retro_flags r with(nolock) on (a.retro_flag = r.retro_flag)
		join niacore..authorization_types aty with(nolock) on (a.authorization_type_id = aty.authorization_type_id)
		left outer join Dean.dbo.authorization_data_supplemental ads with(nolock) on (a.auth_id = ads.auth_id and ads.data_type_id = 542)	
		join Dean.dbo.members m with(nolock) on (a.member_id = m.member_id)
		join Dean.dbo.member_address ma with(nolock) on (a.member_id = ma.member_id)
		join niacore..health_plan hp with(nolock) on (m.plan_id = hp.plan_id)
		join niacore..line_of_business lob with(nolock) on (hp.line_of_business = lob.line_of_business)
		join niacore..health_carrier hc with(nolock) on (hp.car_id = hc.car_id)
		join niacore..health_plan_groups hpg with(nolock) on (hp.health_plan_group_id = hpg.health_plan_group_id)
		join nirad..facilities f with(nolock) on (a.fac_id = f.fac_id)
		join Dean.dbo.physicians p with(nolock) on (a.phys_id = p.phys_id)
		left outer join nirad..applications app with(nolock) on (f.fac_id = app.fac_id and hp.car_id = app.car_id)
		left outer join Dean.dbo.auth_partial_link apl with(nolock) on (a.auth_id = apl.auth_id)
		left outer join #units_auth ca with(nolock) on (a.auth_id = ca.auth_id)

		left outer join Dean.dbo.auth_validity_spans avs with(nolock) on (a.auth_id = avs.auth_id and avs.sequence = 
			(select max(avs2.sequence) from Dean.dbo.auth_validity_spans avs2 with(nolock) 
			 where avs.auth_id = avs2.auth_id)) 
		
	--Look for max(final status) for each auth
		left outer join Dean.dbo.auth_status_change aschg with(nolock) on (a.auth_id = aschg.auth_id 
					and aschg.date_changed = (select max(aschg2.date_changed) from Dean.dbo.auth_status_change aschg2 with(nolock)
												join niacore..auth_status_codes ascd2 with(nolock) on (aschg2.new_auth_status = ascd2.auth_status)
												where aschg.auth_id = aschg2.auth_id
												and ascd2.final_status_flag = 1))
												
		left outer join niacore..auth_status_codes ascd with(nolock) on (aschg.new_auth_status = ascd.auth_status)
		left outer join niacore..auth_outcomes aout with(nolock) on (ascd.auth_outcome = aout.auth_outcome)
		
		left outer join niacore..Customer_Determination_Codes cd with (nolock) on (ascd.customer_determination_code = cd.customer_determination_code)
		left outer join niacore..Customer_Group_Determination_Codes cgd with (nolock) on (cd.customer_group_determination_code = cgd.customer_group_determination_code)		
	


		left outer join Dean.dbo.auth_facility_generic afg with(nolock) on (a.auth_id = afg.auth_id 
					and afg.date_updated = (select max(afg2.date_updated) from Dean.dbo.auth_facility_generic afg2 with(nolock) 
											where afg2.auth_id = a.auth_id
											 and afg2.facility_name not like '%cancel%'
											 and afg2.facility_name not like 'Other%'))
											 									 
		left outer join #hab hh with(nolock) on (a.auth_id = hh.auth_id)

--select * from #pm
---------------------------------------------------------------------------------------------------
--Identify member's plan at the time of the initial determination

select	pm.*,

		pm_typetherapycode = ads1.data,
		
		therapy_type_code = case when ads1.data = 1 then 'PT'
								 when ads1.data = 2 then 'OT'
								 when ads1.data = 3 then 'ST'
								 else 'Unknown' end,
		pmt.therapy_type,
		
		--select * from niacore..physical_medicine_therapy_types
		
		
		min_date_changed = aschg5.date_changed,
		min_status_desc = ascd5.status_desc,
		min_auth_outcome = ascd5.auth_outcome,

		determ_plan_id = isnull(hp2.plan_id, pm.mbrs_plan_id),
		determ_plan_name = isnull(hp2.plan_name, pm.mbrs_plan_name),
		determ_plan_group = isnull(hpg2.description, pm.mbrs_plan_group),
		determ_plan_state = isnull(hp2.state, pm.mbrs_plan_state),
		determ_plan_lob = isnull(hp2.line_of_business, pm.mbrs_plan_lob),		
		determ_plan_lob_desc = isnull(lob2.description, pm.mbrs_plan_lob_desc),
	
	--NEW 12/18/2018	
		apprv_by_algo = case when pm.case_outcome = 'Approve Physical Medicine request'
								--and pm.final_status_code in ('aa','xa','ea')   --Approved, Retro Approved, Eligibility Approved
								then 'Yes' else 'No' end,
								
		algo_offer_accepted = case when f.note like '%accepted%' then 'Yes'
									when f.note like '%declined%' then 'No'
									else '' end

		--next_final_status = (select min(aschg2.date_changed) from auth_status_change aschg2 with(nolock)
		--					join niacore..auth_status_codes ascd2 with(nolock) on (aschg2.new_auth_status = ascd2.auth_status)
		--					where aschg2.auth_id = pm.auth_id 
		--					and ascd2.final_status_flag = 1
		--					and aschg2.date_changed > pm.final_status_date),

into	#pmm
from	#pm pm with(nolock)
		left outer join #offer f with(nolock) on (pm.car_id = f.car_id and pm.auth_id = f.auth_id)

--MIN final status
		left outer join Dean.dbo.auth_status_change aschg5 with(nolock) on (pm.auth_id = aschg5.auth_id
				and aschg5.date_changed = (select MIN(aschg6.date_changed) from Dean.dbo.auth_status_change aschg6 with(nolock),
											niacore..auth_status_codes ascd6 with(nolock)
											where aschg5.auth_id = aschg6.auth_id
											and aschg6.new_auth_status = ascd6.auth_status
											and ascd6.final_status_flag = 1
											))
											
		left outer join niacore..auth_status_codes ascd5 with(nolock) on (aschg5.new_auth_status = ascd5.auth_status)

		left outer join Dean.dbo.members_audit ma with(nolock) on (pm.member_id = ma.member_id
					and ma.column_name = 'plan_id'
					and ma.changed_date > aschg5.date_changed
					and isnumeric(ma.old_data) = 1
					and ma.changed_date = (Select min(changed_date) from Dean.dbo.members_audit with(nolock)
                        where member_id = pm.member_id and
                        column_name = 'plan_id' and
                        isnumeric(old_data) = 1 and
                        changed_date > aschg5.date_changed))

		left outer join niacore..health_plan hp2 with(nolock) on (ma.old_data = hp2.plan_id)
		left outer join niacore..health_plan_groups hpg2 with(nolock) on (hp2.health_plan_group_id = hpg2.health_plan_group_id)
		left outer join niacore..line_of_business lob2 with(nolock) on (hp2.line_of_business = lob2.line_of_business)

		left outer join Dean.dbo.authorization_data_supplemental ads1 with(nolock)
				on (pm.auth_id = ads1.auth_id and ads1.data_type_id = 412)  --PM_TypeOfTherapy
				
		left outer join niacore..physical_medicine_therapy_types pmt with(nolock) on (ads1.data = pmt.physical_medicine_therapy_type_id)
				
--select * from #pmm
---------------------------------------------------------------------------------------------------
-- Get Letter Dates and other items

select	pmm.*,
		market = case	when pmm.car_id = 159 and pmm.determ_plan_state in ('PA','NY','NJ','WV','DE') then 'Aetna ' + pmm.determ_plan_state
						when pmm.car_id = 159 and pmm.determ_plan_state not in ('PA','NY','NJ','WV','DE') 
								then left(pmm.determ_plan_group, 8) --Pull from plan_group field if plan state is not one of the 5 markets.
						
						when pmm.car_id = 129 and pmm.determ_plan_id in (27133, 27134, 27135, 27136, 27610, 27611) then 'Gateway Health PA - Medicaid'
						when pmm.car_id = 129 and pmm.determ_plan_id in (27525, 27526, 27911) then 'Gateway Health PA - Medicare'
						
						--when pmm.car_id = 70 then pmm.car_name
						--when pmm.car_id = 107 then pmm.car_name
						
						else pmm.car_name end,

		Member_Letter_Date = (select min(date_entered) 
								from Dean.dbo.auth_action_log aal with (nolock)
								where  pmm.auth_id = aal.auth_id
										and aal.auth_action_code in ('769','904','905')
										and aal.date_entered >= pmm.final_status_date),

		Phys_Letter_Date = (select min(date_entered) 
								from Dean.dbo.auth_action_log aal with (nolock)
								where  pmm.auth_id = aal.auth_id
										and aal.auth_action_code in ('770','912','913')
										and aal.date_entered >= pmm.final_status_date),

		a785_date = (select min(date_entered) 
								from Dean.dbo.auth_action_log aal with (nolock)
								where  pmm.auth_id = aal.auth_id
										and aal.auth_action_code in ('785','1410')  --Request has been changed from non-expedited to expedited
										),
										--785 = Request has been changed from non-expedited to expedited
										--1410 = Request was expedited at intake									
		--a786_date = (select min(date_entered) 
		--						from Dean.dbo.auth_action_log aal with (nolock)
		--						where  pmm.auth_id = aal.auth_id
		--								and aal.auth_action_code in ('786')  --Request has been changed from expedited to non-expedited
		--								),
						
		--current_status = ascd.status_desc,
		--current_queue = iq1.description,
		--current_queue_date = aqh.queue_date,
		
		benefit_denial = case when a1525_date is not null then 'Yes' else 'No' end,
		
		tp.visits_requested,
		tp.visits_approved,
		tp.visits_denied
		
		--hab_or_rehab = ads.data

		--Validity_period_FROM = convert (char(20), dbo.uf_get_auth_validity_period_start (pmm.auth_id, pmm.car_id),101),
		--Validity_period_TO = convert (char(20), dbo.uf_get_auth_validity_period_end (pmm.auth_id, pmm.car_id, dbo.uf_get_auth_validity_period_start (pmm.auth_id, pmm.car_id)),101)
		
into	#pmmm

from	#pmm pmm with(nolock)
		--left outer join #max_queue aqh with(nolock) on (pmm.car_id = aqh.car_id and pmm.auth_id = aqh.auth_id)
		--left outer join niacore..informa_queues iq1 with(nolock) on (aqh.queue_code = iq1.queue_code)
		--left outer join Dean.dbo.auth_status_change aschg with(nolock) on (pmm.auth_id = aschg.auth_id and aschg.isfinal = 1)
		--left outer join niacore..auth_status_codes ascd with(nolock) on (aschg.new_auth_status = ascd.auth_status)
		
		left outer join Dean.dbo.physical_medicine_therapy_plan tp with(nolock) on (pmm.auth_id = tp.auth_id)

		--left outer join Dean.dbo.authorization_data_supplemental ads with(nolock) on (pmm.auth_id = ads.auth_id 
		--		and ads.data_type_id = 413)

--select * from #pmmm order by tracking_number, auth_id      where tracking_number = '065241384' order by auth_id				
---------------------------------------------------------------------------------------------------
-- Update provider_type for CENTENE ONLY

update	p
set		p.provider_type = p.therapy_type_code
from	#pmmm p
where	p.car_id in (93,103,98,141,129,169,83,84)
		and p.provider_type is null
		
		
---------------------------------------------------------------------------------------------------
-- Isolate all auths with a LINK_ID
-- Does not apply to Dean

select	car_id, link_id, auth_id,
		link_seq = ROW_NUMBER() OVER(Partition BY car_id, link_id ORDER BY car_id, link_id, auth_id),
		tracking_number, final_status_code, final_status_desc, final_status_outcome, final_status_date, UM_Outcome, a1525_date,
		apprv_by_algo, member_letter_date, phys_letter_date

into	#links1
from	#pmmm pm with(nolock)

where	pm.link_id is not null
order by car_id, link_id, auth_id

---------------------------------------------------------------------------------------------------
-- Get all the linked sets into a single row
-- Does not apply to Dean

select	z1.car_id, z1.link_id, 

		first_auth_id = z1.auth_id, first_status = z1.final_status_code, first_status_desc = z1.final_status_desc, 
		first_outcome = z1.final_status_outcome, first_determ_date = z1.final_status_date,
		first_apprv_by_algo = z1.apprv_by_algo,	
		first_member_letter_date = z1.member_letter_date,
		first_phys_letter_date = z1.phys_letter_date,	
		
		second_auth_id = z2.auth_id, second_status = z2.final_status_code, second_status_desc = z2.final_status_desc, 
		second_outcome = z2.final_status_outcome, second_determ_date = z2.final_status_date,
		second_apprv_by_algo = z2.apprv_by_algo,	
		second_member_letter_date = z2.member_letter_date,
		second_phys_letter_date = z2.phys_letter_date,	
		
		
		auth_outcome_key = concat(z1.final_status_outcome, z2.final_status_outcome),
		
		both_auths_complete = case when z1.final_status_date is not null and z2.final_status_date is not null then 'Yes' else 'No' end,
		
		max_determ_date = (select max(z3.final_status_date) from #links1 z3 with(nolock) where z1.car_id = z3.car_id and z1.link_id = z3.link_id),
		
		min_determ_date = (select min(z4.final_status_date) from #links1 z4 with(nolock) where z1.car_id = z4.car_id and z1.link_id = z4.link_id),  ---NEW2

		benefit_denial = case when z1.a1525_date is not null or z2.a1525_date is not null then 'Yes' else 'No' end
		
into	#links2
from	#links1 z1 with(nolock)
		left outer join #links1 z2 with(nolock) on (z1.car_id = z2.car_id and z1.link_id = z2.link_id and z2.link_seq = 2)

where	z1.link_seq = 1

---------------------------------------------------------------------------------------------------
-- Flag the partial denials
-- Does not apply to Dean

select	x.*,
		partial_denial_flag = case when auth_outcome_key in ('AD','DA') then 1 else 0 end,
		
		link_determ_code = RTRIM(isnull(first_status,'xx') + '/' + isnull(second_status,'xx')),
		
		link_determ_desc = RTRIM(isnull(first_status_desc,'xx') + '/' + isnull(second_status_desc,'xx')),
		
		both_apprv_by_algo = case when first_apprv_by_algo = 'Yes' and second_apprv_by_algo = 'Yes' then 'Yes' else 'No' end,   
		
		link_mbr_ltr_date = case when both_auths_complete = 'Yes' 
									and isnull(first_member_letter_date, '01/01/1900') > isnull(second_member_letter_date, '01/01/1900')
									 then first_member_letter_date
								 
								 when both_auths_complete = 'Yes' 
									and isnull(second_member_letter_date, '01/01/1900') > isnull(first_member_letter_date, '01/01/1900') 
									 then second_member_letter_date  --find the max letter date between the two auths
								 end,
								 
		link_phys_ltr_date = case when both_auths_complete = 'Yes' 
									and isnull(first_phys_letter_date, '01/01/1900') > isnull(second_phys_letter_date , '01/01/1900')
									 then first_phys_letter_date
									 
								  when both_auths_complete = 'Yes' 
									and isnull(second_phys_letter_date, '01/01/1900') > isnull(first_phys_letter_date, '01/01/1900') 
									 then second_phys_letter_date  --find the max letter date between the two auths
								 end

into	#links3

from	#links2 x with(nolock)

---------------------------------------------------------------------------------------------------
-- Update more data items


IF OBJECT_ID('tempdb..#pm2') IS NOT NULL drop table #pm2

select	pm.*,
		urgency = case	when pm.expedite_flag = 'n' and pm.retro_flag = 'n' then 'Standard Pre-Service'
						when pm.expedite_flag = 'y' and pm.retro_flag = 'n' then 'Expedited Pre-Service'
						when pm.expedite_flag = 'y' and pm.retro_flag <> 'n' then 'Retrospective'
						when pm.expedite_flag = 'n' and pm.retro_flag <> 'n' then 'Retrospective'
						end,
		
		determ_count = case when pm.final_status_code is not null
						then 1 else 0 end,
							
		updated_UM_Outcome	= case  --when x3.auth_outcome_key in ('AD','DA') then 'Partially Non-Certified' 
								when pm.link_id is null and pm.final_status_code = 'pt' then 'Partially Non-Certified'  --New for Centene
								else pm.UM_Outcome end,
		
		linked_auth_id = NULL,  --x3.second_auth_id,

		--pt_den_final_status_desc = case when ((pm.final_status_code = 'pt') or (pm2.auth_id is not null and pm2.final_status_code = 'ma'))
		--								then pm2.final_status_desc else '' end,  --this doesn't work right - not sure it is needed
		
		--for partials, get the clinical rationale for the denial onto the approval
		--clinical_rationale = isnull(tp.pt_denied_clin_rationale, pm.clinical_rationale_orig),
		--clinical_rationale = pm.clinical_rationale_orig,
		has_link_id = case when pm.link_id is not null then 'Y' else '' end,
		
		is_true_pt = case --when pm.link_id is not null and x3.partial_denial_flag = 1 then 'Y'   --This will work for Aetna/Coventry 
						  when pm.link_id is null and pm.final_status_code = 'pt' then 'Y'		--This will work for Centene
						  else '' end,
			
		partial_denial_flag = case	--when pm.link_id is not null and x3.partial_denial_flag = 1 then 1   --This will work for Aetna/Coventry 
							when pm.link_id is null and pm.final_status_code = 'pt' then 1		--This will work for Centene
							else NULL end,
							
		updated_flag = 0
		
into	#pm2

from	#pmmm pm with(nolock)
		--left outer join #pmmm pm2 with(nolock) on (pm.car_id = pm2.car_id and pm.link_id = pm2.link_id and pm.auth_id <> pm2.auth_id)
		--left outer join #links3 x3 with(nolock) on (pm.car_id = x3.car_id and pm.link_id = x3.link_id)


order by pm.link_id, pm.auth_id

---------------------------------------------------------------------------------------------------
-- Reset determ_count to zero for the second auth in each pair of linked auths.

update	pm2
set		determ_count = 2,
		updated_flag = 1
from	#pm2 pm2 with(nolock)
		join #links3 x3 with(nolock) on (pm2.car_id = x3.car_id and pm2.link_id = x3.link_id and pm2.auth_id = x3.second_auth_id)


---------------------------------------------------------------------------------------------------
-- Reset determ_count to zero for auths that have a link id but one of the auths doesn't yet have a final determination.

update	pm2
set		determ_count = 3
from	#pm2 pm2 with(nolock)
		join #links3 x3 with(nolock) on (pm2.car_id = x3.car_id and pm2.link_id = x3.link_id and x3.both_auths_complete = 'No')
		
---------------------------------------------------------------------------------------------------
-- Prepare final details for Determinations Activity Report

select	pm.car_id,
		pm.car_name,
		pm.market,
		pm.auth_id, 
		pm.link_id,
		linked_auth_id = isnull(x3.second_auth_id, ''),
		partial_denial_flag = case when x3.partial_denial_flag = 1 then 'Yes' 
								   when pm.car_id in (93,103) and pm.final_status_code = 'pt' then 'Yes'
								   else '' end,
		
		
		--subsequent_req_flag = case when right(pm.auth_id,1) in ('A','B','C','D','E','F','G','H',
		--		'I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z')
		--		and pm.link_id is null
		--		then 'Yes' else 'No' end,
		subsequent_req_flag = case when left(right(pm.auth_id,3),2) = '-R'
				and pm.link_id is null
				then 'Yes'
				when left(right(pm.auth_id,4),2) = '-R'
				and pm.link_id is null
				then 'Yes' else 'No' end,
		pm.tracking_number, 
		
		pm.urgency, --pm.combo_flag, 
		--request_date = convert (char(10), pm.date_call_rcvd, 101),
		request_date = case when pm.a1302_date is not null then pm.a1302_date else pm.date_call_rcvd end,
		pm.auth_origin,
		Initiated_by_Fax = case when pm.a1302_date is not null then 'Yes' else '' end,
		plan_group = pm.determ_plan_group,
		plan_id = pm.determ_plan_id,
		plan_name = pm.determ_plan_name,
		lob_code = pm.determ_plan_lob,
		lob_desc = pm.determ_plan_lob_desc,
		
		client_group_number = pm.client_group_number,
		client_group_type = '',
		pm.mbr_age,
		mbr_gender = pm.gender,
		pm.member_id,
		
		Apprv_by_Algo = case when pm.has_link_id = 'Y' then x3.both_apprv_by_algo else pm.apprv_by_algo end,
		
		Algo_offer_accepted,
		
		UM_Determ_Outcome = pm.updated_UM_Outcome,

		--If the auth is part of a linked set, take the latest determ date for the pair.
		determination_date = case when pm.has_link_id = 'Y'	then x3.max_determ_date	else pm.final_status_date end,
		
		final_status_code = case when pm.has_link_id = 'Y' then x3.link_determ_code else pm.final_status_code end,
		
		final_status_desc = case when pm.has_link_id = 'Y' then x3.link_determ_desc else pm.final_status_desc end,
		

		min_determination_date = case when pm.has_link_id = 'Y' then x3.min_determ_date else pm.min_date_changed end,		---NEW2

		Member_Letter_Date = case when pm.has_link_id = 'Y' then x3.link_mbr_ltr_date else pm.Member_Letter_Date end,
		
		Phys_Letter_Date = case when pm.has_link_id = 'Y' then x3.link_phys_ltr_date else pm.Phys_Letter_Date end,
		
		benefit_denial = case when pm.has_link_id = 'Y' then x3.benefit_denial else pm.benefit_denial end,
		
		--partial_denial_set = case when pt_den_flag = 1 
		--							then pm.auth_id + ' - ' + pm.final_status_desc + ', ' + pm.pt_den_auth_id + ' - ' + pt_den_final_status_desc
		--							else '' end,
									
		--clinical_rationale = ISNULL(CAST(REPLACE(REPLACE(REPLACE(pm.clinical_rationale, CHAR(13), ''), CHAR(10), ''), CHAR(9), '') AS VARCHAR(255)),''),
	
		pm.phys_id,
		pm.phys_tax_id,
		provider_npi = '', --pm.provider_npi,
		pm.client_physician_id,
		pm.provider_name,
		provider_type = isnull(pm.provider_type,'Unknown'),
		
		a97035_apprv_units =	case when pm.has_link_id = 'Y'		 then c.a97035_apprv_units		else pm.a97035_apprv_units	end,
		a97035_den_units =		case when pm.has_link_id = 'Y'		 then c.a97035_den_units		else pm.a97035_den_units	end,
		a97110_apprv_units =	case when pm.has_link_id = 'Y'		 then c.a97110_apprv_units		else pm.a97110_apprv_units	end,
		a97110_den_units =		case when pm.has_link_id = 'Y'		 then c.a97110_den_units		else pm.a97110_den_units	end,
		a97140_apprv_units =	case when pm.has_link_id = 'Y'		 then c.a97140_apprv_units		else pm.a97140_apprv_units	end,
		a97140_den_units =		case when pm.has_link_id = 'Y'		 then c.a97140_den_units		else pm.a97140_den_units	end,
		a97535_apprv_units =	case when pm.has_link_id = 'Y'		 then c.a97535_apprv_units		else pm.a97535_apprv_units	end,
		a97535_den_units =		case when pm.has_link_id = 'Y'		 then c.a97535_den_units		else pm.a97535_den_units	end,
		a97750_apprv_units =	case when pm.has_link_id = 'Y'		 then c.a97750_apprv_units		else pm.a97750_apprv_units	end,
		a97750_den_units =		case when pm.has_link_id = 'Y'		 then c.a97750_den_units		else pm.a97750_den_units	end,
		a97760_apprv_units =	case when pm.has_link_id = 'Y'		 then c.a97760_apprv_units		else pm.a97760_apprv_units	end,
		a97760_den_units =		case when pm.has_link_id = 'Y'		 then c.a97760_den_units		else pm.a97760_den_units	end,
		a98940_apprv_units =	case when pm.has_link_id = 'Y'		 then c.a98940_apprv_units		else pm.a98940_apprv_units	end,
		a98940_den_units =		case when pm.has_link_id = 'Y'		 then c.a98940_den_units		else pm.a98940_den_units	end,
		other_cpt = '',
		
		visits_requested = isnull(pm.visits_requested,0),
		visits_approved = isnull(pm.visits_approved,0),
		visits_denied = isnull(pm.visits_denied,0),
		
		expedited = UPPER(pm.expedite_flag),
		expedited_date = case when pm.expedite_flag = 'Y' then convert (char(20), a785_date, 101) else '' end,
		--a785_date,						
		--a786_date,
		retro_flag = case when pm.retro_flag = 'n' then 'N' else 'Y' end,
		combo_flag = UPPER(pm.combo_flag),
		diagnosis_code = diagnosis,
		pm.client_member_id,
		pm.mbr_dob,
		pm.mbr_fname,
		pm.mbr_lname,
		
		pm.fac_name,
		pm.fac_tin,
		pm.fac_address,
		pm.fac_city,
		pm.fac_state,
		pm.fac_zip,
		pm.fac_mis,
		pm.fac_phone,
		pm.fac_fax,
		
		Validity_period_FROM =	isnull(convert(char(10),pm.auth_validity_start, 101), ''),  --convert (char(20), dbo.uf_get_auth_validity_period_start (p.auth_id, p.car_id),101),
		Validity_period_TO =	isnull(convert(char(10),pm.auth_validity_end, 101), ''),  --convert (char(20), dbo.uf_get_auth_validity_period_end (p.auth_id, p.car_id, dbo.uf_get_auth_validity_period_start (p.auth_id, p.car_id)),101),
		
		
		INSERTTS = getdate(),
		pm.all_ICD10_codes,
		pm.hab_or_rehab
		
		
into	#pm3
from	#pm2 pm with(nolock)
		left outer join #units_link c with(nolock) on (pm.car_id = c.car_id and pm.link_id = c.link_id)
		left outer join #links3 x3 with(nolock) on (pm.car_id = x3.car_id and pm.link_id = x3.link_id)

where	pm.determ_count = 1
		and final_status_date between (select start_date from #rpt_parms) and dateadd(dd,1,(select end_date from #rpt_parms))
		

--select count(*) from #pm3 where final_status_date >= '08/01/2018'
--select * from #pm2 where final

---------------------------------------------------------------------------------------------------
--Get TATs

select	p3.*,
		TAT_CD = datediff(dd, p3.request_date, p3.min_determination_date),
		TAT_BD = adhoc.dbo.uf_working_days(p3.request_date, p3.min_determination_date),
		
		determ_MMYYYY = convert(varchar(7), determination_date, 120)
			
into	#pm4
from	#pm3 p3 with(nolock)

---------------------------------------------------------------------------------------------------
--Assign TAT groups

select	p4.*,
		TAT_BD_group = case	when TAT_BD in (0,1,2,3) then '0-3 days'
							when TAT_BD in (4,5,6,7) then '4-7 days'
							when TAT_BD in (8,9,10,11) then '8-11 days'
							when TAT_BD in (12,13,14,15) then '12-15 days'
							when TAT_BD > 15 then '16+ days'
							else '' end,
							
		TAT_CD_group = case	when TAT_CD in (0,1,2,3) then '0-3 days'
							when TAT_CD in (4,5,6,7) then '4-7 days'
							when TAT_CD in (8,9,10,11) then '8-11 days'
							when TAT_CD in (12,13,14,15) then '12-15 days'
							when TAT_CD > 15 then '16+ days'
							else '' end,
							
		multiple_determ_dates = case when p4.determination_date <> p4.min_determination_date then 'Yes' else 'No' end	   ---NEW2

into	#pm5
from	#pm4 p4 with(nolock)


---------------------------------------------------------------------------------------------------
--Add sequence to find initial request
--Get all auths to be numbered into a separate table
--Doing this to exclude certain withdrawals


select	p5.car_id, p5.auth_id, p5.linked_auth_id, p5.link_id, p5.tracking_number, p5.partial_denial_flag, p5.final_status_code, p5.final_status_desc,
		seq = ROW_NUMBER() OVER(Partition BY car_id, tracking_number ORDER BY car_id, tracking_number, auth_id)

into	#seq
from	#pm5 p5 with(nolock)
where	p5.final_status_code not in ('rw','rw/rw')  --Admin Withdrawals


---------------------------------------------------------------------------------------------------
--Bring the sequence number into the main data set
--Modify sequence number.  We want the initial request to be seq = 0.
--1st subsequent request will be seq = 1.
--2nd subsequent = 2, etc.

--drop table #pm6

select	p5.*,
		seq_num = s.seq - 1,
		inital_or_subsequent = case when s.seq = 1 then 'Initial' else 'Subsequent' + ' ' + convert(varchar,s.seq - 1) end

into	#pm6
from	#pm5 p5 with(nolock)
		left outer join #seq s with(nolock) on (p5.car_id = s.car_id and p5.auth_id = s.auth_id)
		
---------------------------------------------------------------------------------------------------

alter table #pm6 drop column subsequent_req_flag

---------------------------------------------------------------------------------------------------

--Reset all the "Subsequents" to "not apprv by algo".  All Subsequents go to clinical review.
update	p6
set		apprv_by_algo = 'N/A'
from	#pm6 p6 
where	seq_num > 0  ---NEW 12/18/2018

---------------------------------------------------------------------------------------------------
DROP TABLE Adhoc.dbo.Dean_Phys_Med_Determs

SELECT	car_id,
		car_name,
		market,
		auth_id,
		link_id,
		linked_auth_id,
		partial_denial_flag,
		tracking_number,
		seq_num,
		inital_or_subsequent,
		urgency,
		request_date,
		auth_origin,
		Initiated_by_Fax,
		plan_group,
		plan_id,
		plan_name,
		lob_code,
		lob_desc,
		client_group_number,
		client_group_type,
		mbr_age,
		mbr_gender,
		member_id,
		Apprv_by_Algo,
		Algo_offer_accepted,
		UM_Determ_Outcome,
		determination_date,
		final_status_code,
		final_status_desc,
		min_determination_date,
		benefit_denial,
		phys_id,
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
		visits_requested,
		visits_approved,
		visits_denied,
		expedited,
		expedited_date,
		retro_flag,
		combo_flag,
		diagnosis_code,
		all_ICD10_codes,
		hab_or_rehab,
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
		Validity_period_TO,
		INSERTTS,
		TAT_CD,
		TAT_BD,
		determ_MMYYYY,
		TAT_BD_group,
		TAT_CD_group,
		multiple_determ_dates,
		Member_Letter_Date,
		Phys_Letter_Date

INTO	Adhoc.dbo.Dean_Phys_Med_Determs
FROM	#pm6


--select distinct provider_type from Adhoc.dbo.Dean_Phys_Med_Determs order by tracking_number, auth_id --where tracking_number = '065241384'

---------------------------------------------------------------------------------------------------
--  Get number of auths per tracking number


select	dpm.car_id, dpm.auth_id, dpm.tracking_number,
		seq = ROW_NUMBER() OVER(Partition BY car_id, tracking_number ORDER BY car_id, tracking_number, auth_id)

into	#track_auth_count
from	Adhoc.dbo.Dean_Phys_Med_Determs dpm

--select * from #track_auth_count order by tracking_number, auth_id
---------------------------------------------------------------------------------------------------
--  Get max number of auths per tracking number


select	tac.car_id, 
		tac.tracking_number,
		max(tac.seq) as max_auths

into	#track_auth_max
from	#track_auth_count tac

group by tac.car_id,
		 tac.tracking_number

--select * from #track_auth_max order by tracking_number
---------------------------------------------------------------------------------------------------

-- Update the final determination date to be the initial determination when there is more than one auth w/i a tracking number
-- As each subsequent auth comes in, the final determination date is currently being set to the final date of the entire tracking
-- number.

update	dpm
set		determination_date = min_determination_date
from	Adhoc.dbo.Dean_Phys_Med_Determs dpm with(nolock)
		join #track_auth_max tam with(nolock) on (dpm.car_id = tam.car_id and dpm.tracking_number = tam.tracking_number and tam.max_auths > 1)
		
---------------------------------------------------------------------------------------------------

update	dpm
set		determ_MMYYYY = convert(varchar(7), determination_date, 120)
from	Adhoc.dbo.Dean_Phys_Med_Determs dpm with(nolock)
				
---------------------------------------------------------------------------------------------------
 
update	dpm
set		provider_type = ' '
from	Adhoc.dbo.Dean_Phys_Med_Determs dpm with(nolock)
		


--select distinct provider_type from	Adhoc.dbo.Dean_Phys_Med_Determs dpm


--select * from	Adhoc.dbo.Dean_Phys_Med_Determs order by tracking_number, auth_id

--select * from Dean.dbo.auth_icd10_codes where auth_id in ('01161977284','07191877202-R1','06121977322','09241977287') order by auth_id, icd10_code




















--END

--GO

--GRANT EXECUTE ON [Adhoc].[dbo].[DEAN_PHYS_MED_01] TO db_execallsp

--GO

