FACT.Temp:
Load
    *
;
SQL
?
?
?
IF OBJECT_ID('adhoc.dbo.initial') IS NOT NULL drop table adhoc.dbo.initial
IF OBJECT_ID('adhoc.dbo.main_1915') IS NOT NULL drop table adhoc.dbo.main_1915
IF OBJECT_ID('adhoc.dbo.main_MD') IS NOT NULL drop table adhoc.dbo.main_MD
IF OBJECT_ID('adhoc.dbo.summary_1915') IS NOT NULL drop table adhoc.dbo.summary_1915
IF OBJECT_ID('adhoc.dbo.summary_MD') IS NOT NULL drop table adhoc.dbo.summary_MD
IF OBJECT_ID('adhoc.dbo.final_1915') IS NOT NULL drop table adhoc.dbo.final_1915
IF OBJECT_ID('adhoc.dbo.final_MD') IS NOT NULL drop table adhoc.dbo.final_MD
?
select
    member_id
into adhoc.dbo.initial
from centenenh..members
Where
    SUBSTRING(client_member_id, 0, charindex('-', client_member_id, 0)) in ($(vMedicaid))
?
?
select i.*, 
a.auth_id,
case when at.description ='Cardiology' then 'Radiology' else at.description end as auth_type,
aschg.date_changed, ascd.auth_outcome
into adhoc.dbo.main_1915
from adhoc.dbo.initial i
join centenenh..authorizations a  on (a.member_id = i.member_id)
join niacore..authorization_types at  on (at.authorization_type_id =a.authorization_type_id)
left outer join centenenh..auth_status_change aschg with(nolock) on (a.auth_id = aschg.auth_id)
left outer join niacore..auth_status_codes ascd with(nolock) on (aschg.new_auth_status = ascd.auth_status)
?
?
where ascd.final_status_flag = '1' -- and ascd.auth_outcome <> 'W'
and aschg.date_changed between '$(vStartDate)' and dateadd(d,1,'$(vEndDate)')
?
select a.auth_id,
case when at.description ='Cardiology' then 'Radiology' else at.description end as auth_type,
aschg.date_changed, ascd.auth_outcome
into adhoc.dbo.main_MD
from centenenh..authorizations a 
left join centenenh..members m  on (m.member_id = a.member_id) 
join niacore..authorization_types at  on (at.authorization_type_id =a.authorization_type_id)
join niacore..health_plan hp  on (hp.plan_id = m.plan_id)
left outer join centenenh..auth_status_change aschg with(nolock) on (a.auth_id = aschg.auth_id)
left outer join niacore..auth_status_codes ascd with(nolock) on (aschg.new_auth_status = ascd.auth_status)
where ascd.final_status_flag = '1' -- and ascd.auth_outcome <> 'W'
and aschg.date_changed between '$(vStartDate)' and dateadd(d,1,'$(vEndDate)')
and hp.line_of_business = 'MD'
?
?
select auth_type, count(m.auth_id) as Requested,
sum (case when auth_outcome = 'A' then '1' else 0 end) as Approved,
sum (case when auth_outcome = 'D' then '1' else 0 end) as Denied,
sum (case when auth_outcome = 'W' then '1' else 0 end) as Withdrawn
?
into adhoc.dbo.summary_1915
from adhoc.dbo.main_1915 m
group by auth_type
?
?
select auth_type, count(m.auth_id) as Requested,
sum (case when auth_outcome = 'A' then '1' else 0 end) as Approved,