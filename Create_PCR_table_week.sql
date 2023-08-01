/*************************************************************************************************************************
*  Requested By:		Bruce Heck
* Request Due Date:		06/04/18
* Request Received:		05/25/18
* Created By:			Michelle Boggs
* Create Date:			05/31/18
* Last Modified Date:	
* Last Modified By:		
* Adhoc #:				 
* Report Name:			PCR Volume
* Report Description:	All Carriers
*						Per Bruce
*
*						-  Do not need 2016 data
*						-  Add filter for LOB
*						-  Add P2P
*************************************************************************************************************************/

USE  ASDReportDB

DROP TABLE  #temp1
DROP TABLE  #temp2
DROP TABLE	#temp_P2P
DROP TABLE  #temp_PCR
DROP TABLE  #temp_action_112
DROP TABLE  #temp3
DROP TABLE  adhoc.dbo.PCR_weekly_data


DECLARE		@start_date datetime,
			@end_date datetime

SET			@start_date = '12/06/2020'      --This should be the last 12 weeks (Sunday - Saturday) increase two weeks
SET			@end_date	= '02/27/2021'		

---------------------------------------------------------------------------------------------------

SELECT	a.car_id,
--      hp.car_name as 'plan_name'
		a.auth_id,
		a.authorization_type_id,
		a.combo_flag,
		aschg.new_auth_status,
		ascd.report_translation,
		ascd.recon_status_flag,
		aschg.date_changed as 'determination_date',
		a.case_id,
		a.auth_status,
		a.cpt4_code,
case	when a.proc_desc like '% - %' then LEFT(a.proc_desc,charindex('-',a.proc_desc,0)-2)
		when a.proc_desc like '% (%)' then LEFT(a.proc_desc,charindex('(',a.proc_desc,0)-2)
		when a.proc_desc like '%(%'   then LEFT(a.proc_desc,charindex('(',a.proc_desc,0)-1)
		else a.proc_desc end as 'proc_desc',
		case_description = c.description,
		ascd.auth_outcome,
		ascd.auth_status_type,
		d.auth_status_type_description,
		e.description as 'outcome_description',
case	when a.is_user_id = 1998 then 1 else 0 end as 'radmd_volume',
case	when a.is_user_id = 1998 and a.contact_type_id = 6 then 1 else 0 end as 'retro_claims_auths',
		(datepart(yyyy,aschg.date_changed)*100)+datepart(mm,aschg.date_changed) as 'month_year',
		convert(varchar(4),datepart(yyyy,aschg.date_changed))+
			(case when datepart(mm,aschg.date_changed) in (1,2,3) then 'Q1'
				  when datepart(mm,aschg.date_changed) in (4,5,6) then 'Q2'
				  when datepart(mm,aschg.date_changed) in (7,8,9) then 'Q3'
				  when datepart(mm,aschg.date_changed) in (10,11,12) then 'Q4' end) as 'quarter_year',
		datepart(ww,aschg.date_changed) as 'week_in_year', 
		iut.report_level as 'level_of_resolution', 
	   (isu.lname + ', ' + isu.fname) as 'reviewer_name', 
case	when ascd.auth_outcome = 'A' then 1 else 0 end as 'approvals', 
case	when ascd.auth_outcome <> 'A' and ascd.auth_status_type in ('C','R') then 1 else 0 end as 'clinical_denials', 
case	when ascd.auth_outcome <> 'A' and ascd.auth_status_type = 'A' then 1 else 0 end as 'admin_denials',
		a.member_id

		--case when ''' + @db_name + ''' in (
		--			select distinct hc.db_name
		--			from niacore..health_carrier hc (nolock)
		--			join niacore..health_plan hp (nolock) on (hc.car_id = hp.car_id)
		--			where hp.funding_risk_type = 2) then ''Risk'' else ''ASO'' end,
		--ex.exam_cat_desc as 'actualmodality',
		--hp.line_of_business
			
INTO		#temp1

FROM	    niacombine.authorizations_nia a with (nolock) 
			join niacombine.auth_status_change_nia aschg WITH (NOLOCK) on (a.auth_id = aschg.auth_id and a.car_id = aschg.car_id)
            join niacore..auth_status_codes ascd WITH (NOLOCK) on (aschg.new_auth_status = ascd.auth_status)
				
------------------------------------------------ New UM Terminology ----------------
--			left join niacore..um_decision_codes d with (nolock) on (ascd.um_decision_code = d.um_decision_code)
--			left join niacore..um_process_codes pc with (nolock) on (ascd.um_process_code = pc.um_process_code)
--			left join niacore..benefit_determination_codes b with (nolock) on (ascd.benefit_determination_code = b.benefit_determination_code)
--			left join niacore..Customer_Determination_Codes cd with (nolock) on (ascd.customer_determination_code = cd.customer_determination_code)
--			left join niacore..Customer_Group_Determination_Codes cgd with (nolock) on (cd.customer_group_determination_code = cgd.customer_group_determination_code)
------------------------------------------------------------------------------------
            left outer join niacore..cases c (nolock) on (a.case_id = c.case_id)
			join niacore..auth_status_types d (nolock) on (ascd.auth_status_type = d.auth_status_type) 
			join niacore..auth_outcomes e (nolock) on (ascd.auth_outcome = e.auth_outcome) 
			left join niacore..is_users isu with (nolock) on (aschg.user_name = isu.log_id)
	        left join niacore..is_user_types iut with (nolock) on (isu.type = iut.user_type)
	
WHERE		ascd.final_status_flag = 1 
			and aschg.date_changed = (select max(aschg1.date_changed) 
                            from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
                            where aschg1.auth_id = a.auth_id and a.car_id = aschg1.car_id and 
                           exists (select 'true'
                                   from niacore..auth_status_codes ascd1 WITH (NOLOCK)
                                   where aschg1.new_auth_status = ascd1.auth_status and
                                                            aschg1.car_id = a.car_id and 
                                         ascd1.final_status_flag = 1) and
                                         aschg1.date_changed >= @start_date and 
                                         aschg1.date_changed < dateadd(dd, 1, @end_date)) 
			and aschg.date_changed >= @start_date
			and aschg.date_changed < dateadd(dd,1,@end_date) 
			and a.authorization_type_id in ('1','2','5','6')
			and ascd.auth_status <> 'cc'
			and iut.report_level = 'PCR'
			

--select count(*) from #temp1
--select distinct physician_fax from #temp where physician_fax like '%5070%' order by physician_fax
--select * from #temp1 where determination_date >= '12/30/2018'
---------------------------------------------------------------------------------------------------

--Get Member Info

SELECT  t.car_id,
		hc.car_name as 'plan_name',
		t.auth_id,
		t.authorization_type_id,
		t.combo_flag,
		t.new_auth_status,
		t.report_translation,
		t.recon_status_flag,
		t.determination_date,
		t.case_id,
		t.auth_status,
		t.cpt4_code,
		t.proc_desc,
		t.case_description,
		t.auth_outcome,
		t.auth_status_type,
		t.auth_status_type_description,
		t.outcome_description,
		t.radmd_volume,
		t.retro_claims_auths,
		t.month_year,
		t.quarter_year,
		t.week_in_year, 
		t.level_of_resolution, 
		t.reviewer_name,
		t.approvals, 
		t.clinical_denials, 
		t.admin_denials,
case	when hp.funding_risk_type = 2 then 'Risk' 
		when hp.funding_risk_type in ('5','6','7','8') then 'ASO Premium'
		else 'ASO' end as 'riskaso_flag',
		ex.exam_cat_desc as 'actualmodality',
		ex.cardiology_product_flag,
		hp.line_of_business

INTO		#temp2

FROM	    #temp1 t
			join niacombine.members_nia m WITH (NOLOCK) on (t.member_id = m.member_id and t.car_id = m.car_id)
            join niacore..health_plan hp WITH (NOLOCK) on (m.plan_id = hp.plan_id and m.car_id = hp.car_id)
            join niacore..health_carrier hc WITH (NOLOCK) on (t.car_id = hc.car_id)
            left outer join niacore..cpt4_codes cpt (nolock) on (t.cpt4_code = cpt.cpt4_code)
			left outer join niacore..exam_category ex (nolock) on (cpt.exam_cat_id = ex.exam_cat_id)

--drop table #temp2
--select * from #temp2 where recon_status_flag <> '0'
------------------------------------------------------------------------------------------------------------------------

-- PULL P2P ACTION CODES

SELECT	t.car_id,
		t.auth_id,
		'Yes' as 'P2P_held'

INTO	#temp_P2P

FROM	#temp2 t 
		join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
		
WHERE	aal.auth_action_code in ('17','969','970','1040')
		

GROUP BY	t.car_id,
			t.auth_id

--drop table #temp_P2P
---------------------------------------------------------------------------------------------------

SELECT      distinct t.car_id,
			t.auth_id,
			aschg.date_changed			as 'PCR_Recommendation_date',
			i.log_id					as 'PCR_log_id',
			iut.report_level			as 'PCR_level',
		   (i.lname + ', ' + i.fname)	as 'PCR_Recommendation_name',
		    i.is_user_id                as 'PCR_is_user_id'
			
INTO		#temp_PCR

FROM	    #temp2 t
            join ASDReportDB.niacombine.auth_status_change_nia	aschg	WITH (NOLOCK) on (t.auth_id = aschg.auth_id and t.car_id = aschg.car_id)
			join niacore..auth_status_codes	ascd WITH (NOLOCK) on (aschg.new_auth_status = ascd.auth_status)
			left join niacore..is_users	i WITH (NOLOCK) on (aschg.user_name = i.log_id )
			join niacore..is_user_types	iut	WITH (NOLOCK) on (i.type = iut.user_type)
			
WHERE		aschg.new_auth_status in ('ac','de')
			and aschg.date_changed = (select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
									   where aschg1.auth_id = t.auth_id and aschg1.car_id = t.car_id 
										 and aschg1.new_auth_status in ('ac','de'))


-----------------------------------------------------------------------------------------------------------------

SELECT DISTINCT  t.car_id,
			t.auth_id,
		    aal.auth_action_code as 'PCR_Action_112'
			
INTO		#temp_action_112

FROM	    #temp2 t
			join ASDReportDB.niacombine.auth_action_log_nia aal with (nolock) on (t.car_id = aal.car_id and t.auth_id = aal.auth_id)
						
WHERE		aal.auth_action_code in ('112')
			and aal.date_entered = (select max(aal1.date_entered) 
									  from ASDReportDB.niacombine.auth_action_log_nia aal1 WITH (NOLOCK)
									 where aal1.auth_id = t.auth_id and aal1.car_id = t.car_id 
									   and aal1.auth_action_code in ('112'))

-----------------------------------------------------------------------------------------------------------------

-- PULL LACK OF CLINICAL ACTION CODES

SELECT	t.car_id,
		t.auth_id,
		'Yes' as 'denied_lack_clinical'

INTO	#temp_loc

FROM	#temp2 t 
		join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
		
WHERE	aal.auth_action_code in ('20')
		

GROUP BY	t.car_id,
			t.auth_id

--drop table #temp_loc
---------------------------------------------------------------------------------------------------
--  Get info from temp tables

SELECT      t.*,
	case    when tp.P2P_held = 'Yes' then 1 else 0 end as 'P2P_count',
	case	when ta.auth_id is not null and pcr.auth_id is not null 
			then pcr.PCR_level 			
			else t.level_of_resolution
			end as 'level_of_resolution2',  
	case	
			when ta.auth_id is not null and pcr.auth_id is not null 
			then pcr.PCR_Recommendation_name 
			else t.reviewer_name
			end as 'pcr_name',
	case    when loc.denied_lack_clinical is NULL then 'No' else 'Yes' end as 'denied_LOC',
	case    when t.recon_status_flag = '1' then 'Yes' else 'No' end as 'RRR_flag',
	case    when tp.P2P_held = 'Yes' then 'Yes' else 'No' end as 'P2P_held',
	case    when t.authorization_type_id = '5' then 'IPM' 
			when t.authorization_type_id = '6' then 'Surgery'
			when t.authorization_type_id = '16' then 'Physical Medicine'
			when t.cardiology_product_flag = '1' then 'Cardiac'
			else 'RBM' end as 'procedure_group',
	case    when t.week_in_year = '53' then '1' else t.week_in_year end as 'week_in_year_2'

INTO		#temp3

FROM	    #temp2 t
			left join #temp_PCR	pcr with (nolock) on (t.car_id = pcr.car_id and t.auth_id = pcr.auth_id)
			left join #temp_action_112 ta	with (nolock) on (t.car_id = ta.car_id	and t.auth_id = ta.auth_id)
			left join #temp_P2P tp with (nolock) on (t.car_id = tp.car_id and t.auth_id = tp.auth_id)
			left join #temp_loc loc with (nolock) on (t.car_id = loc.car_id and t.auth_id = loc.auth_id)


--select * from #temp3 where level_of_resolution2 <> 'PCR'
--select * from #temp_PCR where car_id = 55 and auth_id in ('N18041700102','N18051400264','N17101200082','N17112800349','N17082200415')
--select * from #temp_action_112 where car_id = 55 and auth_id in ('N18041700102','N18051400264','N17101200082','N17112800349','N17082200415')
--select distinct P2P_held from #temp3
--drop table #temp3
---------------------------------------------------------------------------------------------------
-- Get auth counts by procedure

SELECT	t.procedure_group, 
		t.proc_desc, 
		count(*) as 'auth_count' 

INTO	#temp_totals
		
FROM	#temp3 t

GROUP BY	t.procedure_group, 
			t.proc_desc  

--drop table #temp_totals
---------------------------------------------------------------------------------------------------
-- Order the procedures by procedure group and volume

SELECT	t.procedure_group,
		t.proc_desc,
		t.auth_count,
		seq = ROW_NUMBER() OVER(Partition BY t.procedure_group ORDER BY t.procedure_group, t.auth_count desc)

INTO	#temp_ordered

FROM	#temp_totals t

--select * from #temp_ordered order by procedure_group, seq
--drop table #temp_ordered
---------------------------------------------------------------------------------------------------
-- Add the sequence to the table

SELECT	t.*,
		tor.seq

INTO	#temp4

FROM	#temp3 t
		join #temp_ordered tor with (nolock) on (t.procedure_group = tor.procedure_group and t.proc_desc = tor.proc_desc)

--select * from #temp5
--drop table #temp5
---------------------------------------------------------------------------------------------------

SELECT	pcr_name, 
		approvals = sum(approvals),
		clinical_denials = sum(clinical_denials),
		admin_denials = sum(admin_denials),
		P2P_count = sum(P2P_count),
		auth_count = count(auth_id),
		week_in_year_2,
		--product_group = case when actualmodality in ('Cardiac Catheterization', 'CCTA (Coronary Computed Tomography Angiography)',
		--					'Echocardiography', 'Nuclear Cardiology', 'Stress Echocardiography')
		--			then 'Cardiac'
		--			when actualmodality in ('Peripheral Vascular Ultrasound', 'Ultrasound General')
		--			then 'Primary'
		--			when actualmodality in ('CT (Computed Tomography)','CTA (Computed Tomography Angiography)',
		--					'MRA (Magnetic Resonance Angiography)','MRI (Magnetic Resonance Imaging)','PET (Positron Emission Tomography)')
		--			then 'Advanced'
		--			when actualmodality = 'Other' and cpt4_code in ('94660','95811')
		--			then 'Sleep Management'
		--			else 'Other'
		--			end,
		product_group = t.procedure_group,
		modality = actualmodality,
case    when (t.procedure_group = 'Cardiac' and t.seq <= 12) then t.proc_desc 
		when  t.procedure_group = 'Cardiac' then 'All Other Cardiac' 
		when (t.procedure_group = 'IPM' and t.seq <= 9) then t.proc_desc 
		when  t.procedure_group = 'IPM' then 'All Other IPM'
		when (t.procedure_group = 'RBM' and t.seq <= 30) then t.proc_desc 
		when  t.procedure_group = 'RBM' then 'All Other RBM'
		when (t.procedure_group = 'Surgery' and t.seq <= 12) then t.proc_desc 
		when  t.procedure_group = 'Surgery' then 'All Other Surgery'
		when  t.procedure_group = 'Physical Medicine' then t.proc_desc
		else 'Other' end as 'proc_desc',
		combo_flag,
		riskaso_flag,
case    when line_of_business = 'OT' then 'CO' else line_of_business end as 'line_of_business',
		plan_name,
		denied_LOC,
		RRR_flag,
		P2P_held
		--denial_status = case when auth_outcome = 'A' then 'Not a Denial' else report_translation end

INTO	adhoc.dbo.PCR_weekly_data

FROM	#temp4 t

WHERE	level_of_resolution2 = 'PCR'

GROUP BY	pcr_name, 
			week_in_year_2,
			t.procedure_group,
			actualmodality,
	case    when (t.procedure_group = 'Cardiac' and t.seq <= 12) then t.proc_desc 
			when  t.procedure_group = 'Cardiac' then 'All Other Cardiac' 
			when (t.procedure_group = 'IPM' and t.seq <= 9) then t.proc_desc 
			when  t.procedure_group = 'IPM' then 'All Other IPM'
			when (t.procedure_group = 'RBM' and t.seq <= 30) then t.proc_desc 
			when  t.procedure_group = 'RBM' then 'All Other RBM'
			when (t.procedure_group = 'Surgery' and t.seq <= 12) then t.proc_desc 
			when  t.procedure_group = 'Surgery' then 'All Other Surgery'
			when  t.procedure_group = 'Physical Medicine' then t.proc_desc
			else 'Other' end,
			combo_flag,
			riskaso_flag,
	case    when line_of_business = 'OT' then 'CO' else line_of_business end,
			plan_name,
			denied_LOC,
			RRR_flag,
			P2P_held
	--case	when auth_outcome = 'A' then 'Not a Denial' else report_translation end


---------------------------------------------------------------------------------------------------

SELECT		*

FROM		adhoc.dbo.PCR_weekly_data

-- (232855 row(s) affected) - 6/24/19