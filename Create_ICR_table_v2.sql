/*************************************************************************************************************************
* Requested By:			Ed Wilson and Sheri Tonioli-Gross
* Request Due Date:		05/12/17
* Request Received:		04/27/17
* Created By:			Michelle Boggs
* Create Date:			05/02/17
* Last Modified Date:	
* Last Modified By:		
* Adhoc #:				 
* Report Name:			ICR Volume
* Report Description:	All Carriers
*						Per Ed Wilson
*
*						-  Select only finalized cases
*						-  Only count unique cases where an ICR enters one of the following status_codes:
*							ICR Approved
*							Clinical Pend
*							MD Review
*						-  The first ICR to enter one of the codes above gets counted for the case.
*						-  Rolling 12 weeks of data (Sunday through Saturday)
*************************************************************************************************************************/

USE  ASDReportDB

DROP TABLE  #temp1
DROP TABLE  #temp2
DROP TABLE  #temp3
DROP TABLE  #temp4
DROP TABLE	#temp5
DROP TABLE  #temp_status
DROP TABLE  #temp_status2


DECLARE		@start_date datetime,
			@end_date datetime

SET			@start_date = '01/09/2022'      --This should be the last 12 weeks (Sunday - Saturday) increase two weeks
SET			@end_date	= '04/02/2022'


---------------------------------------------------------------------------------------------------

SELECT	a.car_id,
--      hp.car_name as 'plan_name'
		a.auth_id,
		a.combo_flag,
		aschg.new_auth_status,
		ascd.report_translation,
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
			and a.authorization_type_id in ('1','2')
			

--select count(*) from #temp1
--select distinct physician_fax from #temp where physician_fax like '%5070%' order by physician_fax
--select * from #temp1
---------------------------------------------------------------------------------------------------

--Get Member Info

SELECT  t.car_id,
		hc.car_name as 'plan_name',
case    when hp.line_of_business = 'OT' then 'CO' else hp.line_of_business end as 'line_of_business',
case	when hp.funding_risk_type = 2 then 'Risk' 
		when hp.funding_risk_type in ('5','6','7','8') then 'ASO Premium'
		else 'ASO' end as 'riskaso_flag',
		t.auth_id,
		t.combo_flag,
		t.new_auth_status,
		t.report_translation,
		t.determination_date,
		t.case_id,
		t.auth_status,
		t.cpt4_code,
		t.proc_desc,
		t.case_description,
		ex.exam_cat_desc as 'actualmodality',
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
		t.approvals, 
		t.clinical_denials, 
		t.admin_denials

INTO		#temp2

FROM	    #temp1 t
			join niacombine.members_nia m WITH (NOLOCK) on (t.member_id = m.member_id and t.car_id = m.car_id)
            join niacore..health_plan hp WITH (NOLOCK) on (m.plan_id = hp.plan_id and m.car_id = hp.car_id)
            join niacore..health_carrier hc WITH (NOLOCK) on (t.car_id = hc.car_id)
            left outer join niacore..cpt4_codes cpt (nolock) on (t.cpt4_code = cpt.cpt4_code)
			left outer join niacore..exam_category ex (nolock) on (cpt.exam_cat_id = ex.exam_cat_id)

--drop table #temp2
--select count(*) from #temp2
------------------------------------------------------------------------------------------------------------------------

-- PULL FIRST STATUS CODE ENTERED BY ICR


SELECT      t.car_id,
			t.auth_id,
			min(asch.date_changed) as 'min_status_date'
			
INTO		#temp_status

FROM	    #temp2 t
			join ASDReportDB.niacombine.auth_status_change_nia asch WITH (NOLOCK) on (t.car_id = asch.car_id and t.auth_id = asch.auth_id)
			join niacore..is_users iu WITH (NOLOCK) on (asch.user_name = iu.log_id)

WHERE		iu.type in ('ur')
       and  asch.new_auth_status in ('ra','mr')

GROUP BY    t.car_id,
            t.auth_id		
				      
--select distinct t.car_id, t.auth_id from #temp_status t 
--select * from #temp_P2P where car_id = 14 and auth_id in ('16159C024','16118C207','16025C155','16008C033')
----------------------------------------------------------------------------------------------------------------

-- GET USER AND STATUS INFO FROM AUTH_STATUS_CHANGE

SELECT      t.car_id,
			t.auth_id,
			t.min_status_date,
			ascd.status_desc as 'status_entered',
		   (upper(iu.lname) + ', ' + upper(iu.fname)) as 'ICR_name'
					
INTO		#temp_status2

FROM	    #temp_status t
			join ASDReportDB.niacombine.auth_status_change_nia asch WITH (NOLOCK) on (t.car_id = asch.car_id and t.auth_id = asch.auth_id)
			join niacore..auth_status_codes ascd WITH (NOLOCK) on (asch.new_auth_status = ascd.auth_status)
			join niacore..is_users iu WITH (NOLOCK) on (asch.user_name = iu.log_id)

WHERE		iu.type in ('ur')
       and  t.min_status_date = asch.date_changed

	
--select * from #temp_status2 where auth_id = '170461883'
--select distinct status_entered from #temp_status2

---------------------------------------------------------------------------------------------------

-- PULL CVR REQUIRED ACTION CODES

SELECT	t.car_id,
		t.auth_id,
		'Yes' as 'CVR_required'

INTO	#temp_CVR_req

FROM	#temp2 t 
		join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
		
WHERE	aal.auth_action_code in ('711')

GROUP BY	t.car_id,
			t.auth_id

--drop table #temp_CVR_req
---------------------------------------------------------------------------------------------------
--  Get info from temp tables

SELECT      t.*,
case        when tc.CVR_required is NULL then 'No' else tc.CVR_required end as 'CVR_required',
			ts2.status_entered,
			ts2.ICR_name,
case		when ts2.status_entered = 'ICR Approved' then 1 else 0 end as 'ICR_approved',
case		when ts2.status_entered = 'MD Rev' then 1 else 0 end as 'MD_rev'
--case		when ts2.status_entered = 'Clinical Pend' then 1 else 0 end as 'Clinical_pend'

INTO		#temp3

FROM	    #temp2 t
			join #temp_status2 ts2 with (nolock) on (t.car_id = ts2.car_id and t.auth_id = ts2.auth_id)
			left join #temp_CVR_req tc with (nolock) on (t.car_id = tc.car_id and t.auth_id = tc.auth_id)

--select * from #temp3
--drop table #temp3
---------------------------------------------------------------------------------------------------

--  Add flag for MD Denial

SELECT      t.*,		
case        when (t.status_entered = 'MD Rev' and t.outcome_description = 'Disapproval') then 1 else 0 end as 'MD_denial'

INTO		#temp4

FROM	    #temp3 t
			
--select * from #temp4 where week_in_year = '20' and ICR_name in ('STOWERS, BRIAN','JONES, MINERVA2','MCLAURIN, JILL','AVERY, ANN')

--drop table #temp4
--select distinct plan_name from #temp4 order by plan_name
--select * from #temp4 where status_entered = 'MD Rev' and outcome_description = 'Approval' and proc_desc = 'Cervical Spine MRI' and plan_name in ('Blue Shield of California','Florida Blue')
---------------------------------------------------------------------------------------------------

DROP TABLE	adhoc.dbo.ICR_data_weekly

SELECT		ICR_name, 
			ICR_approved = sum(ICR_approved),
			MD_rev = sum(MD_rev),
			MD_denial = sum(MD_denial),
			--Clinical_pend = sum(Clinical_pend),
			auth_count = count(auth_id),
	case    when week_in_year = '53' then '1' else week_in_year end as 'month_year',
			product_group = case when actualmodality in ('Cardiac Catheterization', 'CCTA (Coronary Computed Tomography Angiography)',
							'Echocardiography', 'Nuclear Cardiology', 'Stress Echocardiography')
					then 'Cardiac'
			when actualmodality in ('Peripheral Vascular Ultrasound', 'Ultrasound General')
					then 'Primary'
			when actualmodality in ('CT (Computed Tomography)','CTA (Computed Tomography Angiography)',
							'MRA (Magnetic Resonance Angiography)','MRI (Magnetic Resonance Imaging)','PET (Positron Emission Tomography)')
					then 'Advanced'
			when actualmodality = 'Other' and proc_desc = 'Sleep study, attended'
					then 'Sleep Management'
			else 'Other' end,
		modality = actualmodality,
		proc_desc,
		riskaso_flag,
		plan_name,
		combo_flag,
		line_of_business,
		CVR_required
	
INTO	adhoc.dbo.ICR_data_weekly
	
FROM	#temp4

GROUP BY	ICR_name, 
case		when week_in_year = '53' then '1' else week_in_year end,
case		when actualmodality in ('Cardiac Catheterization', 'CCTA (Coronary Computed Tomography Angiography)',
							'Echocardiography', 'Nuclear Cardiology', 'Stress Echocardiography')
					then 'Cardiac'
			when actualmodality in ('Peripheral Vascular Ultrasound', 'Ultrasound General')
					then 'Primary'
			when actualmodality in ('CT (Computed Tomography)','CTA (Computed Tomography Angiography)',
							'MRA (Magnetic Resonance Angiography)','MRI (Magnetic Resonance Imaging)','PET (Positron Emission Tomography)')
					then 'Advanced'
			when actualmodality = 'Other' and proc_desc = 'Sleep study, attended'
					then 'Sleep Management'
			else 'Other' end,
		actualmodality,
		proc_desc,
		riskaso_flag,
		plan_name, 
		combo_flag,
		line_of_business,
		CVR_required

---------------------------------------------------------------------------------------------------

SELECT	*

FROM	adhoc.dbo.ICR_data_weekly

--=================================================================================================================

--extract auth_ids for Brain MRI only for Bionca

--DROP TABLE	#ICR_data_weekly_With_authIDs

--SELECT		ICR_name, 
--			ICR_approved = sum(ICR_approved),
--			MD_rev = sum(MD_rev),
--			MD_denial = sum(MD_denial),
--			--Clinical_pend = sum(Clinical_pend),
--			--auth_count = count(auth_id),
--			auth_id,
--	case    when week_in_year = '53' then '1' else week_in_year end as 'month_year',
--			product_group = case when actualmodality in ('Cardiac Catheterization', 'CCTA (Coronary Computed Tomography Angiography)',
--							'Echocardiography', 'Nuclear Cardiology', 'Stress Echocardiography')
--					then 'Cardiac'
--			when actualmodality in ('Peripheral Vascular Ultrasound', 'Ultrasound General')
--					then 'Primary'
--			when actualmodality in ('CT (Computed Tomography)','CTA (Computed Tomography Angiography)',
--							'MRA (Magnetic Resonance Angiography)','MRI (Magnetic Resonance Imaging)','PET (Positron Emission Tomography)')
--					then 'Advanced'
--			when actualmodality = 'Other' and proc_desc = 'Sleep study, attended'
--					then 'Sleep Management'
--			else 'Other' end,
--		modality = actualmodality,
--		proc_desc,
--		riskaso_flag,
--		plan_name,
--		combo_flag,
--		line_of_business,
--		CVR_required
	
--INTO	#ICR_data_weekly_With_authIDs
	
--FROM	#temp4
--where proc_desc = 'Brain MRI'

--GROUP BY	ICR_name, auth_id,
--case		when week_in_year = '53' then '1' else week_in_year end,
--case		when actualmodality in ('Cardiac Catheterization', 'CCTA (Coronary Computed Tomography Angiography)',
--							'Echocardiography', 'Nuclear Cardiology', 'Stress Echocardiography')
--					then 'Cardiac'
--			when actualmodality in ('Peripheral Vascular Ultrasound', 'Ultrasound General')
--					then 'Primary'
--			when actualmodality in ('CT (Computed Tomography)','CTA (Computed Tomography Angiography)',
--							'MRA (Magnetic Resonance Angiography)','MRI (Magnetic Resonance Imaging)','PET (Positron Emission Tomography)')
--					then 'Advanced'
--			when actualmodality = 'Other' and proc_desc = 'Sleep study, attended'
--					then 'Sleep Management'
--			else 'Other' end,
--		actualmodality,
--		proc_desc,
--		riskaso_flag,
--		plan_name, 
--		combo_flag,
--		line_of_business,
--		CVR_required
---- (39924 row(s) affected) 3/15/20
-----------------------------------------------------------------------------------------------------

--SELECT	*

--FROM	#ICR_data_weekly_With_authIDs