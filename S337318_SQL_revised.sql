/*GetIT S337318
-Per Robert Beach 5/20/19
Mark, per our conversation, here is how I think you can find all the action codes that would represent us making a communication with the ordering physician’s office.     You would use the min( ) value that occurs after clinical was received (or it was approved without receipt of further clinical, such as those approved at intake).

This is a blend of:
-	Our P2P faxes
-	Our P2P callouts
-	Any of our official notification methods for timeliness – approvals, denials, letters, faxes, emails, online via RadMD, etc.

/* First the p2P successful faxes */
Select auth_action_code from niacore.dbo.auth_action_codes
where (description like '%peer%' or description like '%p2p%') and description like '%fax%' and description like '%success%'
UNION 
-- successful p2p verbal contact
Select auth_action_code from niacore.dbo.auth_action_codes
where peer_discussion_req_met_flag = 1
UNION 
-- successful communication of any sort as measured for timeliness
Select distinct convert(int, key_value) 
from niacore.dbo.timeliness_measurement_event_keyvalues 
where queue_id = 2 -- auth_action_codes
and isnumeric(key_value)=1 -- I always put this here just for safety in case there's some bad data in the keyvalues table
and event_id in 
(2,  -- Fax notification to ordering physician
3,  -- Written notification to ordering physician
4,  -- Verbal notification to ordering physician
16,  -- Peer to Peer discussion successful
19,  -- Approval issued at intake
20,  -- Notification that additional information is required
24,  -- RadMD Notification to ordering physician
51,  -- Written notification to ordering physician (Approval)
52,  -- Written notification to ordering physician (Denial)
54,  -- Fax notification to ordering physician (Add'l Information)
55,  -- Fax notification to ordering physician (Unable to Reach - Req for Discussion)
79,  -- Appeal Ack notification to ordering physician
86,  -- RRR Approval Written notification to ordering physician
87,  -- RRR Denial Written notification to ordering physician
95,	 -- P2P call
100, -- Appeal Approval letter to Ordering Physician
101, -- Appeal Denial letter to Ordering Physician
115, -- P2P Held
131, -- Manual Letter Sent
155, -- Max P2P discussion successful
157  -- Max Clinical Info telephonically
)


--MWilliamson, KFroyum - 1/22/19 - exclude IIQ cases & those with extensions.  sibily add 875 one touch soft denial.
**pos

I think I have a solution for reporting on the Physical Medicine area.   For the section that is currently reporting TAT from receipt of records to initial clinical determination – let’s move to reporting the TAT from the date the record enters the 1st Clinical Review Queue until the initial determination.  The record will pass through more than one clinical review queue.  

I think the first queue the record will enter is the “Physical Medicine Clinical Review Queue”. Karen, can you confirm? If yes, this will be the start date for measurement purposes. 

por	Physical Medicine Clinical Review Queue

Use CCI IPM Timeliness Report as a source - Mark Gieringer created the CCI report (sample attached).  Need aggregate (not detail) time calculated in business days (excluding Holidays and Weekends) from (1) date of request (2) date of last clinical record received and (3) date from last p2p conversation.  Report by Request Type (Radiology, Cardiology, IPM, MSK). Need ability to filter by Health Plan.  Include indicator request type including retrospective request and expedited requests.

RBM	% 2 BD	% 3 BD	% 4 BD	> 4 BD		
Request Date						
Records Date						
P2P Date				
						
End Initial Determination						
exclude Rec and Appeals						
						
Aggregate and by customer						

*/


use asdreportdb

declare		@start_date datetime,
			@end_date datetime 


set			@start_date = '2/14/2021' --dateadd(wk,-1,getdate())22
set			@end_date = '2/20/2021'
--set			@end_date = DATEADD(ms, -2, DATEADD(DAY, CASE DATENAME(WEEKDAY, GETDATE())
--                        WHEN 'Sunday' THEN 0
--                        WHEN 'Monday' THEN -1
--                        ELSE -1 END, DATEDIFF(DAY, 0, GETDATE())))    

	
select @start_date, @end_date	

---------------------------------------------------------------------------------
                 --MAIN LOGIC
---------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#initial') IS NOT NULL drop table #initial

SELECT     	hp.car_id,
			hc.car_name,
			hp.line_of_business as [line of business],
			--hp.plan_id,
			hp.plan_name,
			--hp.health_plan_group_id,
			--health_plan_group_description = hpg.description,
			upper(m.lname) + ', ' + upper(m.fname) as member_name,
			convert(varchar(10),m.dob,101) as 'DOB',
			datediff(yyyy, m.dob,aschg.date_changed) as age,
			a.auth_id,
			a.cpt4_code,
			cpt.cpt4_descr, 
			Auth_origin = case when a.is_user_id = 1998 then 'RadMD' else 'Call Center' end,
			case when at.description like '%physical medicine%' then 'Physical Medicine' 
			     when mc.program is not null then mc.program
			else at.[description] end as auth_type,
			exam_cat_desc,
			ascd.auth_outcome,
			ascd.status_desc,
		
---------------------------------------------- New UM Terminology --------------	
	case
			when cd.customer_group_determination_code in ('1','5') then 'Certified'
			when cd.customer_group_determination_code in ('2','6') then 'Non-Certified'
			when cd.customer_group_determination_code = '3' then 'Administrative Non-Certified'
			when cd.customer_group_determination_code = '4' then 'Inactivated by Ordering Provider'
			when cd.customer_group_determination_code in ('7','8') then 'Partial Determination'
			else 'Other'
	end as 'determination',
--------------------------------------------------------------------------------
			a.date_call_rcvd as request_date,
			aschg.date_changed as decision_date,
			(round(adhoc.dbo.datediff_fn(date_call_rcvd,aschg.date_changed,'Y','Y')/86400,0)) as BD_TAT_Req_to_Det,
			
			Extension_Flag = 'N',

			IIQ_Flag = 'N'
	
INTO		#initial

FROM		asdreportdb.niacombine.authorizations_nia a WITH (NOLOCK)
            join asdreportdb.niacombine.auth_status_change_nia aschg WITH (NOLOCK) on (a.auth_id = aschg.auth_id and a.car_id = aschg.car_id)
            join niacore..auth_status_codes ascd WITH (NOLOCK) on (aschg.new_auth_status = ascd.auth_status)
            join asdreportdb.niacombine.members_nia m WITH (NOLOCK) on (a.member_id = m.member_id and a.car_id = m.car_id)
            join niacore..health_plan hp WITH (NOLOCK) on (m.plan_id = hp.plan_id)
            --join niacore..health_plan_groups hpg WITH (NOLOCK) on (hp.health_plan_group_id = hpg.health_plan_group_id )
            join niacore..health_carrier hc WITH (NOLOCK) on (hp.car_id = hc.car_id)
            left join niacore..cpt4_codes cpt WITH (NOLOCK) on (a.cpt4_code = cpt.cpt4_code) 
            left join niacore..exam_category ec WITH (NOLOCK) on (cpt.exam_cat_id = ec.exam_cat_id) 
			left join niacore..authorization_types at with (nolock) on (a.authorization_type_id = at.authorization_type_id)
			left join adhoc..msk_codes mc with (nolock) on (a.cpt4_code = mc.proc_code)
			--join physicians p with (NOLOCK) on (a.phys_id = p.phys_id)
            --join nirad..specialties s with (NOLOCK) on (s.spec_id = p.spec_id)
--select * from adhoc..msk_codes
---------------------------------------------- New UM Terminology ----------------
			left join niacore..um_decision_codes d with (nolock) on (ascd.um_decision_code = d.um_decision_code)
			left join niacore..um_process_codes pc with (nolock) on (ascd.um_process_code = pc.um_process_code)
			left join niacore..benefit_determination_codes b with (nolock) on (ascd.benefit_determination_code = b.benefit_determination_code)
			left join niacore..Customer_Determination_Codes cd with (nolock) on (ascd.customer_determination_code = cd.customer_determination_code)
			left join niacore..Customer_Group_Determination_Codes cgd with (nolock) on (cd.customer_group_determination_code = cgd.customer_group_determination_code)
----------------------------------------------------------------------------------

where		ascd.final_status_flag = 1 
			and aschg.date_changed = (select min(aschg1.date_changed) 
                            from asdreportdb.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
                            where aschg1.auth_id = a.auth_id and 
							aschg1.car_id = a.car_id and
                           exists (select 'true'
                                   from niacore..auth_status_codes ascd1 WITH (NOLOCK)
                                   where aschg1.new_auth_status = ascd1.auth_status and
                                         ascd1.final_status_flag = 1
										 and ascd1.auth_status not in (
											'ay','ax','az',						--Clinical Appeals
											'la','ld','da','dd','ca','cd',		--Claims Appeals
											'ha','hn','hd','ro','po',			--Healthplan approved, Healthplan denied, HP Policy Denial, HP Post Service Overturn, HP Prospective Overturn
											'za','zd',						    --Appeal Recommend Approved, Appeal Recommend Denied
											'qa','qd','qe',						--recon
											'od','or','oa',						--reopen
											'rb','rh','ru',						--rereview
											'cc'                                --remove clinical closures
										 )) and
                                         aschg1.date_changed >= @start_date and 
                                         aschg1.date_changed < dateadd(dd, 1, @end_date)) 
			and aschg.date_changed >= @start_date
			and aschg.date_changed < dateadd(dd,1,@end_date) 
			--and a.authorization_type_id = '5'-- Pain Management - Injections 
			and ascd.auth_outcome <> 'W'
			and at.business_division_id ='1'
			and hc.date_contract_inactive is null
			and cd.customer_group_determination_code <> '4'  --inactivated by ordering provider
			and a.retro_flag = 'n'  -- Per Vonda
			--and a.car_id = '23'
			--and a.auth_id in ('200504N0434','200515N1689')
--select * from #initial where auth_type = 'Musculoskeletal - Surgery'


update i2

set IIQ_Flag = case when exists (select aqha.auth_id 
					 from asdreportdb.niacombine.auth_queue_history_arch_NIA aqha with(nolock)
					 where aqha.auth_id = i2.auth_id and aqha.car_id = i2.car_id
					 and aqha.queue_code in ('IIQ')) --Member Notification Extensions
					 then 'Y' else 'N' end

from #initial i2;



update i2

set Extension_Flag = case when exists (select aal.auth_id 
					 from asdreportdb.niacombine.auth_action_log_nia aal with(nolock)
					 where aal.auth_id = i2.auth_id and aal.car_id = i2.car_id
					 and aal.auth_action_code in ('911')) --Member Notification Extensions
					 then 'Y' else 'N' end

from #initial i2;


delete from #initial where Extension_Flag = 'Y'

delete from #initial where IIQ_Flag = 'Y'

--select * from #initial



IF OBJECT_ID('tempdb..#next') IS NOT NULL drop table #next

select  car_name,
		car_id,
		[line of business],
		member_name,
		DOB,
		age,
		auth_id, 
		cpt4_code,
		auth_origin, 
		auth_type,
		status_desc,
		auth_outcome,
		determination, 
		request_date, 
		decision_date, 
		phys_written = (select min(date_action) 
								from asdreportdb.niacombine.auth_action_log_nia aal with (nolock)
								where i.auth_id = aal.auth_id and
								      i.car_id = aal.car_id and
									  aal.auth_action_code in ('912','913') and
									  aal.date_action >= i.decision_date),
		BD_TAT_Req_to_Det,
		
		Recon_Flag = case when exists
							(select * from asdreportdb.niacombine.auth_status_change_nia aschg2 with(nolock)
							 where i.auth_id = aschg2.auth_id and
							i.car_id = aschg2.car_id and
							aschg2.new_auth_status in (
							  'qa', --	Recon Approved
							 'qd', --	Recon Denied
							 'qe'  --	Recon Partial Denied
							 ))
						then 'Y' else 'N' end
   
into #next
from #initial i

--select * from #next where determination = 'Inactivated by Ordering Provider'  car_name = 'HealthAmerica of PA'

--remove all recons
delete from #next 
where Recon_Flag = 'Y';

------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#clinical_receipt_min') IS NOT NULL drop table #clinical_receipt_min

select n.car_id,n.auth_id, count(*) as receipt_occurrences, min(date_action) as clinical_receipt_min --aal.auth_action_code,aac.description, aal.date_action,n.decision_date, (round(adhoc.dbo.datediff_fn(aal.date_action,n.decision_date,'Y','Y')/86400,0)) as BD_TAT_Info_Rcvd_to_Det
     
into #clinical_receipt_min
	from asdreportdb.niacombine.auth_action_log_nia aal with (nolock)
      join #next n on (n.auth_id = aal.auth_id and n.car_id = aal.car_id)
	  join niacore..auth_Action_codes aac on (aal.auth_action_code = aac.auth_action_code)
	  where aal.auth_action_code in (Select key_value from niacore.dbo.timeliness_measurement_event_keyvalues where event_id = 10 and queue_id = 2)
	  and aal.date_action < n.decision_date
	  and aal.date_action > = n.request_Date
      group by n.car_id,n.auth_id--, aal.auth_action_code,aal.date_action,description,n.decision_date


--select * from #clinical_receipt_min

IF OBJECT_ID('tempdb..#clinical_receipt_max') IS NOT NULL drop table #clinical_receipt_max

select n.car_id,n.auth_id, count(*) as receipt_occurrences, max(date_action) as clinical_receipt_max --aal.auth_action_code,aac.description, aal.date_action,n.decision_date, (round(adhoc.dbo.datediff_fn(aal.date_action,n.decision_date,'Y','Y')/86400,0)) as BD_TAT_Info_Rcvd_to_Det
     
into #clinical_receipt_max
	from asdreportdb.niacombine.auth_action_log_nia aal with (nolock)
      join #next n on (n.auth_id = aal.auth_id and n.car_id = aal.car_id)
	  join niacore..auth_Action_codes aac on (aal.auth_action_code = aac.auth_action_code)
	  where aal.auth_action_code in (Select key_value from niacore.dbo.timeliness_measurement_event_keyvalues where event_id = 10 and queue_id = 2)
	  and aal.date_action < n.decision_date
      and aal.date_action > = n.request_Date
	  group by n.car_id,n.auth_id--, aal.auth_action_code,aal.date_action,description,n.decision_date

	  	  
------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#clinical_queue') IS NOT NULL drop table #clinical_queue

select n.car_id, n.auth_id, count(*) as receipt_occurrences, max(date_queued) as queue_date 

into #clinical_queue
from asdreportdb.niacombine.auth_queue_history_arch_nia aqh with (nolock)
  join #next n on (n.auth_id = aqh.auth_id and n.car_id = aqh.car_id)
	 where aqh.queue_code = 'por' and aqh.date_queued < n.decision_date
      group by n.car_id,n.auth_id

--select * from #clinical_receipt order by auth_id
--select * from asdreportdb.niacombine.auth_queue_history_arch_nia aqh with (nolock)
--      join #next n on (n.auth_id = aqy.auth_id and n.car_id = aqh.car_id)
--	 where aqh.queue_code = 'por'
--------------------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#clinical_review') IS NOT NULL drop table #clinical_review

select n.car_id, n.auth_id, count(*) as review_occurrences, max(Date_action) as last_review --,(round(adhoc.dbo.datediff_fn (max(aal.date_action),n.decision_date,'Y','Y')/86400,0)) as BD_TAT_P2P_to_Det
     
into #clinical_review
from asdreportdb.niacombine.auth_action_log_nia aal with (nolock)
      join #next n on (n.auth_id = aal.auth_id and n.car_id = aal.car_id)
	  join niacore..auth_Action_codes aac on (aal.auth_action_code = aac.auth_action_code)
	  where aal.auth_action_code in (  '15',	--Call Transferred for P2P/Organization Determination Outreach Discussion
									   '17',	--P2P/Organization Determination Outreach Discussion Held
									  '969',	--Discussion with alternate clinician held
									 '1040')	--P2P/Organization Determination Outreach Discussion Held with Specialist
		and aal.date_action < n.decision_date
      group by n.car_id,n.auth_id--, aal.auth_action_code,aal.date_action,description,n.decision_date

--select * from #clinical_review order by auth_id


IF OBJECT_ID('tempdb..#clinical_contact') IS NOT NULL drop table #clinical_contact

select n.car_id, n.auth_id, min(Date_action) as clinical_contact
     
into #clinical_contact
from asdreportdb.niacombine.auth_action_log_nia aal with (nolock)
      join #next n on (n.auth_id = aal.auth_id and n.car_id = aal.car_id)
	  join niacore..auth_Action_codes aac on (aal.auth_action_code = aac.auth_action_code)
	  join #clinical_receipt_min c on (c.car_id = aal.car_id and c.auth_id = aal.auth_id)
	  where aal.auth_action_code in (
		Select auth_action_code from niacore.dbo.auth_action_codes
			where (description like '%peer%' or description like '%p2p%') and description like '%fax%' and description like '%success%' or (description like '%OCR%')
	UNION 
		-- successful p2p verbal contact
		Select auth_action_code from niacore.dbo.auth_action_codes
			where peer_discussion_req_met_flag = 1
	UNION 
		-- successful communication of any sort as measured for timeliness
		Select distinct convert(int, key_value) 
			from niacore.dbo.timeliness_measurement_event_keyvalues 
			where queue_id = 2 -- auth_action_codes
			and isnumeric(key_value)=1 -- I always put this here just for safety in case there's some bad data in the keyvalues table
			and event_id in 
				(2,  -- Fax notification to ordering physician
3,  -- Written notification to ordering physician
4,  -- Verbal notification to ordering physician
16,  -- Peer to Peer discussion successful
19,  -- Approval issued at intake
20,  -- Notification that additional information is required
24,  -- RadMD Notification to ordering physician
51,  -- Written notification to ordering physician (Approval)
52,  -- Written notification to ordering physician (Denial)
54,  -- Fax notification to ordering physician (Add'l Information)
55,  -- Fax notification to ordering physician (Unable to Reach - Req for Discussion)
66,  -- Request to speak to NIA Physician by MDO Representative Attempted/Completed
67,  --	Verbal to ordering physician after MDO Representative request to speak to NIA Physician
79,  -- Appeal Ack notification to ordering physician
86,  -- RRR Approval Written notification to ordering physician
87,  -- RRR Denial Written notification to ordering physician
95,	 -- P2P call
100, -- Appeal Approval letter to Ordering Physician
101, -- Appeal Denial letter to Ordering Physician
115, -- P2P Held
131, -- Manual Letter Sent
155, -- Max P2P discussion successful
157  -- Max Clinical Info telephonically
)

	  and aal.date_action > c.clinical_receipt_min)
      group by n.car_id,n.auth_id


--select * from #clinical_contact where car_id = '14'

IF OBJECT_ID('tempdb..#total') IS NOT NULL drop table #total
select 

n.car_name as [car name],
case when n.auth_type = 'Back' then 'Cervical/Spine Surgery'
	 when n.auth_type = 'HKS' then 'HKS Surgery'
	 else n.auth_type
end as [auth type],
[line of business],
n.auth_id, 
case when n.determination in ('Certified', 'Partial Determination') then 'Approved'
	 when n.determination in ('Non-Certified') then 'Disapproved' 
	 else n.determination
end as Outcome, 
--n.auth_id,
--n.status_desc as [status desc],
--n.determination as [determination],
--n.request_date as [request date],
(n.bd_tat_req_to_det) as [BD TAT Req to Det],
--cr.receipt_occurrences as [Clinical Info Occurrences],
--cr.last_receipt as [Last Clinical Info Receipt],
round(adhoc.dbo.datediff_fn(crmin.clinical_receipt_min,cc.clinical_contact,'Y','Y')/86400,0) as [BD TAT Info Rcvd to Contact],
case when n.auth_type <> 'Physical Medicine – Therapy (Physical, Occupational, and Speech), and Chiropractic Care' then (round(adhoc.dbo.datediff_fn(crmax.clinical_receipt_max,n.decision_date,'Y','Y')/86400,0)) 
 else  (round(adhoc.dbo.datediff_fn(cq.queue_date,n.decision_date,'Y','Y')/86400,0)) 
end as [BD TAT Info Rcvd to Det],
--crv.review_occurrences as [Clinical Review Occurrences],
--crv.last_review as [Last Clinical Review],
(round(adhoc.dbo.datediff_fn(crv.last_review,n.decision_date,'Y','Y')/86400,0)) as [BD TAT Rev to Det]--,
--n.decision_date as [decision date],
--n.phys_written as [phys written]

into #total
from #next n
left join #clinical_receipt_min crmin on (n.auth_id = crmin.auth_id and n.car_id = crmin.car_id)
left join #clinical_receipt_max crmax on (n.auth_id = crmax.auth_id and n.car_id = crmax.car_id)
left join #clinical_contact cc on (n.auth_id = cc.auth_id and n.car_id = cc.car_id)
left join #clinical_review crv on (n.auth_id = crv.auth_id and n.car_id = crv.car_id)
left join #clinical_queue cq on (n.auth_id = cq.auth_id and n.car_id = cq.car_id)

group by n.car_name, n.auth_type,n.bd_tat_req_to_det,crmax.clinical_receipt_max,crmin.clinical_receipt_min,n.decision_date,crv.last_review,cq.queue_date, [line of Business], n.auth_id,determination,cc.clinical_contact
--select * from #total where [car name] = 'HealthAmerica of PA' and [auth type] = 'Physical Medicine – Therapy (Physical, Occupational, and Speech), and Chiropractic Care'

--select * from #total

--IF OBJECT_ID('tempdb..#detail') IS NOT NULL drop table #detail

--select i.*, last_receipt as clinical_rcvd_date, last_review as review_date

--into #detail
--from #initial i
--left join #clinical_receipt cr on (i.auth_id = cr.auth_id)
--left join #clinical_review crv on (i.auth_id = crv.auth_id)

--select * from #detail where car_name = 'Aetna'


IF OBJECT_ID('tempdb..#final') IS NOT NULL drop table #final

select

[car name],
[auth type],
FORMAT(count(*),'N0') as total1,
FORMAT(sum(case when [BD TAT Req to Det] < = 2
		then 1 else 0
		end) ,'N0') as Ttl_2BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 2  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_2BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] < = 3
		then 1 else 0
		end) ,'N0') as Ttl_3BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 3  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_3BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] < = 4
		then 1 else 0
		end) ,'N0') as Ttl_4BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 4  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_4BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] > 4
		then 1 else 0
		end) ,'N0') as Ttl_Over_4BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] > 4 then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_Over_4BD_TAT1,

FORMAT(count([BD TAT Info Rcvd to Contact]),'N0') as totalcontact,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_2BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_3BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_4BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TATC,

FORMAT(count([BD TAT Info Rcvd to Det]),'N0') as total2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_2BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_3BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TAT21,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_4BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TAT2,

FORMAT(count([BD TAT Rev to Det]),'N0') as total3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_2BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_3BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_4BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TAT3

into #final
from #total

group by [car name],[auth type]
order by [car name],[auth type]



IF OBJECT_ID('tempdb..#final2') IS NOT NULL drop table #final2

select

[auth type],
[line of business],
FORMAT(count(*),'N0') as total1,
FORMAT(sum(case when [BD TAT Req to Det] < = 2
		then 1 else 0
		end) ,'N0') as Ttl_2BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 2  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_2BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] < = 3
		then 1 else 0
		end) ,'N0') as Ttl_3BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 3  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_3BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] < = 4
		then 1 else 0
		end) ,'N0') as Ttl_4BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 4  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_4BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] > 4
		then 1 else 0
		end) ,'N0') as Ttl_Over_4BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] > 4 then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_Over_4BD_TAT1,

FORMAT(count([BD TAT Info Rcvd to Contact]),'N0') as totalcontact,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_2BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_3BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_4BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TATC,

FORMAT(count([BD TAT Info Rcvd to Det]),'N0') as total2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_2BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_3BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TAT21,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_4BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TAT2,

FORMAT(count([BD TAT Rev to Det]),'N0') as total3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_2BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_3BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_4BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TAT3

into #final2
from #total

group by [auth type],[line of business]
order by [auth type],[line of business]

IF OBJECT_ID('tempdb..#final3') IS NOT NULL drop table #final3

select

[auth type],
outcome,
FORMAT(count(*),'N0') as total1,
FORMAT(sum(case when [BD TAT Req to Det] < = 2
		then 1 else 0
		end) ,'N0') as Ttl_2BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 2  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_2BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] < = 3
		then 1 else 0
		end) ,'N0') as Ttl_3BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 3  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_3BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] < = 4
		then 1 else 0
		end) ,'N0') as Ttl_4BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 4  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_4BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] > 4
		then 1 else 0
		end) ,'N0') as Ttl_Over_4BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] > 4 then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_Over_4BD_TAT1,

FORMAT(count([BD TAT Info Rcvd to Contact]),'N0') as totalcontact,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_2BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_3BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_4BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TATC,

FORMAT(count([BD TAT Info Rcvd to Det]),'N0') as total2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_2BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_3BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TAT21,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_4BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TAT2,

FORMAT(count([BD TAT Rev to Det]),'N0') as total3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_2BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_3BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_4BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TAT3

into #final3
from #total

group by [auth type], outcome 
order by [auth type], outcome 


IF OBJECT_ID('tempdb..#final4') IS NOT NULL drop table #final4

select

[auth type],
FORMAT(count(*),'N0') as total1,
FORMAT(sum(case when [BD TAT Req to Det] < = 2
		then 1 else 0
		end) ,'N0') as Ttl_2BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 2  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_2BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] < = 3
		then 1 else 0
		end) ,'N0') as Ttl_3BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 3  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_3BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] < = 4
		then 1 else 0
		end) ,'N0') as Ttl_4BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] < = 4  then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_4BD_TAT1,
FORMAT(sum(case when [BD TAT Req to Det] > 4
		then 1 else 0
		end) ,'N0') as Ttl_Over_4BD_TAT1,
cast(cast(sum(case when [BD TAT Req to Det] > 4 then 1 else 0 end) as decimal)/cast(count(*) as decimal)  as decimal (10,3)) as pct_Over_4BD_TAT1,

FORMAT(count([BD TAT Info Rcvd to Contact]),'N0') as totalcontact,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_2BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_3BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_4BD_TATC,
FORMAT(sum(case when [BD TAT Info Rcvd to Contact] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TATC,
cast(cast(sum(case when [BD TAT Info Rcvd to Contact] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Contact]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TATC,

FORMAT(count([BD TAT Info Rcvd to Det]),'N0') as total2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_2BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_3BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TAT21,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_4BD_TAT2,
FORMAT(sum(case when [BD TAT Info Rcvd to Det] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TAT2,
cast(cast(sum(case when [BD TAT Info Rcvd to Det] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Info Rcvd to Det]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TAT2,

FORMAT(count([BD TAT Rev to Det]),'N0') as total3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 2
		then 1 else 0
		end),'N0') as Ttl_2BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 2  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_2BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 3
		then 1 else 0
		end),'N0') as Ttl_3BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 3  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_3BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] < = 4
		then 1 else 0
		end),'N0') as Ttl_4BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] < = 4  then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_4BD_TAT3,
FORMAT(sum(case when [BD TAT Rev to Det] > 4
		then 1 else 0
		end),'N0') as Ttl_Over_4BD_TAT3,
cast(cast(sum(case when [BD TAT Rev to Det] > 4 then 1 else 0 end) as decimal)/cast(nullif(count([BD TAT Rev to Det]),0) as decimal) as decimal (10,3)) as pct_Over_4BD_TAT3

into #final4
from #total

group by [auth type] 
order by [auth type] 


select * 

from #final



select * 

from #final2
order by [auth type]

select * 

from #final3
order by [auth type]

select * 

from #final4
order by [auth type]

---detail tab

select * from #total --where [BD TAT Info Rcvd to Contact] is not null


--select * 
--into adhoc.dbo.Provider_Experience_TAT_Details
--from #total
--order by [car name],[auth type]
--drop table  adhoc.dbo.Provider_Experience_TAT_Details
