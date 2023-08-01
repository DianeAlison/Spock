

select	auth_id, phys_name, report_translation,
		withdrawal_reason = case when report_translation = 'Admin Withdrawn' then 
							(select top 1 aac.description from absolute..auth_action_log aal, niacore..auth_action_codes aac 
							 where aal.auth_action_code = aac.auth_action_code and aal.auth_id = r.auth_id 
							 and (aac.description like '%Admin Withdrawn.%' or aac.description like '%Allow to extend validity period%')) else 'Not Admin Withdrawal' end
--into	#temp
from	aetnahealth r
where	current_historical = 'Current'
		and outcome_category = 'Admin Denial'


drop table #e

select	a.auth_id,
		aschg.new_auth_status,
		ascd.status_desc,
		ascd.report_translation,
		withdrawal_reason = case when ascd.report_translation = 'Admin Withdrawn' then 
							(select top 1 aac.description from auth_action_log aal, niacore..auth_action_codes aac 
							 where aal.auth_action_code = aac.auth_action_code and aal.auth_id = a.auth_id 
							 and (aac.description like '%Admin Withdrawn.%' or aac.description like '%Allow to extend validity period%')) else 'Not Admin Withdrawal' end

into	#e
from	authorizations a
		left outer join auth_status_change aschg with(nolock) on (a.auth_id = aschg.auth_id 
					and aschg.date_changed = (select max(aschg2.date_changed) from auth_status_change aschg2 with(nolock)
												join niacore..auth_status_codes ascd2 with(nolock) on (aschg2.new_auth_status = ascd2.auth_status)
												where aschg.auth_id = aschg2.auth_id
												and ascd2.final_status_flag = 1))
												
		left outer join niacore..auth_status_codes ascd with(nolock) on (aschg.new_auth_status = ascd.auth_status)
		left outer join niacore..auth_outcomes aout with(nolock) on (ascd.auth_outcome = aout.auth_outcome)

where	aschg.new_auth_status = 'rw'

select * from #e



select	aal.auth_action_code,
		aac.description,
		count(e.auth_id)
		
from	#e e
		join auth_action_log aal with(nolock) on (e.auth_id = aal.auth_id)
		join niacore..auth_action_codes aac with(nolock) on (aal.auth_action_code = aac.auth_action_code)
		
where	aac.description like '%Admin Withdrawn.%' 
		or aac.description like '%Allow to extend validity period%'
		
group by aal.auth_action_code,
		aac.description