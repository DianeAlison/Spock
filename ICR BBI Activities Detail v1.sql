set nocount on

declare
 @start_date datetime
,@end_date datetime

select
 @start_date = DATEADD(d,-1,DATEDIFF(d, 0,GETDATE()))
,@end_date = DATEADD(d,-1,DATEDIFF(d, 0,GETDATE()))
-- @start_date = '5/8/19'
--,@end_date = '5/8/19'

if object_id('adhoc..temppcr1', 'U') is not null drop table adhoc..temppcr1
select
 aschg.car_id
,hc.car_name
,aschg.auth_id
,aschg.date_changed
,aschg.new_auth_status
,aschg.user_name
,ascd.status_desc
,a.proc_desc
,a.combo_flag
,ascd.final_status_flag
,ascd.auth_outcome
,change_date = convert(varchar(12), aschg.date_changed, 101)
,auth_type_id = a.authorization_type_id
,auth_type_name = at.description
into
 adhoc..temppcr1
from
		ASDReportdb.niacombine.auth_status_change_nia aschg with (nolock)
join niacore..auth_status_codes ascd with (nolock) on (aschg.new_auth_status = ascd.auth_status)
join niacore..health_carrier hc with (nolock) on (aschg.car_id = hc.car_id)
join ASDReportdb.niacombine.authorizations_NIA a with (nolock) on (aschg.car_id = a.car_id and aschg.auth_id = a.auth_id)
left join niacore..authorization_types at WITH (NOLOCK) on (a.authorization_type_id = at.authorization_type_id)
where
		aschg.date_changed >= @start_date
and aschg.date_changed <dateadd(dd,1,@end_date)
and aschg.user_name in (select log_id from niacore..is_users iu where iu.type = 'ur')
order by date_changed
--select * from adhoc..temppcr1

------------------------------------------------------------------------------------------------STEP 2: Get Clinical Rationale for the denials
if object_id('adhoc..temppcr2', 'U') is not null drop table adhoc..temppcr2
select
 t.*
,clinical_rationale = (select note from ASDReportdb.niacombine.auth_notes_nia an
													where t.auth_id = an.auth_id
													and t.car_id = an.car_id
													and note_type_id = 'CR'
													and t.auth_outcome = 'D'
													and t.final_status_flag = 1
													and date_entered = (select min(date_entered) from ASDReportdb.niacombine.auth_notes_nia an1 with (nolock)
																																where an1.auth_id = an.auth_id
																																and an1.car_id = an.car_id
																																and an1.note_type_id = an.note_type_id
																																and an1.note_type_id = 'CR'
																																and an1.note <> ' '))
into
 adhoc..temppcr2
from
 adhoc..temppcr1 t
order by
 car_id
,auth_id
--select * from adhoc..temppcr2

------------------------------------------------------------------------------------------------STEP 3: ADD AN INDICATOR FOR ACTION CODE 1062 AND ALSO DETERMINE THE FIRST 1062 DATE
if object_id('adhoc..temppcr3', 'U') is not null drop table adhoc..temppcr3
select
 car_id
,car_name
,auth_id
,combo_flag
,proc_desc
,user_name
,date_changed
,status_desc
,clinical_rationale
,a1062_flag = case when exists
										(select aal.auth_id from ASDReportdb.niacombine.auth_action_log_NIA aal with (nolock)
																		where aal.auth_id = a.auth_id and aal.car_id = a.car_id and aal.auth_action_code = '1062') --OneTouch adjudication applied
								then 1 else 0
								end
,min_a1062_date = (select min(date_entered)	from ASDReportdb.niacombine.auth_action_log_NIA aal with (nolock)
																			where aal.auth_id = a.auth_id and aal.car_id = a.car_id and aal.auth_action_code = '1062') --OneTouch adjudication applied
,a1128_flag = case when exists
										(select aal.auth_id from ASDReportdb.niacombine.auth_action_log_NIA aal with (nolock)
																		where aal.auth_id = a.auth_id and aal.car_id = a.car_id and aal.auth_action_code = '1128') --System applied previous approval
								then 1 else 0
								end
,min_a1128_date = (select min(date_entered) from ASDReportdb.niacombine.auth_action_log_NIA aal with (nolock)
																			where aal.auth_id = a.auth_id and aal.car_id = a.car_id and aal.auth_action_code = '1128') --System applied previous approval
,change_date
,auth_type_id
,auth_type_name
into
 adhoc..temppcr3
from
 adhoc..temppcr2 a
order by
 date_changed
 --select * from adhoc..temppcr3

------------------------------------------------------------------------------------------------STEP 4: GET DATE DIFF BETWEEN STATUS CHANGE AND MIN 1062 DATE AND DETERMINATION TAKES PLACE RIGHT BEFORE ACTION CODE 1062
if object_id('adhoc..temppcr4','U') is not null drop table adhoc..temppcr4
select
 car_id
,car_name
,auth_id
,combo_flag
,proc_desc
,user_name
,date_changed
,status_desc
,clinical_rationale
,a1062_flag
,min_a1062_date
,minutes_determ_to_1062 = datediff(minute,date_changed, min_a1062_date)
,a1128_flag
,min_a1128_date
,minutes_determ_to_1128 = datediff(minute,date_changed, min_a1128_date)
,change_date
,auth_action = 'No'
,auth_type_id
,auth_type_name
into
 adhoc..temppcr4
from
 adhoc..temppcr3 t
--select * from adhoc..temppcr3

----------------------------------------------------------------------------------------------STEP 5: LOOK AT ACTION CODE DATA AND DO THE SAME STEPS AS ABOVE
if object_id('adhoc..temppcraction','U') is not null drop table adhoc..temppcraction
select
 aschg.car_id
,hc.car_name
,aschg.auth_id
,date_changed = aschg.date_entered
,aschg.auth_action_code
,iu.log_id
,ascd.description as 'status_desc'
,a.proc_desc
,a.combo_flag
,change_date = convert(varchar(12),aschg.date_entered,101)
,auth_type_id = a.authorization_type_id
,auth_type_name = at.description
into
 adhoc..temppcraction
from
		ASDReportdb.niacombine.auth_action_log_nia aschg with (nolock)
join niacore..auth_action_codes ascd with (nolock) on (aschg.auth_action_code = ascd.auth_action_code)
join niacore..health_carrier hc with (nolock) on (aschg.car_id = hc.car_id)
join ASDReportdb.niacombine.authorizations_NIA a with (nolock) on (aschg.car_id = a.car_id and aschg.auth_id = a.auth_id)
join niacore..is_users iu on (aschg.is_user_id = iu.is_user_id)
left join niacore..authorization_types at WITH (NOLOCK) on (a.authorization_type_id = at.authorization_type_id)
where
		aschg.date_entered  >= @start_date
and aschg.date_entered <dateadd(dd,1,@end_date)
and iu.log_id in (select log_id from niacore..is_users iu2 where iu2.type = 'ur')
order by
date_entered
--select * from adhoc..temppcraction

------------------------------------------------------------------------------------------------STEP 6: ADD AN INDICATOR FOR ACTION CODE 1062 AND DETERMINE THE FIRST 1062 DATE
if object_id('adhoc..temppcraction2','U') is not null drop table adhoc..temppcraction2
select
 car_id
,car_name
,auth_id
,combo_flag
,proc_desc
,user_name = log_id
,date_changed
,status_desc
,clinical_rationale = ' '
,a1062_flag = case when exists
										(select aal.auth_id from ASDReportdb.niacombine.auth_action_log_NIA aal with (nolock)
																		where aal.auth_id = a.auth_id and aal.car_id = a.car_id and aal.auth_action_code = '1062') --OneTouch adjudication applied
						then 1 else 0
						end
,min_a1062_date = (select min(date_entered) from ASDReportdb.niacombine.auth_action_log_NIA aal with (nolock)
																			where aal.auth_id = a.auth_id and aal.car_id = a.car_id and aal.auth_action_code = '1062') --OneTouch adjudication applied
,a1128_flag = case when exists
										(select aal.auth_id from ASDReportdb.niacombine.auth_action_log_NIA aal with (nolock)
																		where aal.auth_id = a.auth_id and aal.car_id = a.car_id and aal.auth_action_code = '1128') --System applied previous approval
						then 1 else 0
						end
,min_a1128_date = (select min(date_entered) from ASDReportdb.niacombine.auth_action_log_NIA aal with (nolock)
																			where aal.auth_id = a.auth_id and aal.car_id = a.car_id and aal.auth_action_code = '1128') --System applied previous approval
,change_date
,auth_type_id
,auth_type_name
into
 adhoc..temppcraction2
from
 adhoc..temppcraction a
order by
 date_changed
--select * from adhoc..temppcraction2

------------------------------------------------------------------------------------------------STEP 7: GET DATE DIFF BETWEEN STATUS CHANGE AND MIN 1062 DATE AND DETERMINATION TAKES PLACE RIGHT BEFORE ACTION CODE 1062
if object_id('adhoc..temppcraction3','U') is not null drop table adhoc..temppcraction3
select
 car_id
,car_name
,auth_id
,combo_flag
,proc_desc
,user_name
,date_changed
,status_desc
,clinical_rationale
,a1062_flag
,min_a1062_date
,minutes_determ_to_1062 = datediff(minute,date_changed, min_a1062_date)
,a1128_flag
,min_a1128_date
,minutes_determ_to_1128 = datediff(minute,date_changed, min_a1128_date)
,change_date
,auth_action = 'Yes'
,auth_type_id
,auth_type_name
into
 adhoc..temppcraction3
from
 adhoc..temppcraction2 t
--select * from adhoc..temppcraction3

----------------------------------------------------------------------------------------------STEP 8: UNIONED RESULTS
if object_id('adhoc..temptest_929','U') is not null drop table adhoc..temptest_929
select
 *
into
 adhoc..temptest_929
from
 adhoc..temppcr4
where
		((minutes_determ_to_1062 <> 0 and minutes_determ_to_1062 <> 1)
or		minutes_determ_to_1062 is null)
and ((minutes_determ_to_1128 <> 0 and minutes_determ_to_1128 <> 1)
or		minutes_determ_to_1128 is null)

union

select
 *
from
 adhoc..temppcraction3
where
		((minutes_determ_to_1062 <> 0 and minutes_determ_to_1062 <> 1)
or		minutes_determ_to_1062 is null)
and ((minutes_determ_to_1128 <> 0 and minutes_determ_to_1128 <> 1)
or		minutes_determ_to_1128 is null)
order by
 date_changed
--select * from adhoc..temptest_929

------------------------------------------------------------------------------------------------STEP 9: RETURN DETAIL
select
 *
from
 adhoc..temptest_929
order by
 user_name
,date_changed

------------------------------------------------------------------------------------------------STEP 10: DROP TEMP TABLES
drop table adhoc..temppcr1
drop table adhoc..temppcr2
drop table adhoc..temppcr3
drop table adhoc..temppcr4
drop table adhoc..temppcraction
drop table adhoc..temppcraction2
drop table adhoc..temppcraction3
drop table adhoc..temptest_929