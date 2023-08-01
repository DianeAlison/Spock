IF OBJECT_ID('adhoc.dbo.PMqueue_pre_rt') IS NOT NULL 
                drop table adhoc.dbo.PMqueue_pre_rt;
IF OBJECT_ID('adhoc.dbo.PMqueue_rt') IS NOT NULL 
                drop table adhoc.dbo.PMqueue_rt;
IF OBJECT_ID('adhoc.dbo.Queue_PM_rows_RT') IS NOT NULL 
                drop table adhoc.dbo.Queue_PM_rows_RT;
IF OBJECT_ID('tempdb..#overall') IS NOT NULL 
                drop table tempdb..#overall
IF OBJECT_ID('tempdb..#breakout') IS NOT NULL 
                drop table tempdb..#breakout
                
                
set nocount on

declare @db_name varchar(30),
                @car_name varchar(100),
                @ls_sqlstring varchar(8000),
                @last_night varchar(20)                ,
                @last_night_end varchar(20)                 -----------  jhv added to simulate run time of report
/*
set @last_night			=  '8/30/2018 10:00pm'
set @last_night_end =  '8/31/2018 10:00pm'    -----------  jhv added to simulate run time of report
*/

/*
set @last_night = case when datepart(dw,getdate() - 1) = 1   --- is today Monday
then convert(varchar(2),datepart(mm,getdate()-4)) + '/'  + convert(varchar(2),datepart(dd,getdate()-4)) + '/' + convert(varchar(4),datepart(yyyy,getdate()-4)) + ' 10:00pm'    --- capture all of Friday
else convert(varchar(2),datepart(mm,getdate()-2)) + '/'  + convert(varchar(2),datepart(dd,getdate()-2)) + '/' + convert(varchar(4),datepart(yyyy,getdate()-2)) + ' 10:00pm'    ---- capture all of yesterday
                                 end

 */ 

set @last_night = '11/27/2020 10:00pm'
                                       
set  @last_night_end = '11/28/2020 10:00pm'

--set @last_night =  convert(varchar(2),datepart(mm,getdate()-2)) + '/'  + convert(varchar(2),datepart(dd,getdate()-2)) + '/' + convert(varchar(4),datepart(yyyy,getdate()-2)) + ' 10:00pm'    ---- capture all of yesterday
                                       
--set  @last_night_end = convert(varchar(2),datepart(mm,getdate()-1)) + '/'  + convert(varchar(2),datepart(dd,getdate()-1)) + '/' + convert(varchar(4),datepart(yyyy,getdate()-1)) + ' 10:00pm'   -----------  jhv added to simulate run time of report
      
select 	  @last_night ,   @last_night_end                         
----*/


create table adhoc.dbo.PMqueue_pre_rt(

				auth_type_desc varchar (100) null,
                healthplan varchar(100) null,
                auth_id varchar(25) null,
                date_in datetime,
                date_out datetime,
                queue_code varchar(3) null    ,
                ---report_translation varchar(3) null)   ----[jhv] 7.31.18 remove code
				report_translation varchar(100) null    ----[jhv] 7.31.18  use description
				)
declare f cursor for 
                select    
						 distinct a.db_name
						,a.car_name
                from      niacore..health_carrier a  WITH(NOLOCK),
                                niacore..nia_program_codes b  WITH(NOLOCK)
                where   a.date_contract_active <= @last_night and
                                (a.date_contract_inactive is null or a.date_contract_inactive >= dateadd(dy, 1, getdate())) and
                                a.nia_program_code = b.nia_program_code and
                                b.informa_active_flag = 1

open f
fetch next from f into @db_name, @car_name

while @@fetch_status = 0
begin

select    @ls_sqlstring = 'insert into adhoc.dbo.PMqueue_pre_rt (healthplan, auth_type_desc, auth_id, date_in, date_out, queue_code, report_translation) '+

'select
		''' + @car_name + ''',         
		at.description,
		aqh.auth_id,
        date_in = aqh.date_queued,
        date_out = aqh2.date_queued,
        aqh.queue_code,
        ----aqh.report_translation
        iq.description   -------- [jhv] 7.31.18 
from ' + @db_name + '..auth_queue_history aqh WITH(NOLOCK)
		join ' + @db_name + '..authorizations a WITH(NOLOCK) on (aqh.auth_id = a.auth_id)
		join  niacore.dbo.authorization_types at WITH(NOLOCK) on (at.authorization_type_id = a.authorization_type_id)
		join [Adhoc].[dbo].[queue_codes_for_PM_review_] icrQ WITH(NOLOCK) on (aqh.queue_code = icrQ.queue_code) 	   -----  JHV innotas   6.15.18
		join [niacore].[dbo].[informa_queues] iq WITH(NOLOCK) on (aqh.report_translation = iq.queue_code)  --- [jhv] 7.31.18 
		left join  ' + @db_name + '..auth_queue_history aqh2  WITH(NOLOCK) on (aqh.auth_id = aqh2.auth_id 
											 and aqh2.date_queued = (select min(aqh3.date_queued) 
															from  ' + @db_name + '..auth_queue_history aqh3  WITH(NOLOCK)
															where aqh3.auth_id = aqh.auth_id
															and aqh3.date_queued > aqh.date_queued
															and aqh3.date_queued <= ''' + @last_night_end + '''     -----------  jhv added to simulate run time of report
															 )) 
where (aqh2.date_queued >= ''' + @last_night + '''  or aqh2.date_queued is null)

			and (aqh2.date_queued <= ''' + @last_night_end + ''' or aqh2.date_queued is null )     -----------  jhv added to simulate run time of report
			and (aqh.date_queued	<= ''' + @last_night_end + ''' )     -----------  jhv added to simulate run time of report
	and (aqh2.queue_code is NULL
	or aqh2.queue_code <> ''fhs'')  ---added to resolve issue with FHS MG 6/8/15
	------and at.business_division_id = ''1''   ---added to remove BH cases MG 7/18/16
	and at.authorization_type_id = ''16''
															
union

select 
		''' + @car_name + ''',          
		at.description,
		aqha.auth_id,
        date_in = aqha.date_queued,
        date_out = aqha2.date_queued,
        aqha.queue_code,
        ------aqha.report_translation             
       iq.description   -------- [jhv] 7.31.18  
from  ' + @db_name + '..auth_queue_history_arch aqha  WITH(NOLOCK)
        join ' + @db_name + '..authorizations a WITH(NOLOCK) on (aqha.auth_id = a.auth_id)
        join niacore.dbo.authorization_types at WITH(NOLOCK) on (at.authorization_type_id = a.authorization_type_id)                              
		join [Adhoc].[dbo].[queue_codes_for_PM_review_] icrQ WITH(NOLOCK) on (aqha.queue_code = icrQ.queue_code) 		             -----  JHV innotas   6.15.18          
		join [niacore].[dbo].[informa_queues] iq WITH(NOLOCK) on (aqha.report_translation = iq.queue_code)  --- [jhv] 7.31.18                             
		left join  ' + @db_name + '..auth_queue_history_arch aqha2  WITH(NOLOCK) on (aqha.auth_id = aqha2.auth_id
												and aqha2.date_queued = (select min(aqha3.date_queued) 
																from  ' + @db_name + '..auth_queue_history_arch aqha3 WITH(NOLOCK)
																where aqha3.auth_id = aqha.auth_id
																and aqha3.date_queued > aqha.date_queued
																and aqha3.date_queued <= ''' + @last_night_end + '''      -----------  jhv added to simulate run time of report
																 )) 
		where aqha2.date_queued >= ''' + @last_night + '''
			and aqha2.date_queued <= ''' + @last_night_end + '''      -----------  jhv added to simulate run time of report
		
			and (aqha.date_queued	<= ''' + @last_night_end + ''' )     -----------  jhv added to simulate run time of report
				
	and (aqha2.queue_code is NULL
	or aqha2.queue_code <> ''fhs'')  ---added to resolve issue with FHS MG 6/8/15

	and at.authorization_type_id = ''16''															
	'		  -------------END of cursor logic
exec( @ls_sqlstring )

fetch next from f into @db_name, @car_name
end

close f
deallocate f

---- select * from adhoc..icrqueue_pre_RT
/* Get Touches Limited - Kevin Frederick said we needed to try and eliminate duplicate 
   system submissions to the ICR queues so Terry Rogers wrote the code below to limit
   the duplicates to any that were greater than 5 minutes from the first resubmit to 
   the second.  This isn't perfect but falls more in line with expected volume.      */

SELECT 
	healthplan, 
	auth_type_desc, 
	auth_id, 
	date_in, 
	date_out, 
	queue_code, 
	report_translation,
	identity(int,1,1) as rown
into adhoc.dbo.Queue_PM_rows_RT
from adhoc.dbo.PMqueue_pre_RT
order by healthplan, auth_id, date_in



select	a.*,identity(int,1,1) as row_id,
		datediff (minute, b.date_in, a.date_in) as time_diff

into	adhoc.dbo.PMqueue_rt

from	adhoc.dbo.Queue_PM_rows_RT a
		left join adhoc.dbo.Queue_PM_rows_RT b on (a.healthplan = b.healthplan
					and a.queue_code = b.queue_code
					and a.auth_id = b.auth_id and b.rown = (a.rown - 1))
					
where	datediff (minute, b.date_in, a.date_in) is null
		or datediff (minute, b.date_in, a.date_in)>5




		
-------------------- NEW first breakout --------------- JHV innotas   7.31.18
select e.report_translation,

queue_count_last_night = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code
								and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc
                                and e1.date_in < @last_night),

entered_queue = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan  
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
                               	and e1.auth_type_desc = e.auth_type_desc 
                                and e1.date_in >= @last_night
                                and e1.date_in <=  @last_night_end  ),    -----------  jhv added to simulate run time of report

left_queue = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc                                                                
                                and e1.date_out >= @last_night
                                and e1.date_out <=  @last_night_end ),    -----------  jhv added to simulate run time of report

in_queue_at_time_of_report_run = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc                                                                
                                and e1.date_out is null)
into #overall
from adhoc.dbo.PMqueue_rt e   ---- select * from adhoc..icrqueue_rt   where auth_ID = '08021855344'  order by auth_id
group by  e.report_translation, e.healthplan, e.queue_code, auth_type_desc
order by e.report_translation		
		
select 
 report_translation
,SUM(queue_count_last_night) as queue_count_last_night
,SUM(entered_queue) as entered_queue
,SUM(left_queue) as left_queue
,SUM(in_queue_at_time_of_report_run) as in_queue_at_time_of_report_run

from #overall 
group by  report_translation
order by report_translation

-------------------------------------- GRAND TOTAL ------------------------for tab one (SUMMARY)
select   'Grand_Total',

PM_Review_Queue_Count_Last_Night = (select count(e1.auth_id) 
 from adhoc.dbo.PMqueue_rt e1
        where e1.date_in <= @last_night
			),
PM_Review_Entered_Queue = (select count(e1.auth_id)
from adhoc.dbo.PMqueue_rt e1
        where e1.date_in >= @last_night
			and e1.date_in <=  @last_night_end    -----------  jhv added to simulate run time of report
			),
PM_Review_Left_Queue = (select count(e1.auth_id)
       from adhoc.dbo.PMqueue_rt e1
       where e1.date_out >= @last_night
			and e1.date_out <=  @last_night_end    -----------  jhv added to simulate run time of report 
			), 
PM_Review_In_Queue_At_Time_Of_Report_Run = (select count(e1.auth_id)
       from adhoc.dbo.PMqueue_rt e1
       where e1.date_out is null
		)
		



-------------------- NEW second level breakout --------------- JHV innotas   6.15.18
select e.auth_type_desc,

queue_count_last_night = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code
								and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc
                                and e1.date_in < @last_night),

entered_queue = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan  
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
                               	and e1.auth_type_desc = e.auth_type_desc 
                                and e1.date_in >= @last_night
                                and e1.date_in <=  @last_night_end  ),    -----------  jhv added to simulate run time of report

left_queue = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc                                                                
                                and e1.date_out >= @last_night
                                and e1.date_out <=  @last_night_end ),    -----------  jhv added to simulate run time of report

in_queue_at_time_of_report_run = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc                                                                
                                and e1.date_out is null)
into #breakout
from adhoc.dbo.PMqueue_rt e
group by  e.auth_type_desc, e.healthplan, e.queue_code, e.report_translation
order by e.auth_type_desc

select 
 auth_type_desc
,SUM(queue_count_last_night) as queue_count_last_night
,SUM(entered_queue) as entered_queue
,SUM(left_queue) as left_queue
,SUM(in_queue_at_time_of_report_run) as in_queue_at_time_of_report_run

from #breakout 
group by  auth_type_desc
order by auth_type_desc

-------------------------------------------END---- new second level breakout

---------------------------------------- new third level breakout  JHV      Innotas 6.15.18.  --- replace report translation code with description  --[jhv] 7.31.18 

select distinct e.auth_type_desc, e.healthplan, e.queue_code, e.report_translation,

queue_count_last_night = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code
								and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc
                                and e1.date_in < @last_night),

entered_queue = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan  
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
                               	and e1.auth_type_desc = e.auth_type_desc 
                                and e1.date_in >= @last_night
                                and e1.date_in <=  @last_night_end  ),    -----------  jhv added to simulate run time of report

left_queue = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc                                                                
                                and e1.date_out >= @last_night
                                and e1.date_out <=  @last_night_end ),    -----------  jhv added to simulate run time of report

in_queue_at_time_of_report_run = (select count(e1.auth_id) from adhoc.dbo.PMqueue_rt e1
                                where e1.healthplan = e.healthplan 
                                and e1.queue_code = e.queue_code 
                                and e1.report_translation = e.report_translation
								and e1.auth_type_desc = e.auth_type_desc                                                                
                                and e1.date_out is null)

from adhoc.dbo.PMqueue_rt e
group by  e.auth_type_desc, e.healthplan, e.queue_code, e.report_translation
order by e.healthplan, e.auth_type_desc, e.queue_code

-----------------------AUTH LEVEL DETAIL -------------------  

 select healthplan, auth_type_desc,auth_id, date_in, date_out, queue_code, report_translation, rown, datediff(mi,date_in,date_out)
 

  from adhoc.dbo.PMqueue_rt

 
order by auth_type_desc,  healthplan,  queue_code