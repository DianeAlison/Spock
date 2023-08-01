-- Use nile-r2 

/* declare local variables */
declare @car_id integer, @start_date datetime, @end_date datetime 

IF OBJECT_ID('tempdb..#initial') IS NOT NULL drop table #initial
IF OBJECT_ID('tempdb..#initial_expired_removed') IS NOT NULL drop table #initial_expired_removed
IF OBJECT_ID('tempdb..#main') IS NOT NULL drop table #main
IF OBJECT_ID('tempdb..#casebreakdown') IS NOT NULL drop table #casebreakdown
IF OBJECT_ID('tempdb..#radbreakdown') IS NOT NULL drop table #radbreakdown

/* assign values to local variables */
select	--@car_id =		'67', --43 = Highmark
	@start_date = '12/06/2020', --'12/01/2015'
	@end_date = '12/06/2020'

select distinct
	datepart(yyyy,a.date_call_rcvd) as year,
	--datepart(yyyy,aschg.date_changed) as year,
	--datepart(mm,aschg.date_changed) as month,
	a.car_id, 
	a.member_id,
	a.auth_id,
	a.proc_desc,
	cpt.cpt4_descr,
	ec.exam_cat_desc,
	a.combo_flag,
	--aschg.date_changed as final_determination_date,
	case when a.authorization_type_id = 6 then ip.label
		 when a.authorization_type_id = 16 and a.proc_desc = 'Other Phys Med Services' then 'Therapy-PT'
		  when a.authorization_type_id = 16 and a.proc_desc = 'Physician Services' then 'Therapy-PT'
		 when a.authorization_type_id = 16 and a.proc_desc like 'Phys% Therapy%' then 'Therapy-PT'
		 when a.authorization_type_id = 16 and a.proc_desc = 'Occupational Therapy' then 'Therapy-OT'
		 when a.authorization_Type_id = 16 then a.proc_desc
		else at.description 
	end as auth_type,
	case when a.is_user_id <> 1998 then 'CallCtr' else 'RadMD' end as Method,
	a.contact_type_id,
	ec.exam_cat_id
	--Auth_Expired_Flag = case when exists (select a1.auth_id from asdreportdb.niacombine.authorizations_nia a1
	--									join asdreportdb.niacombine.auth_action_log_nia aal with(nolock) on (aal.car_id = a1.car_id and a1.auth_id = aal.auth_id)
	--									where a.car_id = a1.car_id and a.member_id = a1.member_id 
	--									and aal.auth_action_code = '36' --	36           Auth expired.  Status Admin Withdrawn.				
	--									and a1.proc_desc = a.proc_desc
	--									and aal.date_action between dateadd(dd,-60,aschg.date_changed) and aschg.date_changed) 
	--								then 'Yes' else 'No' end,
	--Extend_validity_flag = case when exists (select a1.auth_id from asdreportdb.niacombine.authorizations_nia a1
	--									join asdreportdb.niacombine.auth_action_log_nia aal with(nolock) on (aal.car_id = a1.car_id and a1.auth_id = aal.auth_id)
	--									where a.car_id = a1.car_id and a.member_id = a1.member_id 
	--									and aal.auth_action_code = '751' --	751          Allow to extend validity period				
	--									and a1.proc_desc = a.proc_desc
	--									and aal.date_action between dateadd(dd,-60,aschg.date_changed) and aschg.date_changed) 
	--								then 'Yes' else 'No' end
									
		
into #initial	  
From asdreportdb.niacombine.authorizations_nia a WITH (NOLOCK)
	--join asdreportdb.niacombine.auth_status_change_nia aschg WITH (NOLOCK) on (a.auth_id = aschg.auth_id and a.car_id = aschg.car_id)
	--join niacore..auth_status_codes ascd WITH (NOLOCK) on (aschg.new_auth_status = ascd.auth_status)
	left join adhoc..ipm_surgery ip with (nolock) on (replace(replace(a.proc_desc,'(left)',''),'(right)','') = ip.ipm_proc)
	join niacore..authorization_types at WITH (NOLOCK) on (a.authorization_type_id = at.authorization_type_id)
	join niacore..cpt4_codes cpt with (nolock) on (a.cpt4_code = cpt.cpt4_code)
    join niacore..exam_category ec with (nolock) on (cpt.exam_Cat_id = ec.exam_cat_id)      
	join niacore..exam_modality_categories emc with (nolock) on (ec.exam_modality_cat_id = emc.exam_modality_cat_id)

where a.date_call_rcvd >= @start_date 
and a.date_call_rcvd < dateadd(dd, 1, @end_date)
and at.business_division_id = '1' 	  


group by 
	a.date_call_rcvd,
	a.proc_desc,
	cpt.cpt4_descr,
	ec.exam_cat_desc,
	a.authorization_type_id,
	--aschg.date_changed,
	a.car_id, 
	a.member_id,
	a.auth_id,
	at.description,
	a.is_user_id,
	a.contact_type_id,
	a.combo_flag,
	ip.Label,
	ec.exam_cat_id

update i

set auth_type = 'Cardiology'

from #initial i
where exam_cat_id in (5,24,22,17,10,15,31);


	--5		DX Nuclear Medicine
	--24	Cardiac Catheterization
	--22	CTA (Computed Tomography Angiography)
	--17	Echocardiography
	--10	Nuclear Cardiology
	--15	Stress Echocardiography
	--31	Interventional Cardiology

	--ascd.auth_outcome,
	--ascd.auth_status_type
	

--delete from #initial where auth_expired_flag = 'Yes'

--delete from #initial where Extend_validity_flag = 'Yes'
	
select * from #initial where auth_type is null

--select * from adhoc..ipm_surgery
--insert into adhoc..ipm_surgery

----------------------------------------------------------------------------------


--Total Cases 
select 
		i.year,
		--i.month,
		--count((convert(varchar(3),i.car_id))+i.auth_id) as Total_Cases,
		count(distinct(convert(varchar(3),i.car_id))+i.auth_id) as Total_Cases,
       sum(case when i.method  = 'RadMD' then 1 else 0 end) as Total_Radmd,
	  cast(cast(sum(case when i.method  = 'RadMD' then 1 else 0 end) as decimal(9,0)) /count(distinct(convert(varchar(3),i.car_id))+i.auth_id) as decimal(4,3)) as Percent_RadMd
into #Main
from #initial i
group by year
--group by month
--------------------------------------------------------
--Cases by auth type
select
	i.year,
	--i.month,
	--count((convert(varchar(3),i.car_id))+i.auth_id) as Cases, 
	count(distinct(convert(varchar(3),i.car_id))+i.auth_id) as Cases, 
	m.Total_cases,
	cast(cast(count(distinct(convert(varchar(3),i.car_id))+i.auth_id) as decimal(9,0)) / m.Total_cases as decimal(4,3)) as Prct_Case,
    i.auth_type

into #casebreakdown
from #initial i
	--join #main m with (nolock) on (m.month = i.month)
	join #main m with (nolock) on (m.year = i.year)
group by auth_type, 
i.year,
--i.month,
m.total_cases
--------------------------------------------------------
--RadMD Volume by Auth Type
select 
	  i.year,
	  --i.month,
	  sum(case when i.method = 'Radmd' then 1 else 0 end) as Type,
	  m.Total_Radmd,
		cast(cast(sum(case when i.method = 'Radmd' then 1 else 0 end) as decimal(9,0)) / m.Total_radmd as decimal(4,3)) as Prct_Rad,
	i.auth_type

into #radbreakdown
from #initial i
	--join #main m with (nolock) on (m.month = i.month)
	join #main m with (nolock) on (m.year = i.year)
group by auth_type, 
i.year,
--i.month,
 m.Total_Radmd
--------------------------------------------------------------
select 'Total Cases by Auth Type'

select 
cases,total_cases, prct_case, auth_type
from #casebreakdown
group by year,cases,total_cases, prct_case, auth_type
order by auth_type

Select 'Rad Md Cases by Auth Type'

select 
type,total_radmd, prct_rad, auth_type
from #radbreakdown
group by year,type,total_radmd, prct_rad, auth_type
order by auth_type


--select * from niacore..cpt4_codes
--select * from exam_category
--select * from exam_modality_categories
--select * from exam_modality_group_types
