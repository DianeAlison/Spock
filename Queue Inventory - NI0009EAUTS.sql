--Use nile-r1


/*
Paste all carrier results into the tab titled "ICR Deter Detail"
from columns A through  AI only,   --****  DO NOT  clear colums AJ through AQ.
 
*/

--Run from here to big fat note at bottom that says 
--RUN THE FOLLOWING OUTPUT SEPERATELY


/* declare local variables */
declare @start_date datetime, @end_date datetime ,@car_id int

/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'
	

SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month
	


IF OBJECT_ID('adhoc.dbo.ICR_EFF_All') IS NOT NULL Drop Table adhoc.dbo.ICR_EFF_All
IF OBJECT_ID('adhoc.dbo.ICR_EFF_ICR_only') IS NOT NULL Drop Table adhoc.dbo.ICR_EFF_ICR_only   
IF OBJECT_ID('adhoc.dbo.ICR_EFF_Updated_All') IS NOT NULL Drop Table adhoc.dbo.ICR_EFF_Updated_All

IF OBJECT_ID('adhoc.dbo.ICR_EFF_Updated_ICR_only') IS NOT NULL Drop Table adhoc.dbo.ICR_EFF_Updated_ICR_only 	

IF OBJECT_ID('adhoc.dbo.Max_ICR') IS NOT NULL Drop Table adhoc.dbo.Max_ICR
IF OBJECT_ID('temdb..#rows') IS NOT NULL Drop Table #rows

create table adhoc.dbo.ICR_EFF_All
		(car_name varchar(100) NULL,
		car_id int NULL,
		auth_id varchar(15) NULL,
		combo_flag varchar(1) NULL,
		line_of_business varchar(5) NULL, 
		plan_id int NULL,
		plan_name varchar(100) NULL,
		--risk_type varchar(100) NULL,
		authorization_type_id tinyint NULL,
		auth_type_name varchar(100) NULL,
		efficiency_group_id int NULL,	
		CPT4_Code_ICR_Team varchar(100) NULL,
		Status varchar(255) NULL,
		cpt4_code varchar(5) NULL,
		proc_desc varchar(100) NULL,
		final_status_flag int NULL,
		date_call_rcvd datetime NULL,
		changed_date datetime NULL,
		phys_id int NULL,
		tax_id varchar(9) NULL,
		ordering_provider_name varchar(100) NULL,
		spec_name varchar(60) NULL,
		member_id int NULL,
		member_name varchar(100) NULL,
		is_user_id int NULL,
		User_Name varchar(50) NULL,
		title varchar(255) NULL,
		description varchar(100) NULL,
		report_level varchar(130) NULL,
		auth_action_code int NULL,
		action_date datetime NULL)

insert into adhoc.dbo.ICR_EFF_All
		(car_name,
		car_id,
		auth_id,
		combo_flag,
		line_of_business, 
		plan_id,
		plan_name,
		--risk_type,
		authorization_type_id,
		auth_type_name,
		efficiency_group_id,	
		CPT4_Code_ICR_Team,
		Status,
		cpt4_code,
		proc_desc,
		final_status_flag,
		date_call_rcvd,
		changed_date,
		phys_id,
		tax_id,
		ordering_provider_name,
		spec_name,
		member_id,
		member_name,
		is_user_id,
		User_Name,
		title,
		description,
		report_level)
		
Select Distinct   
		car_name = Case When a.car_id = '29' then 'HealthNow New York Inc' 
								else hc.car_name
				   end,
		hc.car_id,
		a.auth_id,
		a.combo_flag,
		hp.line_of_business, 
		hp.plan_id,
		hp.plan_name,
		--risk_type = ft.description,
		a.authorization_type_id,
		auth_type_name = at.description,
		case when egs.efficiency_group_id is null
			then 0
			else egs.efficiency_group_id
		end as 'efficiency_group_id',	
		CPT4_Code_ICR_Team = ' ',
		Status = ac.status_desc,
		a.cpt4_code,
		a.proc_desc,
		ac.final_status_flag,
		a.date_call_rcvd,
		changed_date = aschg.date_changed,
		a.phys_id,
		p.tax_id,
		ordering_provider_name = upper(p.lname + ', '+p.fname),
		s.spec_name,
		m.member_id,
		member_name = upper(m.lname + ', '+m.fname),
		i.is_user_id,
		upper(i.lname +', '+i.fname) as 'User_Name',
		i.title,
		ut.description,
		ut.report_level

From    ASDReportDB.niacombine.authorizations_nia a WITH (NOLOCK)
        join niacore..authorization_types at WITH (NOLOCK) on (a.authorization_type_id = at.authorization_type_id)
		left outer join niacore..efficiency_groups_cpt4_codes egs WITH (NOLOCK) on (a.cpt4_code = egs.cpt4_code)
		join ASDReportDB.niacombine.members_nia m WITH (NOLOCK) on (a.member_id = m.member_id and a.car_id = m.car_id)
		join ASDReportDB.niacombine.physicians_nia p WITH (NOLOCK) on (a.phys_id = p.phys_id and a.car_id = p.car_id)
		join niacore..specialties s WITH (NOLOCK) on (p.spec_id = s.spec_id)
		join niacore..health_plan hp WITH (NOLOCK) on (m.plan_id = hp.plan_id)
        --left join niacore..Funding_Risk_Types ft WITH (NOLOCK) on (hp.funding_risk_type = ft.funding_risk_type)
		join niacore..health_carrier hc WITH (NOLOCK) on (a.car_id =hc.car_id)
		join ASDReportDB.niacombine.auth_status_change_nia aschg WITH (NOLOCK) on (a.auth_id = aschg.auth_id and a.car_id = aschg.car_id) 
		join niacore..auth_status_codes ac WITH (NOLOCK) on (aschg.new_auth_status = ac.auth_status)
		join niacore..is_users i WITH (NOLOCK) on (aschg.user_name = i.log_id )
		join niacore..is_user_types ut WITH (NOLOCK) on (i.type = ut.user_type)

where   aschg.date_changed >= @start_date  
		and aschg.date_changed < dateadd(dd,1, @end_date)
		and i.title = 'Initial Clinical Reviewer'
		--and not exists (select * 
		--	from adhoc.niacombine.auth_action_log_nia b
		--	where a.car_id = b.car_id and a.auth_id = b.auth_id
		--		  and b.auth_action_code in (17,969,970,1040))
option (maxdop 1)


/* Get Auth Action Data */

insert into adhoc.dbo.ICR_EFF_All
		(car_name,
		car_id,
		auth_id,
		combo_flag,
		line_of_business, 
		plan_id,
		plan_name,
		--risk_type,
		authorization_type_id,
		auth_type_name,
		efficiency_group_id,
		CPT4_Code_ICR_Team,
		Status,
		cpt4_code,
		proc_desc,
		final_status_flag,
		date_call_rcvd,
		phys_id,
		tax_id,
		ordering_provider_name,
		spec_name,
		member_id,
		member_name,
		is_user_id,
		User_Name,
		title,
		description,
		report_level,
		auth_action_code,
		action_date)
		
Select Distinct  
		car_name = Case When a.car_id = '29' then 'HealthNow New York Inc' 
								else hc.car_name
				   end,
		hc.car_id,
		a.auth_id,
		a.combo_flag,
		hp.line_of_business, 
		hp.plan_id,
		hp.plan_name,
		--risk_type = ft.description,
		a.authorization_type_id,
		auth_type_name = at.description,
		case when egs.efficiency_group_id is null
			then 0
			else egs.efficiency_group_id
		end as 'efficiency_group_id',	
		CPT4_Code_ICR_Team = ' ',
		Status = ac.description,
		a.cpt4_code,
		a.proc_desc,
		final_status_flag = 0,
		a.date_call_rcvd,
		a.phys_id,
		p.tax_id,
		ordering_provider_name = upper(p.lname + ', '+p.fname),
		s.spec_name,
		m.member_id,
		member_name = upper(m.lname + ', '+m.fname),
		i.is_user_id,
		upper(i.lname +', '+i.fname) as 'User_Name',
		i.title,
		ut.description,
		ut.report_level,
		ac.auth_action_code as 'auth_action_code',
		al.date_action as 'action_date'	

From    ASDReportDB.niacombine.authorizations_nia a WITH (NOLOCK)
        join niacore..authorization_types at WITH (NOLOCK) on (a.authorization_type_id = at.authorization_type_id)
		left outer join niacore..efficiency_groups_cpt4_codes egs WITH (NOLOCK) on (a.cpt4_code = egs.cpt4_code)
		join ASDReportDB.niacombine.members_nia m WITH (NOLOCK) on (a.member_id = m.member_id and a.car_id = m.car_id)
		join ASDReportDB.niacombine.physicians_nia p WITH (NOLOCK) on (a.phys_id = p.phys_id and a.car_id = p.car_id)
		join niacore..specialties s WITH (NOLOCK) on (p.spec_id = s.spec_id)
		join niacore..health_plan hp WITH (NOLOCK) on (m.plan_id = hp.plan_id)
		--left join niacore..Funding_Risk_Types ft WITH (NOLOCK) on (hp.funding_risk_type = ft.funding_risk_type)
		join niacore..health_carrier hc WITH (NOLOCK) on (a.car_id =hc.car_id)
		join ASDReportDB.niacombine.auth_action_log_nia al WITH (NOLOCK) on (a.auth_id = al.auth_id and a.car_id = al.car_id)
		inner join niacore..auth_action_codes ac WITH (NOLOCK) on (al.auth_action_code = ac.auth_action_code)
		join niacore..is_users i WITH (NOLOCK) on (al.is_user_id = i.is_user_id)
		join niacore..is_user_types ut WITH (NOLOCK) on (i.type = ut.user_type)

where   al.date_action >= @start_date 
		and al.date_action < dateadd(dd,1, @end_date) 
		and i.title = 'Initial Clinical Reviewer'
		--and not exists (select * 
		--	from adhoc.niacombine.auth_action_log_nia b
		--	where a.car_id = b.car_id and a.auth_id = b.auth_id
		--		  and b.auth_action_code in (17,969,970,1040))
option (maxdop 1)



update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR General Studies' where efficiency_group_id = 0 and 
                         authorization_type_id not in (3,5,6)

update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Pain Management Injection' where efficiency_group_id = 6 and 
                         authorization_type_id = 5   

/* Added 11/2/15 to account for other PM Injection - TR */                         
update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Pain Management Injection' where efficiency_group_id = 6 and 
                         authorization_type_id <> 5 
 
/* Added 11/2/15 to account for other PM Injection - TR */                          
update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Pain Management Injection' where efficiency_group_id = 0 and 
                         authorization_type_id = 5                                                                             

update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Pain Management Surgery' where efficiency_group_id = 0 and 
                         authorization_type_id = 6	
update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Cardiology' where efficiency_group_id = 1 

update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Oncology' where efficiency_group_id = 2 

update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Radiation Oncology' where efficiency_group_id = 0 and 
                         authorization_type_id = 3                          

update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Orthopedic' where efficiency_group_id = 3 

update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Abdomen/Pelvis' where efficiency_group_id = 4 

update adhoc.dbo.ICR_EFF_All
set CPT4_Code_ICR_Team = 'ICR Neurology' where efficiency_group_id = 5 
                          						
----/* declare local variables */
--declare @start_date datetime, @end_date datetime ,@car_id int

--/* assign values to local variables */
--select	--@car_id = '67', --43 = Highmark
--	@start_date = '07/01/2015',
--	@end_date = '07/31/2015'

--/* Add Final Status */

Select Distinct  ie.car_name,
		ie.car_id,
		ie.auth_id,
		ie.combo_flag,
		ie.line_of_business, 
		ie.plan_id,
		ie.plan_name,
		--ie.risk_type,
		ie.authorization_type_id,
		ie.auth_type_name,
		ie.date_call_rcvd,
		final_status = (select ascd2.report_translation from ASDReportDB.niacombine.auth_status_change_nia asch2 WITH (NOLOCK), 
		                                                     niacore..auth_status_codes ascd2 WITH (NOLOCK)
								where ie.auth_id = asch2.auth_id and ie.car_id = asch2.car_id
									and asch2.new_auth_status = ascd2.auth_status and asch2.date_changed = 
										(select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
										 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
										 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
										exists (select 'true'
										    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
											 where aschg1.new_auth_status = ascd1.auth_status and
												  ascd1.final_status_flag = 1))),
		final_status_date = (select asch2.date_changed from ASDReportDB.niacombine.auth_status_change_nia asch2 WITH (NOLOCK)
								where ie.auth_id = asch2.auth_id and ie.car_id = asch2.car_id
									and asch2.date_changed = 
										(select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
										 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
										 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
										exists (select 'true'
										    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
											 where aschg1.new_auth_status = ascd1.auth_status and
												  ascd1.final_status_flag = 1))),
		final_auth_status_type = (select ascd4.auth_status_type from ASDReportDB.niacombine.auth_status_change_nia asch4 WITH (NOLOCK), 
		                                                             niacore..auth_status_codes ascd4 WITH (NOLOCK)
								where ie.auth_id = asch4.auth_id and ie.car_id = asch4.car_id
									and asch4.new_auth_status = ascd4.auth_status and asch4.date_changed = 
										(select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
										 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
										 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
										exists (select 'true'
										    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
											 where aschg1.new_auth_status = ascd1.auth_status and
												  ascd1.final_status_flag = 1))),
		final_outcome = (select ascd3.auth_outcome from ASDReportDB.niacombine.auth_status_change_nia asch3 WITH (NOLOCK), 
		                                                niacore..auth_status_codes ascd3 WITH (NOLOCK)
								where ie.auth_id = asch3.auth_id and ie.car_id = asch3.car_id
									and asch3.new_auth_status = ascd3.auth_status and asch3.date_changed = 
										(select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
										 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
										 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
										exists (select 'true'
										    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
											 where aschg1.new_auth_status = ascd1.auth_status and
												  ascd1.final_status_flag = 1))),
		deter_user = (select upper(i1.lname +', '+i1.fname) from ASDReportDB.niacombine.auth_status_change_nia asch5 WITH (NOLOCK), 
						                                         niacore..auth_status_codes ascd4,
						                                         niacore..is_users i1						
								where ie.auth_id = asch5.auth_id and ie.car_id = asch5.car_id
									and asch5.new_auth_status = ascd4.auth_status and asch5.user_name = i1.log_id
									and asch5.date_changed = 
										(select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
										 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
										 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
										exists (select 'true'
										    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
											 where aschg1.new_auth_status = ascd1.auth_status and
												  ascd1.final_status_flag = 1))),
		deter_level = (select iut.report_level from ASDReportDB.niacombine.auth_status_change_nia asch4 WITH (NOLOCK), 
						                            niacore..auth_status_codes ascd3,
						                            niacore..is_users i,
						                            niacore..is_user_types iut
								where ie.auth_id = asch4.auth_id and ie.car_id = asch4.car_id
									and asch4.new_auth_status = ascd3.auth_status and asch4.user_name = i.log_id
									and i.type = iut.user_type and asch4.date_changed = 
										(select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
										 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
										 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
										exists (select 'true'
										    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
											 where aschg1.new_auth_status = ascd1.auth_status and
												  ascd1.final_status_flag = 1))),
		ie.phys_id,
		ie.tax_id,
		ie.ordering_provider_name,
		ie.spec_name,
		ie.member_id,
		ie.member_name,
		ie.cpt4_code,
		ie.proc_desc,
		ie.efficiency_group_id,
		ie.CPT4_Code_ICR_Team,
		--ie.Status,
		--ie.changed_date,
		--ie.auth_action_code,
		--ie.action_date,
		Case When ie.changed_date is null
			then ie.action_date
		else ie.changed_date end as Date,
		ie.is_user_id,
		ICR_Name = ie.User_Name,
		ie.title,
		ie.description,
		ie.report_level,
		Final_Outcome_Category = '                                       ',
		Specialty_Team_new = 'UNK'
		--case when t.team = 'Abdomen_Pelvis' then 'ICR Abdomen/Pelvis'
		--     when t.team = 'Cardiac' then 'ICR Cardiology' 
		--     when t.team = 'General_Studies' then 'ICR General Studies'
		--     when t.team = 'Neurology' and ie.authorization_type_id not in (5,6)then 'ICR Neurology'
		--     --when t.team = 'Neurology' and ie.authorization_type_id = 5 then 'ICR Pain Management Injection'
		--     --when t.team = 'Neurology' and ie.authorization_type_id = 6 then 'ICR Pain Management Surgery'
		--     when t.team = 'Pain Management' and ie.authorization_type_id = 5 then 'ICR Pain Management Injection'
		--     when t.team = 'Pain Management' and ie.authorization_type_id = 6 then 'ICR Pain Management Surgery'
		--     when t.team = 'Oncology' then 'ICR Oncology'
		--     when t.team = 'Orthopedic' then 'ICR Orthopedic'
		--     else 'UNK' end as 'Specialty_Team_new'
					
Into  adhoc.dbo.ICR_EFF_Updated_All
From    adhoc.dbo.ICR_EFF_All ie with (nolock)
        --left join adhoc.dbo.ICR_PCR_Teams t on (ie.is_user_id = t.is_user_id
        --                                     and t.active_flag = 'A')
--select * from adhoc.dbo.ICR_PCR_Teams where team = 'Pain Management' or team = 'Neurology' order by is_user_id                                          
-------------------------------------------------------------------------        
/*        Remove P2P from final detail per Vonda 04/17/2015            
          
          account for both date_entered and date_action TR 08/05/2015  */
-------------------------------------------------------------------------        
Where not exists (select * 
			from ASDReportDB.niacombine.auth_action_log_nia b
			where ie.car_id = b.car_id and ie.auth_id = b.auth_id
				  and b.auth_action_code in (17,969,970,1040)
				  and (b.date_entered <= (select asch2.date_changed from ASDReportDB.niacombine.auth_status_change_nia asch2 WITH (NOLOCK)
								where ie.auth_id = asch2.auth_id and ie.car_id = asch2.car_id
									and asch2.date_changed = 
										(select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
										 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
										 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
										exists (select 'true'
										    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
											 where aschg1.new_auth_status = ascd1.auth_status and
												  ascd1.final_status_flag = 1)))
				 or b.date_action <= (select asch2.date_changed from ASDReportDB.niacombine.auth_status_change_nia asch2 WITH (NOLOCK)
								where ie.auth_id = asch2.auth_id and ie.car_id = asch2.car_id
									and asch2.date_changed = 
										(select max(aschg1.date_changed) 
										from ASDReportDB.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
										 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
										 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
										exists (select 'true'
										    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
											 where aschg1.new_auth_status = ascd1.auth_status and
												  ascd1.final_status_flag = 1)))))
	--or not exists (select * 
	--		from adhoc.niacombine.auth_action_log_nia b
	--		where ie.car_id = b.car_id and ie.auth_id = b.auth_id
	--			  and b.auth_action_code in (17,969,970,1040)
	--			  and b.date_action <= (select asch2.date_changed from adhoc.niacombine.auth_status_change_nia asch2 WITH (NOLOCK)
	--							where ie.auth_id = asch2.auth_id and ie.car_id = asch2.car_id
	--								and asch2.date_changed = 
	--									(select max(aschg1.date_changed) 
	--									from adhoc.niacombine.auth_status_change_nia aschg1 WITH (NOLOCK)
	--									 where aschg1.auth_id = ie.auth_id and aschg1.car_id = ie.car_id 
	--									 and aschg1.date_changed >= @start_date and aschg1.date_changed < dateadd(dd, 1, @end_date) and 
	--									exists (select 'true'
	--									    from niacore..auth_status_codes ascd1 WITH (NOLOCK)
	--										 where aschg1.new_auth_status = ascd1.auth_status and
	--											  ascd1.final_status_flag = 1))))) 											  
-------------------------------------------------------------------------				         		
order by ie.car_id,ie.auth_id --isnull(ie.changed_date, ie.action_date)
option (maxdop 1)

update adhoc.dbo.ICR_Eff_Updated_All
set deter_level = 'AR' where deter_level = 'NA'

update adhoc.dbo.ICR_Eff_Updated_All
set Final_Outcome_Category = case when final_outcome = 'A' then 'Approval'
					              when final_outcome <> 'A' and final_auth_status_type in ('C','R') then 'Clinical Denial'
					              else 'Admin Denial'
					         end

/* Get Last ICR on each case */
select ie.car_name,
	   ie.car_id,
	   ie.auth_id, 
	   ie.final_status_date,
	   max(ie.date) as Date
	   
into adhoc.dbo.Max_ICR	   ----select * from adhoc.dbo.Max_ICR
	   
from adhoc.dbo.ICR_EFF_Updated_All ie

where ie.final_status_date is not null

group by ie.car_name,
	   ie.car_id,
	   ie.auth_id, 
	   ie.final_status_date
	   

--***************************************************************************************************
--***************************************************************************************************
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
--RUN THE FOLLOWING OUTPUT SEPERATELY
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
--***************************************************************************************************
--***************************************************************************************************
--***************************************************************************************************
--***************************************************************************************************
 
/* Get Deter Detail */

/*
	 
/* declare local variables */
------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	

Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('72','43')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)


/* declare local variables */
------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	

Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('67','11')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)




/* declare local variables */
----declare @start_date datetime, @end_date datetime ,@car_id int

----/* assign values to local variables */
----select	--@car_id = '67', --43 = Highmark
----	@start_date = '08/01/2017',
----	@end_date = '08/31/2017'		
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	

Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('57','41')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)


------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month		
	
/* Get Case Detail Extract 2*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('23','70','60')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)


------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month		
	
/* Get Case Detail Extract 2*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('66','29')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)





------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	
	
	
/* Get Case Detail Extract 2*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('39','47','78')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)


------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	
	
/* Get Case Detail Extract 2*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('83','112','134','115','100','116','119','118','128','117')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)




------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	
	
/* Get Case Detail Extract 2*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('56','55','73','87','94','137','89','88','13','76','108','53','14')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)

------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'		
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	
	
/* Get Case Detail Extract 3*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('51','54','65','71')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)	 


------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'		
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	
	
	
/* Get Case Detail Extract 3*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('59','80','84','85')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)



----declare @start_date datetime, @end_date datetime ,@car_id int

----/* assign values to local variables */
----select	--@car_id = '67', --43 = Highmark
----	@start_date = '08/01/2017',
----	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	
		
/* Get Case Detail Extract 3*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id in ('74','75','77','81','91','93','99','79','96','97')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)



------declare @start_date datetime, @end_date datetime ,@car_id int

/* assign values to local variables */
----select	--@car_id = '67', --43 = Highmark
----	@start_date = '08/01/2017',
----	@end_date = '08/31/2017'	
	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month
	
	
	
/* Get Case Detail Extract 3*/
Select Distinct ie.*,
	case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.car_id not in ('43','67','23','70','11','72','60','66','29','39','47','78','57','41',	
						'83','112','134','115','100','116','119','118','128','117',
'56','55','73','87','94','137','89','88','13','76','108','53','14','51','54','65','71','59','80','84','85',
'74','75','77','81','91','93','99','79','96','97')
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)	 




*/


--***************************************************************************************************
--***************************************************************************************************
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
--TOTAL ROW COUNT CHECK
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
--***************************************************************************************************
--***************************************************************************************************
--***************************************************************************************************
--***************************************************************************************************

/* Get Count of Cases */
------declare @start_date datetime, @end_date datetime ,@car_id int

/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'		

SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month


Select count(*)				
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
--order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1)



/* declare local variables */
------declare @start_date datetime, @end_date datetime ,@car_id int

------/* assign values to local variables */
------select	--@car_id = '67', --43 = Highmark
------	@start_date = '08/01/2017',
------	@end_date = '08/31/2017'	

	
SET   @start_date =   DATEADD(MM,-1,DATEADD(MM,DATEDIFF(MM,0, GetDate()),0)) -- use prior month begin
SET   @end_date  =   DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0, GetDate()),0))  --- use last day of prior month	


Select Distinct ie.*

,case when ie.CPT4_Code_ICR_Team = ie.Specialty_Team_new then 'Y' else 'N' end as 'ICR_Team_new'		


INTO adhoc.dbo.ICR_EFF_Updated_ICR_only 	-----select *from 	adhoc.dbo.ICR_EFF_Updated_ICR_only 
from adhoc.dbo.ICR_EFF_Updated_All ie
	 join adhoc.dbo.Max_ICR i on (ie.car_id = i.car_id and ie.auth_id = i.auth_id and ie.Date = i.Date)
Where ie.title = 'Initial Clinical Reviewer'
------and ie.car_id in ('72','43')    ---------------full run as an option to separate cut and pasting  JHV 6.1.2018
and ie.final_status_date >= @start_date  
and ie.final_status_date  < dateadd(dd,1, @end_date)
order by ie.car_id, ie.auth_id, ie.date
option (maxdop 1) 
/*

SELECT '******increments of 10,000 to allow for non-crash pasting ******'
SELECT * FROM #rows WHERE rownumber > 0			 and rownumber <= 10000
SELECT * FROM #rows WHERE rownumber > 10000 and rownumber <= 20000
SELECT * FROM #rows WHERE rownumber > 20000 and rownumber <= 30000
SELECT * FROM #rows WHERE rownumber > 30000 and rownumber <= 40000
SELECT * FROM #rows WHERE rownumber > 40000 and rownumber <= 50000
SELECT * FROM #rows WHERE rownumber > 50000 and rownumber <= 60000
SELECT * FROM #rows WHERE rownumber > 60000 and rownumber <= 70000
SELECT * FROM #rows WHERE rownumber > 70000 and rownumber <= 80000
SELECT * FROM #rows WHERE rownumber > 80000 and rownumber <= 90000
SELECT * FROM #rows WHERE rownumber > 90000 and rownumber <= 100000
SELECT * FROM #rows WHERE rownumber > 100000 and rownumber <= 110000
SELECT * FROM #rows WHERE rownumber > 110000 and rownumber <= 120000
SELECT * FROM #rows WHERE rownumber > 120000 and rownumber <= 130000
SELECT * FROM #rows WHERE rownumber > 130000 and rownumber <= 140000
SELECT * FROM #rows WHERE rownumber > 140000 and rownumber <= 150000
SELECT * FROM #rows WHERE rownumber > 150000 and rownumber <= 160000
SELECT * FROM #rows WHERE rownumber > 160000 and rownumber <= 170000
SELECT * FROM #rows WHERE rownumber > 170000 and rownumber <= 180000
SELECT * FROM #rows WHERE rownumber > 180000 and rownumber <= 190000
SELECT * FROM #rows WHERE rownumber > 190000 and rownumber <= 200000

*/