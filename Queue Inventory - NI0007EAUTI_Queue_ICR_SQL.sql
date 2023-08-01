--Use nile-r2
/*5/21/18 changed from ('dlr','esw','irq','icr','mcb','mib','sgc','sgm','sg6','sg8','sgu',
			'sg1','sg5','sg7','sg3','v04','v01','v05','v02','v03','pm1','ro2','rcr','riq','ro3','uma','aum') */

	use adhoc

	/* declare local variables */
	declare @start_date datetime, @end_date datetime ,@car_id int

	/* assign values to local 5ariables */
	--set	@start_date = DATEADD(MM,0,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) --1st of current month. 
	 set		@start_date = '10/01/2020' --'12/01/2015'
	set		@end_date = '10/31/2020 23:59:59'  --'12/31/2015'

	--set @end_date = (DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0)) --MondayOfCurrentWeek
	--set @end_date = Dateadd(ss, (DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0)),-1) --MondayOfCurrentWeek

	--(dateadd(day,1-datepart(dw, getdate()), getdate())

	--select @car_id,@start_date,@end_date

IF OBJECT_ID('adhoc.dbo.Queue_ICR1') IS NOT NULL drop table adhoc.dbo.Queue_ICR1

	select  aqh.auth_id, 
			aqh.car_id, 
			hc.car_name,
			hp.line_of_business,
			hpg.description as hpg_description,
			hp.plan_name,
			ex.exam_cat_desc,
			a.proc_desc,
			queue_code = aqh.report_translation,  --aqh.queue_code,  ---Changed to use report_translation CB 05/31/2018
			queue_description = iq.description, 
			
			--case when aqh.queue_code in ('dlr','esw','irq','icr','mib','sgc','sgu','sg1','v04','v01',
			--'v05','v02','v03','pm1','ro2','rcr','riq','ro3','aum')  
			-- Then 'icr'
			--	else aqh.queue_code end as updated_queue_code,
			
			--updated_queue_code = 'icr',  --Need to understand what this field means and why it is here.
			
			aqh.isfinal, 
			aqh.date_queued, 
			at.authorization_type_id,
			frt.Description as risk_type,
			Auth_Type_Name = at.description,
			getdate() as Report_Date,
			aqh2.queue_code as outbound_queue_code

	into adhoc.dbo.Queue_ICR1

	from asdreportdb.niacombine.auth_queue_history_nia aqh WITH (NOLOCK)
		 join niacore..informa_queues iq WITH (NOLOCK) on (aqh.report_translation = iq.queue_code)   ---Changed to use report_translation CB 05/31/2018
		 join asdreportdb.niacombine.authorizations_nia a WITH (NOLOCK) on (aqh.car_id = a.car_id and aqh.auth_id = a.auth_id)
		 join niacore..authorization_types at WITH (NOLOCK) on (a.authorization_type_id = at.authorization_type_id)
		 join asdreportdb.niacombine.members_nia m WITH (NOLOCK) on (a.member_id = m.member_id and a.car_id = m.car_id)
		 join niacore..health_carrier hc WITH (NOLOCK) on (aqh.car_id = hc.car_id)
		 join niacore..health_plan hp WITH (NOLOCK) on (m.plan_id = hp.plan_id)
		 join niacore..health_plan_groups hpg WITH (NOLOCK) on (hp.health_plan_group_id = hpg.health_plan_group_id)
		 join niacore..cpt4_codes cpt WITH (NOLOCK) on (a.cpt4_code = cpt.cpt4_code)
		 join niacore..exam_category ex WITH (NOLOCK) on (cpt.exam_cat_id = ex.exam_cat_id)
		 join niacore..funding_risk_types frt with (nolock) on (frt.funding_risk_Type = hp.funding_risk_type)
		 
		 join adhoc.dbo.Queue_Codes_for_ICR q with(nolock) on (aqh.queue_code = q.queue_code)

	--JOIN TO GET THE "NEXT" DATE QUEUED
		 left join  asdreportdb.niacombine.auth_queue_history_nia aqh2 WITH(NOLOCK)  on (aqh.auth_id = aqh2.auth_id and aqh.car_id = aqh2.car_id
						and aqh2.date_queued = (select min(aqh3.date_queued) 
							from   asdreportdb.niacombine.auth_queue_history_nia aqh3 WITH(NOLOCK) 
							where aqh3.auth_id = aqh.auth_id and aqh3.car_id = aqh.car_id
							and aqh3.date_queued > aqh.date_queued))    ---added to resolve issue with FHS MG 6/8/15



	where 
	aqh.date_queued >= @start_date 
	and aqh.date_queued < @end_date
	--and aqh.auth_id = '20120249'
	--and aqh.queue_code in ('dlr','esw','irq','icr','mib','sgc','sgu','sg1','v04','v01',
	--		'v05','v02','v03','pm1','ro2','rcr','riq','ro3','aum') 
	and (aqh2.queue_code is NULL
	or aqh2.queue_code <> 'fhs')  ---added to resolve issue with FHS MG 6/8/15
	and at.business_division_id = '1'   ---added to remove BH cases MG 7/18/16
			
	UNION ALL

	select  aqh.auth_id, 
			aqh.car_id, 
			hc.car_name,
			hp.line_of_business,
			hpg.description as hpg_description,
			hp.plan_name,
			ex.exam_cat_desc,
			a.proc_desc,
			queue_code = aqh.report_translation,  ----aqh.queue_code,  ---Changed to use report_translation CB 05/31/2018
			queue_description = iq.description, 
			
			--case when aqh.queue_code in ('dlr','esw','irq','icr','mib','sgc','sgu','sg1','v04','v01',
			--'v05','v02','v03','pm1','ro2','rcr','riq','ro3','aum') 
			-- Then 'icr'
			--	else aqh.queue_code end as updated_queue_code,
				
			--updated_queue_code = 'icr',  --Need to understand what this field means and why it is here.
			
			aqh.isfinal, 
			aqh.date_queued, 
			at.authorization_type_id,
			frt.Description as risk_type,
			Auth_Type_Name = at.description,
			getdate() as Report_Date,
	    aqh2.queue_code as outbound_queue_code

	from asdreportdb.niacombine.auth_queue_history_arch_nia aqh WITH (NOLOCK)
		 join niacore..informa_queues iq WITH (NOLOCK) on (aqh.report_translation = iq.queue_code)   ---Changed to use report_translation CB 05/31/2018
		 join asdreportdb.niacombine.authorizations_nia a WITH (NOLOCK) on (aqh.car_id = a.car_id and aqh.auth_id = a.auth_id)
		 join niacore..authorization_types at WITH (NOLOCK) on (a.authorization_type_id = at.authorization_type_id)
		 join asdreportdb.niacombine.members_nia m WITH (NOLOCK) on (a.member_id = m.member_id and a.car_id = m.car_id)
		 join niacore..health_carrier hc WITH (NOLOCK) on (aqh.car_id = hc.car_id)
		 join niacore..health_plan hp WITH (NOLOCK) on (m.plan_id = hp.plan_id)
		 join niacore..health_plan_groups hpg WITH (NOLOCK) on (hp.health_plan_group_id = hpg.health_plan_group_id)
		 join niacore..cpt4_codes cpt WITH (NOLOCK) on (a.cpt4_code = cpt.cpt4_code)
		 join niacore..exam_category ex WITH (NOLOCK) on (cpt.exam_cat_id = ex.exam_cat_id)
		 join niacore..funding_risk_types frt with (nolock) on (frt.funding_risk_Type = hp.funding_risk_type)
		 
		 join adhoc.dbo.Queue_Codes_for_ICR q with(nolock) on (aqh.queue_code = q.queue_code)

	--JOIN TO GET THE "NEXT" DATE QUEUED
		 left join   asdreportdb.niacombine.auth_queue_history_arch_nia aqh2 WITH(NOLOCK)  on (aqh.auth_id = aqh2.auth_id and aqh.car_id = aqh2.car_id
						and aqh2.date_queued = (select min(aqh3.date_queued) 
							from asdreportdb.niacombine.auth_queue_history_arch_nia aqh3 WITH(NOLOCK) 
							where aqh3.auth_id = aqh.auth_id and aqh3.car_id = aqh.car_id
							and aqh3.date_queued > aqh.date_queued))		   ---added to resolve issue with FHS MG 6/8/15

	where	
	aqh.date_queued >= @start_date 
	and aqh.date_queued < @end_date--dateadd(dd, 1, @end_date)
	--and aqh.auth_id = '20120249'
	--and aqh.queue_code in ('dlr','esw','irq','icr','mib','sgc','sgu','sg1','v04','v01',
	--		'v05','v02','v03','pm1','ro2','rcr','riq','ro3','aum') 
	and (aqh2.queue_code is NULL
	or aqh2.queue_code <> 'fhs')    ---added to resolve issue with FHS MG 6/8/15
	and at.business_division_id = '1'   ---added to remove BH cases MG 7/18/16	

--select * from adhoc.dbo.Queue_ICR1

/* Get Touches Summary */

IF OBJECT_ID('adhoc.dbo.Queue_ICR1_rows') IS NOT NULL drop table adhoc.dbo.Queue_ICR1_rows

select  auth_id, 
		car_id, 
		car_name,
		line_of_business,
		hpg_description,
		plan_name,
		exam_cat_desc,
		proc_desc,
		queue_code,
		queue_description, 
		--updated_queue_code,
		isfinal, 
		date_queued, 
		authorization_type_id,
		risk_type,
		Auth_Type_Name,
	    Report_Date,
		0 AS Monthly_flag,       
	    identity(int,1,1) as rown
	    
into adhoc.dbo.Queue_ICR1_rows
from adhoc.dbo.Queue_ICR1
order by car_name, auth_id, date_queued


/* Get Touches Limited - Kevin Frederick said we needed to try and eliminate duplicate 
   system submissions to the ICR queues so Terry Rogers wrote the code below to limit
   the duplicates to any that were greater than 5 minutes from the first resubmit to 
   the second.  This isn't perfect but falls more in line with expected volume.      */

IF OBJECT_ID('adhoc.dbo.Queue_ICR1_final_rows') IS NOT NULL drop table adhoc.dbo.Queue_ICR1_final_rows

select	a.*,identity(int,1,1) as row_id,
		datediff (minute, b.date_queued, a.date_queued) as time_diff

into	adhoc.dbo.Queue_ICR1_final_rows	

from	adhoc.dbo.Queue_ICR1_rows a
		left join adhoc.dbo.Queue_ICR1_rows b on (a.car_id = b.car_id
					and a.queue_code = b.queue_code
					and a.auth_id = b.auth_id and b.rown = (a.rown - 1))
					
where	datediff (minute, b.date_queued, a.date_queued) is null
		or datediff (minute, b.date_queued, a.date_queued)>5

     		
/* Get Final Data - by auth type */

Select Auth_Type_ID = authorization_type_id, Auth_Type_Name, queue_code, queue_description, count(distinct(convert(varchar(3),car_id))+auth_id) as Unique_Cases, 
count(convert(varchar(3),car_id)+auth_id) as NonUnique_Cases from adhoc.dbo.Queue_ICR1_final_rows
group by authorization_type_id, Auth_Type_Name, queue_code, queue_description
order by authorization_type_id, queue_code


/* Get Final Data - queue code */

--select queue_code, queue_description, count(distinct(convert(varchar(3),car_id))+auth_id) as Unique_Cases, 
--count(convert(varchar(3),car_id)+auth_id) as NonUnique_Cases from adhoc.dbo.Queue_ICR1_final_rows
--group by queue_code, queue_description
--order by queue_code

--select * from adhoc.dbo.Queue_ICR1_final_rows
	 

/* Get Final Data by HP */

Select Auth_Type_ID = authorization_type_id, Auth_Type_Name, queue_code, queue_description, car_id, car_name, line_of_business,	hpg_description,plan_name,exam_cat_desc,proc_desc,risk_type,
count(distinct(convert(varchar(3),car_id))+auth_id) as Unique_Cases, 
count(convert(varchar(3),car_id)+auth_id) as NonUnique_Cases from adhoc.dbo.Queue_ICR1_final_rows
group by authorization_type_id, Auth_Type_Name, queue_code, queue_description, car_name,car_id,line_of_business,hpg_description,plan_name,exam_cat_desc,proc_desc,--updated_Queue_code,
risk_type
order by authorization_type_id, queue_code, car_name

--select * from adhoc.dbo.Queue_ICR1_final_rows

/* Get Detail of Cases With Multiple Times in Queue */

Select  a.auth_id, 
		a.car_id, 
		a.car_name,
		a.line_of_business,
		a.exam_cat_desc,
		a.proc_desc,
		a.queue_code,
		a.queue_description, 
		--a.updated_queue_code,
		a.risk_type,
		a.Auth_Type_Name,
		count(a.auth_id) as Total_Times_In_Queue	
		
from    adhoc.dbo.Queue_ICR1_final_rows a

group by 
		--a.updated_queue_code,
		a.car_id, 
		a.car_name,
		a.auth_id,
		a.line_of_business,
		a.exam_cat_desc,
		a.proc_desc,
		a.queue_code,
		a.queue_description, 
		a.risk_type,
		a.Auth_Type_Name
					
having count(a.auth_id) >1		

order by count(a.auth_id) desc	