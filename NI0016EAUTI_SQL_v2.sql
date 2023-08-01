/*
11/20/14   ---   Modified to accomodate request  -- JHV

	We would like to modify report MINSO001I.  Please add the following queues to the current setup…

	Insufficient Information Queue
	Pain Injections MD Review Queue
	Retro MD Review Queue

	Kevin R. Frederick
	Senior Director, Operations Hub/Physician Business Mgt 
-----------------------------------------------------------------------------------------------

06/02/15  
Remove FHS outbound queue code of FHS

		Due to some routing changes caused by the Hindsait program, we need to make some changes to this report.

*/

IF OBJECT_ID('AdHoc.dbo.PM_pcrqueue2j') IS NOT NULL 
drop table AdHoc.dbo.PM_pcrqueue2j;

IF OBJECT_ID('AdHoc.dbo.PM_pcrqueue3j') IS NOT NULL 
drop table AdHoc.dbo.PM_pcrqueue3j;

IF OBJECT_ID('AdHoc.dbo.PM_pcrqueue4j') IS NOT NULL 
drop table AdHoc.dbo.PM_pcrqueue4j;

IF OBJECT_ID('AdHoc.dbo.PM_pcrqueue5j') IS NOT NULL 
drop table AdHoc.dbo.PM_pcrqueue5j;

IF OBJECT_ID('AdHoc.dbo.PM_pcrqueue6j') IS NOT NULL 
drop table AdHoc.dbo.PM_pcrqueue6j;


 
set nocount on

declare @db_name varchar(30),
	 @car_name varchar(100),
	 @ls_sqlstring varchar(8000),
	 @last_night varchar(20),
	 @last_night_end varchar(20)

----set @last_night			=    'oct 8 2018 10:00PM'   ---  THIS IS THE TWO DAYS BEFORE THE RUN delivered  ---EX 3.22.16 for the report DELIVERED 3/24
----set @last_night_end  =   'oct 9 2018 10:00PM'    ----  THIS IS THE DAY BEFORE THE RUN delivered ---EX 3.23.16 for the report DELIVERED 3/24

set @last_night   =  convert(varchar(25),  DATEADD(MI,-120,DATEADD(D,DATEDIFF(D,1,GetDate()),0)))
set @last_night_end   = convert(varchar(25),  DATEADD(MI,-120,DATEADD(D,DATEDIFF(D,0,GetDate()),0)))

--------------------------------------
--STEP 1 - Create adhoc temp table PCRQUEUE
---Gathers the active contracts from the Authorization Queue History and the Authorization Queue History Archive tables.---

create table AdHoc.dbo.PM_pcrqueue2j
 		(healthplan varchar(100) null,
		auth_id varchar(25) null,
		date_in datetime,
		date_out datetime,
		queue_code varchar(3) null,
        outbound_queue_code varchar(3) null)    --- need to exclude Hindsait FHS queue codes

--------------------------------------
--STEP 2 - Cursor

----STEP 2a - Establish Cursor
declare f cursor for 

----STEP 2b - Gather client databases that are active as of last night

SELECT   db_name  ---- [jhv] changed to car_name rather than db_name  10/10/18
 ----------------car_name
,client_car_name
FROM niacore.dbo.health_carrier (NOLOCK)
WHERE ISNULL(date_contract_inactive, GETDATE()+1) > GETDATE()
    AND date_contract_active <=  GETDATE()
    AND db_name NOT IN ('BCBSSCMAG', 'BCBSKC','CMS_MID2')
ORDER BY db_name ASC;	
	
open f
fetch next from f into @db_name, @car_name
while @@fetch_status = 0
begin

----STEP 2c - INSERT #1 - queued  (''mdr'' , ''um'' , ''spr'' , ''iiq'' , ''pm2'' , ''rr2'') 

select 	@ls_sqlstring = 'insert into AdHoc.dbo.PM_pcrqueue2j (healthplan, auth_id, date_in, date_out, 
	queue_code, outbound_queue_code) '+'
select ''' + @car_name + ''',	aqh.auth_id, date_in = aqh.date_queued,
	date_out = aqh2.date_queued, aqh.queue_code, aqh2.queue_code
from ' + @db_name + '.dbo.auth_queue_history aqh WITH(NOLOCK) 
         left join  ' + @db_name + '.dbo.auth_queue_history aqh2 WITH(NOLOCK)  on (aqh.auth_id = aqh2.auth_id 
						and aqh2.date_queued = (select min(aqh3.date_queued) 
							from  ' + @db_name + '.dbo.auth_queue_history aqh3 WITH(NOLOCK) 
							where aqh3.auth_id = aqh.auth_id
							and aqh3.date_queued > aqh.date_queued))

		join [Adhoc].[dbo].[queue_codes_for_Daily_PM_review] icrQ WITH(NOLOCK) on (aqh.queue_code = icrQ.queue_code) 
where   (aqh2.date_queued >= ''' + @last_night + '''  or aqh2.date_queued is null)

union

select ''' + @car_name + ''',	aqh.auth_id, date_in = aqh.date_queued, date_out = aqh2.date_queued,
	aqh.queue_code, aqh2.queue_code     	
from  ' + @db_name + '.dbo.auth_queue_history_arch aqh WITH(NOLOCK) 
          left join  ' + @db_name + '.dbo.auth_queue_history_arch aqh2 WITH(NOLOCK)  on (aqh.auth_id = aqh2.auth_id
						and aqh2.date_queued = (select min(aqh3.date_queued) 
						from  ' + @db_name + '.dbo.auth_queue_history_arch aqh3 WITH(NOLOCK) 
						where aqh3.auth_id = aqh.auth_id
							and aqh3.date_queued > aqh.date_queued))
		join [Adhoc].[dbo].[queue_codes_for_Daily_PM_review] icrQ WITH(NOLOCK) on (aqh.queue_code = icrQ.queue_code) 
where aqh2.date_queued >= ''' + @last_night + ''' '

exec( @ls_sqlstring )


fetch next from f into @db_name, @car_name
end

close f
deallocate f

--------------------------------------
--STEP 3 - Create new temp table to bring in the full name of the queue
select	a.*,
		queue_desc = b.description,
		--sort_key = case a.queue_code
		--			when 'pmr' then 1
		--			when 'por' then 2
		--			when 'trr' then 3
					--------when 'iiq' then 4
					--------when 'pm2' then 5
					--------when 'rr2' then 6
					--------else 9 end,
		last_night = @last_night  --pull the variable into the table as a value

into	adhoc.dbo.PM_pcrqueue3j      ----------- select * from adhoc..pcrqueue3j     where  outbound_queue_code <> 'fhs'     
from	adhoc.dbo.PM_pcrqueue2j a
		join niacore.dbo.informa_queues b WITH(NOLOCK)  on (a.queue_code = b.queue_code)
----		where  ISNULL (outbound_queue_code, NULL) <> 'fhs'       
where outbound_queue_code is NULL 
or outbound_queue_code <> 'fhs' 
--------------------------------------
--STEP 4 - Summary tab with Queue counts 

select	--sort_key,
		queue_desc,
		last_night,
		Start = sum(case when date_in < last_night then 1 else 0 end),
		Entered = sum(case when date_in >= last_night  and  date_in   <  @last_night_end  then 1 else 0 end),
		Exited = sum(case when date_out >= last_night  and  date_out <  @last_night_end  then 1 else 0 end),
		Remaining = sum(case when date_out is null and date_in  <  @last_night_end   or   
				(date_in  <  @last_night_end and  date_out >  @last_night_end)  then 1 else 0 end)

from	adhoc.dbo.PM_pcrqueue3j 

group by --sort_key,
queue_desc,last_night
--order by sort_key


-----------------------------------------------------------------------------
--STEP 5 - Detail tab - Queue counts by Client

-- 5a. First, put counts by Healthplan into a separate table.

select	
Healthplan,
		Queue_Desc,
		--Last_Night,
		Start = sum(case when date_in < last_night then 1 else 0 end),
		Entered = sum(case when date_in >= last_night   and  date_in   <  @last_night_end then 1 else 0 end),
		Exited = sum(case when date_out >= last_night   and  date_out <  @last_night_end then 1 else 0 end),
		Remaining = sum(case when date_out is null and date_in  <  @last_night_end   or 
				( date_in  <  @last_night_end and  date_out >  @last_night_end)  then 1 else 0 end)

into	adhoc.dbo.PM_pcrqueue4j    --- select * from adhoc.dbo.pcrqueue4j 
from	adhoc.dbo.PM_pcrqueue3j 

group by Healthplan, Queue_Code, Queue_Desc, Last_Night
		
order by Healthplan


-- 5b-1. Second, do some more calculations including the percentage

select	p4.*,
		Start - Exited as [Start_Minus_Exited],
		Entered - Exited as [Entered_Minus_Exited],
		Percentage1 = case when Start - Exited = 0 or Start = 0 then NULL else (convert(decimal,Start - exited,1))/(convert(decimal,Start,1)) end

into	adhoc.dbo.PM_pcrqueue5j
from	adhoc.dbo.PM_pcrqueue4j p4


-- 5b-2. Refine Percentage1 to be only two digits

select	
Healthplan, Queue_Desc, Start, Entered, Exited, Remaining, Start_Minus_Exited, Entered_Minus_Exited,
		Percentage = cast (p5.Percentage1 as decimal (37,2))

into	adhoc.dbo.PM_pcrqueue6j    
from	adhoc.dbo.PM_pcrqueue5j p5


-- 5c. Third, populate the flag based on the percentage

select	p6.*,
Flag = case when p6.Percentage >= -50 then 1 else 0 end

from	adhoc.dbo.PM_pcrqueue6j p6
WHERE 
	Start > 0 
	OR Entered > 0
	OR Exited > 0
	OR Remaining > 0
order by  
	----case 
	Queue_Desc 
	----	when 'Physical Medicine Therapy MD Review Queue' then 0
	----	when 'Physical Medicine Clinical Review Queue' then 1
	----	when 'Therapy Clinical Rationale Review Queue' then 2
	----	------when 'Insufficient Information Queue' then 3
	----	------when 'Pain Injections MD Review Queue' then 4
	----	------when 'Retro MD Review Queue' then 5
	----end  
	,Healthplan
