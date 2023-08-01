/*************************************************************************************************************************
* Requested By:			Bruce Heck
* Request Due Date:		08/25/18
* Request Received:		08/20/18
* Created By:			Michelle Boggs
* Create Date:			08/20/18
* Last Modified Date:	2/25/21
* Last Modified By:		Jim McLaughlin
* Adhoc #:				SCTASK0266620
* Report Name:			Escalation
* Report Description:	All Carriers
*						Determine the percentage of cases escalated to a PCR.  Is it because of AI, ICR Bypass, or escalated 
*						by an ICR.
*						Filter by Funding tpye, LOB, Modality and Study
*						
*************************************************************************************************************************/

USE  ASDReportDB

DROP TABLE  #temp1
DROP TABLE  #temp2
DROP TABLE  #temp3
DROP TABLE  #temp_bypass
DROP TABLE  #temp_denials
DROP TABLE  #temp_approval
DROP TABLE  #temp_max_subs
DROP TABLE  #temp_approval_2
DROP Table #temp_action
DROP Table #temp_status
DROP table #temp_first_rev
DROP table #temp_info
DROP table #temp_P2P
DROP table #temp_PCR
DROP table #temp_action_112
DROP table #temp_ICR_scored
DROP table #temp_PCR_scored
DROP table #temp_sent_AI
DROP table #temp_loc
DROP table #temp_boaa
Drop table #temp_boe
DROP table #temp_appeal
DROP table #temp_appeal_outcome
DROP table #temp_initial
DROP table #temp_recur
DROP table #temp4
DROP table #temp_recur_2
DROP table #temp_recur_final
DROP table #temp5
DROP table #temp6
DROP table #temp_totals
DROP table #temp7
DROP table #temp_ordered
DROP table #temp_totals_case
DROP table #temp_ordered_case
DROP table #temp7b
DROP table #temp7c
DROP table #temp8

DECLARE		@call_start_date datetime,
			@start_date datetime,
			@end_date datetime

SET			@call_start_date =	'10/01/2017'  ---JFM ---Change this to start - 15 or 27 months...need to validate
SET			@start_date =		'01/01/2028'    ---JFM ---Change this to start - 12 or 24 months...need to validate
SET			@end_date	=		'02/28/2021'-- Change the end_date to the last day of the previous month.


---------------------------------------------------------------------------------------------------
--  Get auths with date call received between data range.  Don't worry about final determination yet.

SELECT      a.car_id,
			a.auth_id,
			a.authorization_type_id,
			a.combo_flag,
			a.expedite_flag,
			a.proc_desc,
	case	when a.cpt4_code in ('78451','78452','78453','78454') then 'Myocardial Perfusion Imaging' 
			when a.proc_desc like '% - %' then LEFT(a.proc_desc,charindex('-',a.proc_desc,0)-2)
            when a.proc_desc like '% (%)' then LEFT(a.proc_desc,charindex('(',a.proc_desc,0)-2)
            when a.proc_desc like '%(%' then LEFT(a.proc_desc,charindex('(',a.proc_desc,0)-1)
            else a.proc_desc end as 'proc_desc_rollup',
			a.cpt4_code,
			a.date_call_rcvd,
			a.member_id,
			a.phys_id,
			'call_start_date' = @call_start_date,
			'start_date' = @start_date,
			'end_date' = @end_date,
			ads.data as 'case_id_2',
			Algorithm_Approved_Count = Case when (a.case_outcome like 'Approve%' and a.case_outcome not like '%disapprov%' 
										and a.case_outcome not like '%bypass%' and a.case_outcome not like '%no case%'
										and a.case_outcome not like '%Automatic Authorization%') 
											then 1 else 0 end,
			Algorithm_Disapproved_Count = Case when (a.case_outcome like 'Disapprove%' and a.case_outcome not like '%bypass%' and a.case_outcome not like '%no case%') 
											then 1 else 0 end,
			Algorithm_Unknown_Count = Case when (a.case_outcome like 'Approve%' and a.case_outcome not like '%disapprov%' 
										and a.case_outcome not like '%bypass%' and a.case_outcome not like '%no case%'
										and a.case_outcome not like '%Automatic Authorization%') 
											then 0 
										when (a.case_outcome like 'Disapprove%' and a.case_outcome not like '%bypass%' and a.case_outcome not like '%no case%') 
											then 0
											else 1 end

			
INTO		#temp1

FROM	    niacombine.authorizations_nia a with (nolock) 
			left join ASDReportDB.niacombine.authorization_data_supplemental_nia ads with(nolock) on (a.car_id = ads.car_id and a.auth_id = ads.auth_id and ads.data_type_id = 218)
			
WHERE		a.date_call_rcvd >= @call_start_date
		and a.date_call_rcvd < dateadd(dd,1,@end_date) 
		and a.authorization_type_id in ('1','2','5','6')
		
--select proc_desc, count(*) from #temp1 group by proc_desc order by count(*) desc
--select distinct physician_fax from #temp where physician_fax like '%5070%' order by physician_fax
--select distinct outcome_category from #temp1

---------------------------------------------------------------------------------------------------
-- Get cases with a final determination

SELECT      a.car_id,
			a.auth_id,
			a.authorization_type_id,
			a.combo_flag,
			a.expedite_flag,
	case	when a.cpt4_code in ('78451','78452','78453','78454') then 'Myocardial Perfusion Imaging' 
			when a.proc_desc like '% - %' then LEFT(a.proc_desc,charindex('-',a.proc_desc,0)-2)
            when a.proc_desc like '% (%)' then LEFT(a.proc_desc,charindex('(',a.proc_desc,0)-2)
            when a.proc_desc like '%(%' then LEFT(a.proc_desc,charindex('(',a.proc_desc,0)-1)
            else a.proc_desc end as 'proc_desc',
			a.cpt4_code,
			a.date_call_rcvd,
			aschg.date_changed as 'final_determination_date',
			ascd.report_translation,
			ascd.status_desc,

---------------------------------------------- New UM Terminology --------------
	case
			when cd.customer_group_determination_code in ('1','5')	then 'Certified'
			when cd.customer_group_determination_code in ('2','6')	then 'Non-Certified'
			when cd.customer_group_determination_code = '3'			then 'Administrative Non-Certified'
			when cd.customer_group_determination_code = '4'			then 'Inactivated by Ordering Provider'
			when cd.customer_group_determination_code in ('7','8')	then 'Partial Determination'
			else 'Other'
	end as 'final_determination',
	case when ascd.auth_outcome <> 'A' and ascd.auth_status_type in ('C','R') then 'Clinical Denial'
			when ascd.auth_outcome <> 'A' and ascd.auth_status_type = 'A' then 'Admin Denial'
			when ascd.auth_outcome = 'A' then 'Approval'
			else null
			end as 'outcome_category',
			ascd.recon_status_flag,
			iut.report_level as 'level_of_determination',
			a.member_id,
			t.call_start_date,
			t.start_date,
			t.end_date,
			t.case_id_2,
			t.Algorithm_Approved_Count,
			t.Algorithm_Disapproved_Count,
			t.Algorithm_Unknown_Count
			
INTO		#temp2

FROM		#temp1 t
			join niacombine.authorizations_nia a with (nolock) on (t.car_id = a.car_id and t.auth_id = a.auth_id)
			join niacombine.auth_status_change_nia aschg WITH (NOLOCK) on (a.auth_id = aschg.auth_id AND A.CAR_ID = ASCHG.CAR_ID)
            join niacore..auth_status_codes ascd WITH (NOLOCK) on (aschg.new_auth_status = ascd.auth_status)
            join niacombine.physicians_nia p with (NOLOCK) on (a.phys_id = p.phys_id and a.car_id = p.car_id)
            left join niacore..specialties sp with (NOLOCK) on (p.spec_id = sp.spec_id)
            --join nirad..facilities f with (NOLOCK) on (f.fac_id = a.fac_id)
				
---------------------------------------------- New UM Terminology ----------------
			left join niacore..um_decision_codes d with (nolock) on (ascd.um_decision_code = d.um_decision_code)
			left join niacore..um_process_codes pc with (nolock) on (ascd.um_process_code = pc.um_process_code)
			left join niacore..benefit_determination_codes b with (nolock) on (ascd.benefit_determination_code = b.benefit_determination_code)
			left join niacore..Customer_Determination_Codes cd with (nolock) on (ascd.customer_determination_code = cd.customer_determination_code)
			left join niacore..Customer_Group_Determination_Codes cgd with (nolock) on (cd.customer_group_determination_code = cgd.customer_group_determination_code)
----------------------------------------------------------------------------------
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
                                         aschg1.date_changed >= t.call_start_date and 
                                         aschg1.date_changed < dateadd(dd, 1, t.end_date)) 
			and aschg.date_changed >= t.call_start_date
			and aschg.date_changed < dateadd(dd,1,t.end_date) 
			
--drop table #temp2
---------------------------------------------------------------------------------------------------

--Get Member Info

SELECT      t.car_id,
			hc.car_name,
			hp.line_of_business,
			hp.funding_risk_type,
			t.auth_id,
			t.authorization_type_id,
			t.combo_flag,
			t.expedite_flag,
			t.proc_desc,
			t.cpt4_code,
			ec.exam_cat_desc,
			ec.short_desc,
			ec.cardiology_product_flag,
			t.date_call_rcvd,
			t.final_determination_date, 
			t.report_translation,
			t.status_desc,
			t.final_determination,
			t.outcome_category,
			t.recon_status_flag,
			t.level_of_determination,
			t.member_id,
			t.call_start_date,
			t.start_date,
			t.end_date,
			t.case_id_2,
			t.Algorithm_Approved_Count,
			t.Algorithm_Disapproved_Count,
			t.Algorithm_Unknown_Count

INTO		#temp3

FROM	    #temp2 t
			join niacombine.members_nia m WITH (NOLOCK) on (t.member_id = m.member_id and t.car_id = m.car_id)
            join niacore..health_plan hp WITH (NOLOCK) on (m.plan_id = hp.plan_id and m.car_id = hp.car_id)
            join niacore..health_carrier hc WITH (NOLOCK) on (t.car_id = hc.car_id)
			left join niacore..cpt4_codes cpt WITH (NOLOCK) on (t.cpt4_code = cpt.cpt4_code) 
            left join niacore..exam_category ec WITH (NOLOCK) on (cpt.exam_cat_id = ec.exam_cat_id) 

            
--WHERE		hp.line_of_business <> 'MC'

--select * from #temp3
------------------------------------------------------------------------------------------------------------------------
-- Get ICR/PCR Actions

SELECT      t.car_id,
			t.auth_id,
			MAX(case when iu.type = 'ur' then 1 else 0 end) as 'ICR_action', 
			MAX(case when iu.type = 'md' then 1 else 0 end) as 'PCR_action'
			
INTO		#temp_action

FROM	    #temp3 t
			join ASDReportDB.niacombine.auth_action_log_nia aal WITH (NOLOCK) on (t.car_id = aal.car_id and t.auth_id = aal.auth_id)
			join niacore..is_users iu WITH (NOLOCK) on (aal.is_user_id = iu.is_user_id)

WHERE		iu.type in ('ur','md')
		and aal.auth_action_code <> '847'

GROUP BY    t.car_id,
            t.auth_id
 
---------------------------------------------------------------------------------------------------
-- Get ICR/PCR Status

SELECT      t.car_id,
			t.auth_id,
			MAX(case when iu.type = 'ur' then 1 else 0 end) as 'ICR_status', 
			MAX(case when iu.type = 'md' then 1 else 0 end) as 'PCR_status'
			
INTO		#temp_status

FROM	    #temp3 t
			join ASDReportDB.niacombine.auth_status_change_nia asch WITH (NOLOCK) on (t.car_id = asch.car_id and t.auth_id = asch.auth_id)
			join niacore..is_users iu WITH (NOLOCK) on (asch.user_name = iu.log_id)

WHERE		iu.type = 'md'
		or (iu.type = 'ur' and asch.new_auth_status NOT IN ('mr','co'))

GROUP BY    t.car_id,
            t.auth_id
 
---------------------------------------------------------------------------------------------------

-- PULL ICR BYPASS ACTION CODES

SELECT	t.car_id,
		t.auth_id,
		'Yes' as 'ICR_bypass'

INTO	#temp_bypass

FROM	#temp3 t 
		join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
		
WHERE	aal.auth_action_code in ('1429')
		

GROUP BY	t.car_id,
			t.auth_id
---------------------------------------------------------------------------------------------------

-- Get MD review code

SELECT      t.car_id,
			t.auth_id,
			MIN(asch.date_changed) as 'md_rev_date'
			
INTO		#temp_first_rev

FROM	    #temp3 t
			join ASDReportDB.niacombine.auth_status_change_nia asch WITH (NOLOCK) on (t.car_id = asch.car_id and t.auth_id = asch.auth_id)
			join niacore..is_users iu WITH (NOLOCK) on (asch.user_name = iu.log_id)

WHERE		asch.new_auth_status = 'mr'
        and iu.type = 'ur'

GROUP BY    t.car_id,
            t.auth_id
 
 --select count(*) from #temp_first_status
 --drop table #temp_first_rev
---------------------------------------------------------------------------------------------------

-- PULL CLINICAL INFO ACTION CODES FOR FAX OR UPLOAD

SELECT	t.car_id,
		t.auth_id,
		'Yes' as 'addl_clinical_received'

INTO	#temp_info

FROM	#temp3 t 
		join #temp_first_rev tfr with (nolock) on (t.car_id = tfr.car_id and t.auth_id = tfr.auth_id)
		join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
		
WHERE	aal.auth_action_code in ('7','264','265','340','454','489','829','963','1100','1101','1129','756','757','758','759','760','761')
   and  aal.date_entered >= tfr.md_rev_date and aal.date_entered <= t.final_determination_date
		
GROUP BY	t.car_id,
			t.auth_id

--drop table #temp_info
---------------------------------------------------------------------------------------------------

-- PULL P2P ACTION CODES  (New list of codes to indicate a P2P occurred received from Karen Froyum on 11/7/19)
-- 11/19/19 - It was decided to only to use clinician to clinician codes.  Don't use codes that only indicate a contact was established.

SELECT	t.car_id,
		t.auth_id,
		'Yes' as 'P2P_held'

INTO	#temp_P2P

FROM	#temp3 t 
		join #temp_first_rev tfr with (nolock) on (t.car_id = tfr.car_id and t.auth_id = tfr.auth_id)
		join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
		
--WHERE	aal.auth_action_code in ('15','17','18','199','361','969','1040','1558')
WHERE	aal.auth_action_code in ('17','969','1040','1558')
   and  aal.date_entered >= tfr.md_rev_date and aal.date_entered <= t.final_determination_date	

GROUP BY	t.car_id,
			t.auth_id

--drop table #temp_p2p
---------------------------------------------------------------------------------------------------

SELECT      distinct t.car_id,
			t.auth_id,
			aschg.date_changed			as 'PCR_Recommendation_date',
			i.log_id					as 'PCR_log_id',
			iut.report_level			as 'PCR_level',
		   (i.lname + ', ' + i.fname)	as 'PCR_Recommendation_name',
		    i.is_user_id                as 'PCR_is_user_id'
			
INTO		#temp_PCR

FROM	    #temp3 t
            join ASDReportDB.niacombine.auth_status_change_nia	aschg	WITH (NOLOCK) on (t.auth_id = aschg.auth_id and t.car_id = aschg.car_id)
			join niacore..auth_status_codes	ascd WITH (NOLOCK) on (aschg.new_auth_status = ascd.auth_status)
			left join niacore..is_users	i WITH (NOLOCK) on (aschg.user_name = i.log_id )
			join niacore..is_user_types	iut	WITH (NOLOCK) on (i.type = iut.user_type)
			
WHERE		aschg.new_auth_status in ('ac','de')
			and aschg.date_changed = (select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
									   where aschg1.auth_id = t.auth_id and aschg1.car_id = t.car_id 
										 and aschg1.new_auth_status in ('ac','de'))
			--and iut.report_level = 'PCR'  --added jfm test to see if numbers improve


-----------------------------------------------------------------------------------------------------------------

SELECT DISTINCT  t.car_id,
			t.auth_id,
		    aal.auth_action_code as 'PCR_Action_112'
			
INTO		#temp_action_112

FROM	    #temp3 t
			join ASDReportDB.niacombine.auth_action_log_nia aal with (nolock) on (t.car_id = aal.car_id and t.auth_id = aal.auth_id)
						
WHERE		aal.auth_action_code in ('112')
			and aal.date_entered = (select max(aal1.date_entered) 
									  from ASDReportDB.niacombine.auth_action_log_nia aal1 WITH (NOLOCK)
									 where aal1.auth_id = t.auth_id and aal1.car_id = t.car_id 
									   and aal1.auth_action_code in ('112'))

-----------------------------------------------------------------------------------------------------------------
-- Get ICR Scored cases (added action code 1276 for Hindsait history)

SELECT      t.car_id,
			t.auth_id,
			MAX(aal.date_action) as 'ICR_scored'
			
INTO		#temp_ICR_scored

FROM	    #temp3 t
			join ASDReportDB.niacombine.auth_action_log_nia aal WITH (NOLOCK) on (t.car_id = aal.car_id and t.auth_id = aal.auth_id)
			
WHERE		aal.auth_action_code in ('1536','1276')

GROUP BY    t.car_id,
            t.auth_id
 
 --drop table #temp_PCR_scored
 --select distinct car_id from #temp_PCR_scored order by car_id
---------------------------------------------------------------------------------------------------
-- Get PCR Scored cases (added action code 1277 and 1278 for Hindsait history)

SELECT      t.car_id,
			t.auth_id,
			MAX(aal.date_action) as 'PCR_scored'
			
INTO		#temp_PCR_scored

FROM	    #temp3 t
			join ASDReportDB.niacombine.auth_action_log_nia aal WITH (NOLOCK) on (t.car_id = aal.car_id and t.auth_id = aal.auth_id)
			
WHERE		aal.auth_action_code in ('1537','1538','1277','1278')

GROUP BY    t.car_id,
            t.auth_id
 
 --drop table #temp_PCR_scored
 --select distinct car_id, auth_id from #temp_PCR_scored order by car_id, auth_id
---------------------------------------------------------------------------------------------------
-- Get Sent to Hindsait Action Code and Internal AI Eligble for Scoring Action codes

SELECT      t.car_id,
			t.auth_id,
			MIN(aal.date_action) as 'sent_to_AI'
			
INTO		#temp_sent_AI

FROM	    #temp3 t
			join ASDReportDB.niacombine.auth_action_log_nia aal WITH (NOLOCK) on (t.car_id = aal.car_id and t.auth_id = aal.auth_id)
			
WHERE		aal.auth_action_code in ('1240','1487','1532','1533')

GROUP BY    t.car_id,
            t.auth_id
 
--drop table #temp_sent_hindsait
--select distinct car_id from #temp_sent_hindsait order by car_id
--select distinct t.proc_desc, t.line_of_business, convert(date,tsh.sent_to_Hindsait) as 'date_entered' from #temp_sent_Hindsait tsh join #temp2 t with (nolock) on (tsh.car_id = t.car_id and tsh.auth_id = t.auth_id) where proc_desc = 'Brain MRI' and line_of_business <> 'MC' order by convert(date,tsh.sent_to_Hindsait) desc
---------------------------------------------------------------------------------------------------

-- PULL LACK OF CLINICAL ACTION CODES

SELECT	t.car_id,
		t.auth_id,
		'Yes' as 'denied_lack_clinical'

INTO	#temp_loc

FROM	#temp3 t 
		join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
		
WHERE	aal.auth_action_code in ('20')
		

GROUP BY	t.car_id,
			t.auth_id

---------------------------------------------------------------------------------------------------

-- PULL BACK OFFICE (STANSON) AUTO APPROVALS ACTION CODES  --added 20210225

SELECT t.car_id,
       t.auth_id,
       'Yes' as 'BackOffice_auto_approval'

INTO   #temp_boaa

FROM   #temp3 t 
       join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
              
WHERE  aal.auth_action_code in ('1697')
              

GROUP BY      t.car_id,
              t.auth_id

---------------------------------------------------------------------------------------------------

-- PULL BACK OFFICE (STANSON) AUTO APPROVALS ACTION CODES  --added 20210225

SELECT t.car_id,
       t.auth_id,
       'Yes' as 'BackOffice_eligible'

INTO   #temp_boe

FROM   #temp3 t 
       join ASDReportDB.niacombine.auth_action_log_nia aal on (t.car_id = aal.car_id and t.auth_id =  aal.auth_id)
              
WHERE  aal.auth_action_code in ('1694','1695')
              

GROUP BY      t.car_id,
              t.auth_id

---------------------------------------------------------------------------------------------------
-- GET MAX APPEAL HISTORY ID

SELECT      t.car_id,
			t.auth_id,
			MAX(ah.appeal_history_id) as 'max_appeal_history_id'
						
INTO		#temp_appeal

FROM	    #temp3 t
			join ASDReportDB.niacombine.appeal_history_nia ah WITH (NOLOCK) on (t.car_id = ah.car_id and t.auth_id = ah.auth_id)
			

WHERE		ah.appeal_type_id in ('m1','m2','p1','p2','nd')
  
GROUP BY    t.car_id,
            t.auth_id
 
 ---------------------------------------------------------------------------------------------------

-- Get Final Appeal Status

SELECT  t.car_id, 
		t.auth_id, 
		t.max_appeal_history_id,
		ah.appeal_intent_date as 'appeal_date',
		at.report_translation as 'appeal_type',
		appeal_final_outcome = aout14.description,
		apscd7.appeal_status_description,
		apschg5.date_changed as 'final_appeal_status_date'		
		
INTO	#temp_appeal_outcome
		
FROM	#temp_appeal t
		join ASDReportDB.niacombine.appeal_history_nia ah with (nolock) on (t.car_id = ah.car_id and t.auth_id = ah.auth_id and t.max_appeal_history_id = ah.appeal_history_id)
		
--02 JOIN to appeal_status_change to get the max final status of the appeal
		left outer join asdreportdb.niacombine.appeal_status_change_nia apschg5 with (nolock) on (ah.car_id = apschg5.car_id and ah.appeal_history_id = apschg5.appeal_history_id and apschg5.date_changed = 
									(select max(apschg6.date_changed) from asdreportdb.niacombine.appeal_status_change_nia apschg6 with(nolock)
									 join niacore..appeal_status_codes apscd4 with(nolock) on apschg6.new_appeal_status = apscd4.appeal_status
									 where apschg6.car_id = apschg5.car_id
									 and apschg6.appeal_history_id = apschg5.appeal_history_id
									 and apscd4.final_status_flag = 1))
 
		left outer join niacore..appeal_status_codes apscd7 with(nolock) on (apschg5.new_appeal_status = apscd7.appeal_status)
		left outer join niacore..auth_outcomes aout14 with(nolock) on (apscd7.auth_outcome = aout14.auth_outcome)
		left join niacore..appeal_types at with (nolock) on (ah.appeal_type_id = at.appeal_type_id)

--select * from #temp_appeal_outcome where car_id = 54 and auth_id in ('20009H180','19353H203','19046H018','20023H019','19267H187')
--drop table #temp_appeal_outcome
--select car_id, auth_id, count(*) as 'appeal_count' from #temp_appeal_outcome group by car_id, auth_id order by count(*) desc
--select car_id, auth_id, appeal_type_id, appeal_history_id, appeal_intent_date from ASDReportdb.niacombine.appeal_history_nia where car_id = 57 and auth_id in ('N17012400934','17087SHP491','19276SHP589','19058SHP198') order by car_id, auth_id, appeal_type_id, appeal_history_id
---------------------------------------------------------------------------------------------------
-- Get Initial Determination Date

SELECT      t.*,
			aschg.date_changed as 'initial_determination_date',
	case	when ascd.auth_outcome <> 'A' and ascd.auth_status_type in ('C','R') then 'Clinical Denial'
			when ascd.auth_outcome <> 'A' and ascd.auth_status_type = 'A' then 'Admin Denial'
			when ascd.auth_outcome = 'A' then 'Approval'
			else null
			end as 'initial_outcome_category',
			ascd.report_translation as 'initial_translation'
			
INTO		#temp_initial

FROM	    #temp3 t
			join niacombine.auth_status_change_nia aschg WITH (NOLOCK) on (t.auth_id = aschg.auth_id AND t.CAR_ID = ASCHG.CAR_ID)
            join niacore..auth_status_codes ascd WITH (NOLOCK) on (aschg.new_auth_status = ascd.auth_status)
				
WHERE		ascd.final_status_flag = 1 
			and aschg.date_changed = (select min(aschg1.date_changed) 
                            from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
                            where aschg1.auth_id = t.auth_id and t.car_id = aschg1.car_id and 
                           exists (select 'true'
                                   from niacore..auth_status_codes ascd1 WITH (NOLOCK)
                                   where aschg1.new_auth_status = ascd1.auth_status and
                                         aschg1.car_id = t.car_id and 
                                         ascd1.final_status_flag = 1))
			
--select * from #temp2
--select count(*) from #temp_initial
--drop table #temp_initial
---------------------------------------------------------------------------------------------------	
-- Get auths with determination date after the start_date

SELECT		t.*

INTO		#temp4

FROM		#temp3 t

WHERE	    t.final_determination_date >= t.start_date
		and t.final_determination_date < dateadd(dd,1,t.end_date) 

-- select distinct car_id, auth_id from #temp5
-- drop table #temp5
---------------------------------------------------------------------------------------------------

-- Get members that had more than one authorizations for the same procedure

SELECT      t.car_id,
			t.member_id,
			t.proc_desc,
			t.auth_id as 'final_auth_id',
			t.date_call_rcvd as 'final_call_rcvd',
			t.final_determination_date,
			t.final_determination,
			t.outcome_category as 'final_outcome_category',
			t3.auth_id as 'initial_auth_id',
			t3.date_call_rcvd as 'initial_call_rcvd',
			t3.final_determination_date as 'initial_determination_date',
			t3.final_determination as 'initial_determination',
			t3.outcome_category as 'initial_outcome_category'	
                  
INTO		#temp_recur

FROM	    #temp4 t
			join #temp3 t3 WITH (NOLOCK) on (t.car_id = t3.car_id and t.member_id = t3.member_id and t.proc_desc = t3.proc_desc)
            
WHERE		t3.date_call_rcvd < t.date_call_rcvd
		and t3.date_call_rcvd >= dateadd(dd,-90,t.date_call_rcvd) 
			and t.auth_id <> t3.auth_id

--select * from #temp_recur order by car_id, member_id
--drop table #temp_recur
--select distinct subsequent_procedure from #temp_approval order by subsequent_procedure
--drop table #temp_denial
--select * from asdreportdb.niacombine.authorizations_nia where car_id = 54 and auth_id in ('19176H077','19149H183')
---------------------------------------------------------------------------------------------------

-- Get distinct final auth_id to eliminate dups

SELECT DISTINCT	t.car_id,
				t.final_auth_id,
				max(initial_determination_date) as 'max_initial'
		
INTO			#temp_recur_2

FROM			#temp_recur t	

WHERE			t.initial_outcome_category = 'Clinical Denial'
			and t.final_outcome_category = 'Approval'

GROUP BY		t.car_id,
				t.final_auth_id

--drop table #temp_recur_2			
--select * from #temp_subs order by car_id, member_id
---------------------------------------------------------------------------------------------------
-- Get data for unique final_auth_id

SELECT      t2.car_id,
			t.member_id,
			t.proc_desc,
			t2.final_auth_id,
			t.final_call_rcvd,
			t.final_determination_date,
			t.final_determination,
			t.final_outcome_category,
			t.initial_auth_id,
			t.initial_call_rcvd,
			t.initial_determination_date,
			t.initial_determination,
			t.initial_outcome_category	
		
INTO		#temp_recur_final

FROM		#temp_recur_2 t2
			join #temp_recur t with (nolock) on (t2.car_id = t.car_id and t2.final_auth_id = t.final_auth_id and t2.max_initial = t.initial_determination_date)
				
--drop table #temp_recur_final			
--select * from #temp_subs order by car_id, member_id
--select * from #temp_recur_final where car_id = 51 and final_auth_id in ('187F7N7','187H0NT','187H9PC','187W931','187C00J','187DV31') order by car_id, final_auth_id
--select car_id, final_auth_id, count(*) from #temp_recur_final group by car_id, final_auth_id order by count(*) desc
---------------------------------------------------------------------------------------------------

-- Combine Data 

SELECT		t.car_id,
			t.car_name,
	case    when t.line_of_business = 'OT' then 'CO' else t.line_of_business end as 'line_of_business',
			t.funding_risk_type,
	case	when t.funding_risk_type = 2 then 'Risk' 
			when t.funding_risk_type in ('5','6','7','8') then 'ASO Premium'
			else 'ASO' end as 'funding_description',
			t.auth_id,
			t.authorization_type_id,
			t.combo_flag,
			t.expedite_flag,
	case    when t.short_desc = 'CA' then 'CT'
			when t.short_desc = 'MA' then 'MR' else t.short_desc end as 'modality',
	case    when t.short_desc = 'CA' then 'CT (Computed Tomography)'
			when t.short_desc = 'MA' then 'MRI (Magnetic Resonance Imaging)' else t.exam_cat_desc end as 'modality_desc',
	case	when t.proc_desc like '% - %' then LEFT(t.proc_desc,charindex('-',t.proc_desc,0)-2)
			when t.proc_desc like '% (%)' then LEFT(t.proc_desc,charindex('(',t.proc_desc,0)-2)
			when t.proc_desc like '%(%' then LEFT(t.proc_desc,charindex('(',t.proc_desc,0)-1)
			when t.proc_desc in ('Brain MRI (with Internal Auditory Canal views)') then 'Brain MRI'
			--when t.proc_desc in ('PET Scan with CT for Attenuation','PET Scan') then 'PET Scan'
			else t.proc_desc
			end as 'proc_desc',
			t.cardiology_product_flag,
			t.final_determination_date, 
			final_determination_year = convert(varchar,datepart(yyyy,t.final_determination_date)),
			final_determination_month = case 
				when datepart(mm,t.final_determination_date) between 1 and 9
				then convert(varchar,0)+convert(varchar,datepart(mm,t.final_determination_date))
				else convert(varchar,datepart(mm,t.final_determination_date)) 
				end,			
			t.report_translation as 'final_translation',
			t.outcome_category as 'final_outcome_category',
			t.recon_status_flag,
	case	when tboaa.BackOffice_auto_approval is not null then 'AR' --jfm added 20210225 for back office
			when ta.auth_id is not null and pcr.auth_id is not null 
			then pcr.PCR_level
			when t.level_of_determination = 'ICR' and t.status_desc like 'MD%' then 'PCR' --jfm added 9/30/2020
			else t.level_of_determination
			end as 'final_determination_level',  
	case	when tboaa.BackOffice_auto_approval is not null then 'AR'  --jfm added 20210225 for back office
			when ta.auth_id is not null and pcr.auth_id is not null 
			then pcr.PCR_level
			else t.level_of_determination
			end as 'final_determination_level_wo_designated',  
			ta2.ICR_action,
			ta2.PCR_action,
			ts.ICR_status,
			ts.PCR_status,
	case	when tb.ICR_bypass is NULL then 'No' else 'Yes' end as 'ICR_bypass',
	case	when tis.ICR_scored is NULL then 'No' else 'Yes' end as 'ICR_scored',
	case	when tps.PCR_scored is NULL then 'No' else 'Yes' end as 'PCR_scored',
	case    when tsa.sent_to_AI is NULL then 'No' else 'Yes' end as 'sent_to_AI',
	case    when ti.addl_clinical_received is NULL then 'No' else 'Yes' end as 'addl_clinical_received',
	case    when tp2p.P2P_held is NULL then 'No' else 'Yes' end as 'P2P_held',
	case    when loc.denied_lack_clinical is NULL then 'No' else 'Yes' end as 'denied_lack_of_clinical',
	case    when tap.appeal_date IS NOT NULL then 'Yes' else 'No' end as 'appeal_flag',
			ti2.initial_determination_date,
			ti2.initial_translation,
	case    when tap.appeal_type = 'Clinical Appeal' and tap.appeal_final_outcome <> 'Withdrawal' then 'Yes' else 'No' end as 'clinical_appeal_not_wd',
	case    when tap.appeal_type = 'Appeal Recommendation' and tap.appeal_final_outcome <> 'Withdrawal' then 'Yes' else 'No' end as 'appeal_rec_not_wd',
	case    when tf.final_auth_id IS NULL then 0 else 1 end as 'recurrence_flag',
			t.case_id_2,
			t.Algorithm_Approved_Count,
			t.Algorithm_Disapproved_Count,
			t.Algorithm_Unknown_Count,
			t.status_desc,
			ti2.initial_outcome_category,
	case    when tboaa.BackOffice_auto_approval IS NULL then 0 else 1 end as 'BackOffice_auto_approval',  --backoffice change 20210225
	Case	when tboe.BackOffice_eligible is null then 0 else 1 end as 'BackOffice_eligible'  --backoffice change 20210225


INTO		#temp5

FROM		#temp4 t
			left join #temp_bypass tb with (nolock) on (t.car_id = tb.car_id and t.auth_id = tb.auth_id)
			left join #temp_PCR	pcr with (nolock) on (t.car_id = pcr.car_id and t.auth_id = pcr.auth_id)
			left join #temp_action_112 ta	with (nolock) on (t.car_id = ta.car_id	and t.auth_id = ta.auth_id)
			left join #temp_action ta2 with (nolock) on (t.car_id = ta2.car_id and t.auth_id = ta2.auth_id)
			left join #temp_status ts with (nolock) on (t.car_id = ts.car_id and t.auth_id = ts.auth_id)
			left join #temp_ICR_scored tis with (nolock) on (t.car_id = tis.car_id and t.auth_id = tis.auth_id)
			left join #temp_PCR_scored tps with (nolock) on (t.car_id = tps.car_id and t.auth_id = tps.auth_id)
			left join #temp_sent_AI tsa with (nolock) on (t.car_id = tsa.car_id and t.auth_id = tsa.auth_id)
			left join #temp_info ti with (nolock) on (t.car_id = ti.car_id and t.auth_id = ti.auth_id)
			left join #temp_P2P tp2p with (nolock) on (t.car_id = tp2p.car_id and t.auth_id = tp2p.auth_id)		
			left join #temp_loc loc with (nolock) on (t.car_id = loc.car_id and t.auth_id = loc.auth_id)
			left join #temp_appeal_outcome tap with (nolock) on (t.car_id = tap.car_id and t.auth_id = tap.auth_id)
			left join #temp_initial ti2 with (nolock) on (t.car_id = ti2.car_id and t.auth_id = ti2.auth_id)
			left join #temp_recur_final tf with (nolock) on (t.car_id = tf.car_id and t.auth_id = tf.final_auth_id)
			left join #temp_boaa tboaa with (nolock) on (t.car_id = tboaa.car_id and t.auth_id = tboaa.auth_id)  --backoffice change 20210225
			left join #temp_boe tboe with (nolock) on (t.car_id = tboe.car_id and t.auth_id = tboe.auth_id)  --backoffice change 20210225
						
ORDER BY	t.car_id,
			t.auth_id

--select * from #temp3 
--select distinct final_determination_level from #temp4
--select HS_routing, count(*) from #temp3 group by HS_routing
--select proc_desc, count(*) from #temp3 group by proc_desc
--drop table #temp5
--select distinct authorization_type_id, proc_desc from #temp3 order by authorization_type_id, proc_desc
---------------------------------------------------------------------------------------------------
-- Set More Data Flags


SELECT		t.car_id,
			t.car_name,
			t.line_of_business,
			t.funding_risk_type,
			t.funding_description,
			t.auth_id,
			t.case_id_2,
			t.combo_flag,
			t.expedite_flag,
	case    when t.authorization_type_id = '5' then 'IPM' 
			when t.authorization_type_id = '6' then 'Surgery'
			when t.cardiology_product_flag = '1' then 'Cardiac'
			else 'RBM' end as 'proc_type',
			t.modality,
			t.modality_desc,
			t.proc_desc,
			t.final_determination_date, 
	--case    when (t.final_determination_year = '2019' and t.final_determination_month = '11' and t.final_determination_date <  '11/14/2019') then '201911 - 1H'
	--		when (t.final_determination_year = '2019' and t.final_determination_month = '11' and t.final_determination_date >= '11/14/2019') then '201911 - 2H'
	--		else (t.final_determination_year + t.final_determination_month) end as 'year_month',
	       (t.final_determination_year + t.final_determination_month) as 'year_month',
			t.final_translation,
			t.final_outcome_category,
			t.recon_status_flag,
	case    when t.final_determination_level = 'NA' then 'AR' else t.final_determination_level end as 'final_determination_level',  
	case   when ((t.ICR_action = 1 or t.ICR_status = 1) and t.BackOffice_auto_approval = 0) then 1 else 0 end as 'ICR_touch',  --backoffice change 20210225
    case   when ((t.PCR_action = 1 or t.PCR_status = 1) and t.BackOffice_auto_approval = 0) then 1 else 0 end as 'PCR_touch',  --backoffice change 20210225

		    t.ICR_bypass,
			t.ICR_scored,
			t.PCR_scored,
			t.sent_to_AI,
			t.addl_clinical_received,
			t.P2P_held,
			t.denied_lack_of_clinical,
			t.recurrence_flag,
			t.appeal_flag,
			t.initial_determination_date,
			t.clinical_appeal_not_wd,
			t.appeal_rec_not_wd,
	case    when (t.clinical_appeal_not_wd = 'Yes' and t.final_determination_date <> t.initial_determination_date and t.final_outcome_category IN ('Approval','Clinical Denial')) then 1 else 0 end as 'clinical_appeal_count',
	case    when (t.clinical_appeal_not_wd = 'Yes' and t.final_determination_date <> t.initial_determination_date and t.final_outcome_category = 'Approval') then 1 else 0 end as 'clinical_appeal_approval',
	case    when (t.clinical_appeal_not_wd = 'Yes' and t.final_determination_date <> t.initial_determination_date and t.final_outcome_category = 'Clinical Denial') then 1 else 0 end as 'clinical_appeal_denial',
	case    when (t.appeal_rec_not_wd = 'Yes' and t.final_determination_date <> t.initial_determination_date and t.final_outcome_category IN ('Approval','Clinical Denial')) then 1 else 0 end as 'appeal_rec_count',
	case    when (t.appeal_rec_not_wd = 'Yes' and t.final_determination_date <> t.initial_determination_date and t.final_outcome_category = 'Approval') then 1 else 0 end as 'appeal_rec_approval',
	case    when (t.appeal_rec_not_wd = 'Yes' and t.final_determination_date <> t.initial_determination_date and t.final_outcome_category = 'Clinical Denial') then 1 else 0 end as 'appeal_rec_denial',
			t.Algorithm_Approved_Count,
			t.Algorithm_Disapproved_Count,
			t.Algorithm_Unknown_Count,
			t.status_desc,
	case    when t.final_determination_level_wo_designated = 'NA' then 'AR' else t.final_determination_level_wo_designated end as 'final_determination_level_wo_designated',
			t.initial_outcome_category,  --added 20201013 per karen Froyam
			t.BackOffice_auto_approval, --added 20210225 for back office
			t.BackOffice_eligible  --added 20210225 for back office
			
INTO		#temp6

FROM		#temp5 t


--select * from #temp4 where ICR_bypass = 'Yes' and (ICR_scored = 'Yes' or PCR_scored = 'Yes')
--select * from #temp4 where ICR_scored = 'No' and PCR_scored = 'Yes' and final_determination_level <> 'PCR'
--drop table #temp6
--select count(*) from #temp1
----------------------------------------------------------------------------------------------
-- Get auth counts by procedure

SELECT	t.proc_type,

		t.proc_desc, 
		count(*) as 'auth_count' 

INTO	#temp_totals
		
FROM	#temp6 t

GROUP BY	
			t.proc_type, 
			t.proc_desc  

--drop table #temp_totals_case
---------------------------------------------------------------------------------------------------
-- Order the procedures by procedure group and volume

SELECT	
		
		t.proc_type,
		t.proc_desc,
		t.auth_count,
		seq = ROW_NUMBER() OVER(Partition BY t.proc_type ORDER BY t.proc_type, t.auth_count desc)

INTO	#temp_ordered

FROM	#temp_totals t

--select * from #temp_ordered order by procedure_group, seq
--drop table #temp_ordered_case


---------------------------------------------------------------------------------------------------
-- Add the sequence to the table

SELECT	t.*,
		tor.seq

INTO	#temp7

FROM	#temp6 t
		join #temp_ordered tor with (nolock) on (t.proc_type = tor.proc_type and t.proc_desc = tor.proc_desc )

--select * from #temp5
--drop table #temp7
--Select count(*) from #temp6
--where case_id_2 is null
--Select count(*) from #temp7
---------------------------------------------------------------------------------------------------
-- Get auth counts by procedure and case --added 20200815 jfm

SELECT	t.proc_type,
		t.case_id_2,
		t.proc_desc, 
		count(*) as 'auth_count' 

INTO	#temp_totals_case
		
FROM	#temp6 t

GROUP BY	t.case_id_2,
			t.proc_type, 
			t.proc_desc  

--drop table #temp_totals_case
---------------------------------------------------------------------------------------------------
-- Order the procedures by procedure group and volume and case  --added 20200815 jfm

SELECT	
		t.case_id_2,
		t.proc_type,
		t.proc_desc,
		t.auth_count,
		seq_case = ROW_NUMBER() OVER(Partition BY t.case_id_2, t.proc_type ORDER BY t.case_id_2, t.proc_type, t.auth_count desc)

INTO	#temp_ordered_case

FROM	#temp_totals_case t

--select * from #temp_ordered order by procedure_group, seq
--drop table #temp_ordered_case
----------------------------------------------------------------------
-- Add the sequence for case level to the table  --added 20200815 jfm

SELECT	t.*,
		tor.seq_case

INTO	#temp7b

FROM	#temp7 t
		join #temp_ordered_case tor with (nolock) on (t.proc_type = tor.proc_type and t.proc_desc = tor.proc_desc and isnull(t.case_id_2,'NULL') = isnull(tor.case_id_2,'NULL'))

--select * from #temp5
--drop table #temp7
--Select count(*) from #temp6
--where case_id_2 is null
--Select count(*) from #temp7
---------------------------------------------------------------------------------------------------

-- Set counters

SELECT		t.car_id,
			t.car_name,
			t.line_of_business,
			t.funding_description,
			t.auth_id,
			t.case_id_2,
			t.combo_flag,
			t.expedite_flag,
			t.proc_type,
			t.modality,
			t.modality_desc,
			t.proc_desc,
	case    when (t.proc_type = 'Cardiac' and t.seq <= 12) then t.proc_desc 
			when  t.proc_type = 'Cardiac' then 'All Other Cardiac' 
			when (t.proc_type = 'IPM' and t.seq <= 9) then t.proc_desc 
			when  t.proc_type = 'IPM' then 'All Other IPM'
			when (t.proc_type = 'RBM' and t.seq <= 30) then t.proc_desc 
			when  t.proc_type = 'RBM' then 'All Other RBM'
			when (t.proc_type = 'Surgery' and t.seq <= 12) then t.proc_desc 
			when  t.proc_type = 'Surgery' then 'All Other Surgery'
			else 'Other' end as 'procedure_rollup',
	case    when (t.proc_type = 'Cardiac' and t.seq_case <= 12) then t.proc_desc 
			when  t.proc_type = 'Cardiac' then 'All Other Cardiac' 
			when (t.proc_type = 'IPM' and t.seq_case <= 9) then t.proc_desc 
			when  t.proc_type = 'IPM' then 'All Other IPM'
			when (t.proc_type = 'RBM' and t.seq_case <= 30) then t.proc_desc 
			when  t.proc_type = 'RBM' then 'All Other RBM'
			when (t.proc_type = 'Surgery' and t.seq_case <= 12) then t.proc_desc 
			when  t.proc_type = 'Surgery' then 'All Other Surgery'
			else 'Other' end as 'procedure_rollup_case',  --added 20200815 jfm
			t.final_determination_date, 
		    t.year_month,
	case	when (t.year_month in('202001','202002','202003')) then '202001_03' else t.year_month end as year_month_Covid,
			t.final_translation,
			t.final_outcome_category,
			t.recon_status_flag,
			t.final_determination_level,  
			t.ICR_touch,
			t.PCR_touch,
		    t.ICR_bypass,
			t.ICR_scored,
			t.PCR_scored,
			t.sent_to_AI,
			t.denied_lack_of_clinical,
	case    when (t.final_determination_level = 'AR' and t.final_outcome_category = 'Admin Denial') then 'Yes' else 'No' end as 'AR_Admin_Denial',
	case    when (t.final_determination_level = 'AR' and t.final_outcome_category = 'Admin Denial') then 0 else 1 end as 'auth_count',    
	--case    when (t.final_determination_level = 'AR' and t.final_outcome_category = 'Approval') then 1 else 0 end as 'AR_approval',
	case    when (t.final_determination_level = 'AR' and t.final_outcome_category = 'Approval' and t.BackOffice_auto_approval <> 1) then 1 else 0 end as 'AR_approval',  --backoffice change 20210225
	case    when  t.ICR_touch = 1 then 1 else 0 end as 'ICR_touch_count',
	case    when (t.final_determination_level = 'ICR' and t.final_outcome_category = 'Approval') then 1 else 0 end as 'ICR_approval',
	case    when (t.final_determination_level = 'PCR' and t.final_outcome_category = 'Approval') then 1 else 0 end as 'PCR_approval',
	case    when (t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level = 'PCR') then 1 else 0 end as 'AI_direct_to_PCR',
	case    when (t.ICR_bypass = 'Yes' and t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level = 'PCR') then 0
	        when (t.ICR_bypass = 'Yes' and t.final_determination_level = 'PCR') then 1 else 0 end as 'ICR_bypass_count',
	case    when (t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level = 'PCR') then 0
	        when (t.ICR_bypass = 'Yes' and t.final_determination_level = 'PCR') then 0
			when  t.final_determination_level = 'PCR' then 1 else 0 end as 'other_PCR_escalation',
	case    when (t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level = 'PCR') then 0
	        when (t.ICR_bypass = 'Yes' and t.final_determination_level = 'PCR') then 0
			when (t.final_determination_level = 'PCR' and t.ICR_touch = 1 and t.PCR_touch = 1) then 1 else 0 end as 'concordance_escalation',
	case    when  t.final_determination_level = 'AR' then 1 else 0 end as 'AR_count',
	case    when  t.final_determination_level = 'ICR' then 1 else 0 end as 'ICR_count',
	case    when  t.final_determination_level = 'PCR' then 1 else 0 end as 'PCR_count',
	case    when  t.final_outcome_category = 'Admin Denial' then 1 else 0 end as 'admin_denial_count',
	case    when  t.final_outcome_category = 'Approval' then 1 else 0 end as 'approval_count',
	case    when  t.final_outcome_category = 'Clinical Denial' then 1 else 0 end as 'denial_count',
	case    when (t.final_determination_level = 'PCR' and t.final_outcome_category = 'Clinical Denial') then 1 else 0 end as 'PCR_denial_count',
	case    when (t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level = 'PCR' and t.final_outcome_category = 'Clinical Denial') then 1 else 0 end as 'AI_direct_to_PCR_denial',
	case    when (t.ICR_bypass = 'Yes' and t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level = 'PCR') then 0
	        when (t.ICR_bypass = 'Yes' and t.final_determination_level = 'PCR' and t.final_outcome_category = 'Clinical Denial') then 1 else 0 end as 'ICR_bypass_denial',
	case    when (t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level = 'PCR') then 0
	        when (t.ICR_bypass = 'Yes' and t.final_determination_level = 'PCR') then 0
			when (t.final_determination_level = 'PCR' and t.ICR_touch = 1 and t.PCR_touch = 1 and t.final_outcome_category = 'Clinical Denial') then 1 else 0 end as 'concordance_PCR_denial',	
	case	when (t.addl_clinical_received = 'No' and t.P2P_held = 'No' and t.appeal_flag = 'No' and t.recon_status_flag = 0 and t.final_determination_level = 'PCR' and t.ICR_touch = 1 and t.PCR_touch = 1 and t.final_outcome_category = 'Clinical Denial') then 1 else 0 end as 'concordance_numerator',
	case    when (t.addl_clinical_received = 'No' and t.P2P_held = 'No' and t.appeal_flag = 'No' and t.recon_status_flag = 0 and t.final_determination_level = 'PCR' and t.ICR_touch = 1 and t.PCR_touch = 1) then 1 else 0 end as 'concordance_denominator',
	case    when (t.ICR_touch = 1 and t.PCR_touch = 1) then 1 else 0 end as 'ICR_PCR_touch_count',
	case    when  (t.final_determination_level = 'PCR' and t.P2P_held = 'Yes') then 1 else 0 end as 'successful_P2P',
	case    when  (t.final_determination_level = 'PCR' and t.P2P_held = 'Yes' and t.final_outcome_category = 'Approval') then 1 else 0 end as 'P2P_approval',
			t.clinical_appeal_count,
			t.clinical_appeal_approval,
			t.clinical_appeal_denial,
			t.appeal_rec_count,
			t.appeal_rec_approval,
			t.appeal_rec_denial,
			t.recurrence_flag,
			t.Algorithm_Approved_Count,
			t.Algorithm_Disapproved_Count,
			t.Algorithm_Unknown_Count,
			t.status_desc,
			t.final_determination_level_wo_designated,
	case    when (t.final_determination_level_wo_designated = 'PCR' and t.final_outcome_category = 'Clinical Denial') then 1 else 0 end as 'PCR_denial_count_wo_designated',
	case    when (t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level_wo_designated = 'PCR') then 1 else 0 end as 'AI_direct_to_PCR_wo_designated',
	case    when (t.ICR_bypass = 'Yes' and t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level_wo_designated = 'PCR') then 0
	        when (t.ICR_bypass = 'Yes' and t.final_determination_level_wo_designated = 'PCR') then 1 else 0 end as 'ICR_bypass_count_wo_designated',
	case    when (t.ICR_scored = 'No' and t.PCR_scored = 'Yes' and t.final_determination_level_wo_designated = 'PCR') then 0
	        when (t.ICR_bypass = 'Yes' and t.final_determination_level_wo_designated = 'PCR') then 0
			when  t.final_determination_level_wo_designated = 'PCR' then 1 else 0 end as 'other_PCR_escalation_wo_designated',
	case    when (t.final_determination_level = 'PCR' and t.initial_outcome_category = 'Clinical Denial') then 1 else 0 end as 'PCR_Initial_Clinical_Denial',  --added 20201013 per karen Froyam
			t.BackOffice_auto_approval,  --added 20210225 for backoffice
			t.BackOffice_eligible  --added 20210225 for back office
			
INTO		#temp7c  --changed from #temp8 on 20200828 jfm

FROM		#temp7b t

---------------------------------------------------------------------------------------------------
--add column to catch if auth is in any of these('AI_direct_to_PCR','ICR_bypass_count','other_PCR_escalation')  --added 20200828 jfm

SELECT		t.*,
            case when AI_direct_to_PCR = 1 then 1
				 when ICR_bypass_count = 1 then 1
				 when other_PCR_escalation = 1 then 1 else 0
			end as 'PCR_Touch_Escalation'
			
INTO		#temp8
FROM		#temp7c t
----------------------------------------------------------------------------------------------------

--select * from #temp5 where final_outcome_category = 'Clinical Denial' and final_determination_level = 'PCR'
--select count(*) from #temp1
--drop table #temp8
--select final_outcome_category, denied_lack_of_clinical, count(*) from #temp5 where AR_admin_denial = 'No' group by final_outcome_category, denied_lack_of_clinical order by final_outcome_category, denied_lack_of_clinical
----------------------------------------------------------------------------------------------
DROP TABLE	adhoc.dbo.concordance_escalation_Month     ---JFM ---Change this to delete last 12 or 24 months...need to validate

SELECT		t.*

INTO		adhoc.dbo.concordance_escalation_Month

FROM		#temp8 t

---------------------------------------------------------------------------------------------------
-- Summarize Data


SELECT		t.car_id,
			t.car_name,
			t.line_of_business,
			t.funding_description,
			t.combo_flag,
			--t.expedite_flag,
			t.proc_type, 
			t.modality_desc,
			t.procedure_rollup,
			t.procedure_rollup_case,
			t.year_month,
			--t.denied_lack_of_clinical,
			t.AR_Admin_Denial,
			t.case_id_2,
			sum(t.auth_count) as 'total_auth_count',    
			sum(AR_approval) as 'total_AR_approval',
			sum(t.ICR_touch_count) as 'total_ICR_touch',
			sum(t.ICR_approval) as 'total_ICR_approval',
			sum(t.PCR_approval) as 'total_PCR_approval',
			sum(t.AI_direct_to_PCR) as 'total_AI_direct_to_PCR',
			sum(t.ICR_bypass_count) as 'total_ICR_bypass',
			sum(t.other_PCR_escalation) as 'total_other_PCR_escalation',
			sum(t.concordance_escalation) as 'total_concordance_escalation',
			sum(t.AR_count) as 'total_AR_resolved',
			sum(t.ICR_count) as 'total_ICR_resolved',
			sum(t.PCR_count) as 'total_PCR_resolved',
			sum(t.admin_denial_count) as 'total_admin_denial',
			sum(t.approval_count) as 'total_approvals',
			sum(t.denial_count) as 'total_denials',
			sum(t.PCR_denial_count) as 'total_PCR_denials',
			sum(t.AI_direct_to_PCR_denial) as 'total_AI_PCR_denials',
			sum(t.ICR_bypass_denial) as 'total_ICR_bypass_denials',
			sum(t.concordance_PCR_denial) as 'total_concordance_PCR_denials',
			sum(t.concordance_numerator) as 'total_concordance_numerator',
			sum(t.concordance_denominator) as 'total_concordance_denominator',
			sum(t.ICR_PCR_touch_count) as 'total_ICR_PCR_touch',
			sum(t.successful_P2P) as 'total_successful_P2P',
			sum(t.P2P_approval) as 'total_P2P_approval',
			sum(t.recurrence_flag) as 'total_recurrence',
			sum(t.clinical_appeal_count) as 'total_clinical_appeals',
			sum(t.clinical_appeal_approval) 'total_clinical_appeals_approved',
			--sum(t.clinical_appeal_denial) as 'total_clinical_appeals_denied',
			sum(t.appeal_rec_count) as 'total_appeal_recommendations',
			sum(t.appeal_rec_approval) as 'total_appeal_rec_approved',
			--sum(t.appeal_rec_denial) as 'total_appeal_rec_denied'
			sum(t.PCR_Touch_Escalation) as 'total_PCR_Escalation',  --added 20200828 jfm
			t.year_month_Covid,  --added 20200912 jfm
			sum(t.Algorithm_Approved_Count) as 'total_algorithm_approved',  --added 20200912 jfm
			sum(t.Algorithm_Disapproved_Count) as 'total_algorithm_disapproved',  --added 20200912 jfm
			sum(t.Algorithm_Unknown_Count) as 'total_algorithm_unknown',  --added 20200912 jfm
			sum(t.PCR_Touch)as 'total_PCR_touch' , --added 20200917 jfm
			sum(t.PCR_denial_count_wo_designated) as 'total_PCR_denials_wo_designated', --added 20200930 to show old CDR without designations
			sum(t.AI_direct_to_PCR_wo_designated) as 'total_AI_direct_to_PCR_wo_designated',--added 20200930 to show old CDR without designations
			sum(t.ICR_bypass_count_wo_designated) as 'total_ICR_bypass_wo_designated',--added 20200930 to show old CDR without designations
			sum(t.other_PCR_escalation_wo_designated) as 'total_other_PCR_escalation_wo_designated',  --added 20200930 to show old CDR without designations
			sum(t.PCR_Initial_Clinical_Denial) as 'total_PCR_Initial_Clinical_Denial', --added 20201013 per karen Froyam
			Sum(t.BackOffice_auto_approval) as 'total_BackOffice_auto_approval',  ----added 20210225 for backoffice
			Sum(t.BackOffice_eligible) as 'total_BackOffice_eligible'  --added 20210225 for back office

FROM		adhoc.dbo.concordance_escalation_Month t

WHERE		t.AR_Admin_Denial = 'No'

GROUP BY	t.car_id,
			t.car_name,
			t.line_of_business,
			t.funding_description,
			t.combo_flag,
			--t.expedite_flag,
			t.proc_type,
			t.modality_desc,
			t.procedure_rollup,
			t.procedure_rollup_case,
			t.year_month,
			t.year_month_Covid,
			--t.denied_lack_of_clinical,
			t.AR_Admin_Denial,
			t.case_id_2

----------------------------------------------------------------------------------------------
/*
Select case_id_2, count(*) from #temp1
group by case_id_2

Select * from #temp_totals


Select * from #temp_pcr where PCR_level <> 'PCR'
and auth_id in (Select auth_id from adhoc.dbo.concordance_escalation_Month where final_determination_level = 'PCR')
*/