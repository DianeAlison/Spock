/** RITM0346585 Response from Frank Noll 10/22/2021: Registration Only is determined by the "auto_auth_flag" The two basic tables are listed below with queries by client/authorization_type. **/

--Health carrier Registration determination ---------------------------------
declare @car_id int = 54					--159
declare @authorization_type_id tinyint = 2	--16

select * from health_carrier_auth_type_flags a
where flag_type_id = 21
and car_id = @car_id

select a.* from niacore..car_cpt4 a
inner join niacore..cpt4_codes b on a.cpt4_code = b.cpt4_code
inner join niacore..authorization_type_exams c on b.exam_cat_id = c.exam_cat_id
and a.date_inactive is null
--and a.auth_noprocess_flag = 0
and a.auto_auth_flag = 1
and c.authorization_type_id = @authorization_type_id
and a.car_id = @car_id

--Health Plan Registration determination ---------------------------------------
declare @car_id int = 54 --159
declare @authorization_type_id tinyint = 2 --16

select * from health_plan_auth_type_flags a
inner join niacore..health_plan b on a.plan_id = b.plan_id
where flag_type_id = 21
and b.car_id = @car_id

--Health Plan
select d.plan_id, a.* from niacore..plan_cpt4 a
inner join niacore..cpt4_codes b on a.cpt4_code = b.cpt4_code
inner join niacore..authorization_type_exams c on b.exam_cat_id = c.exam_cat_id
inner join niacore..health_plan d on a.plan_id = d.plan_id
and a.date_inactive is null
--and a.auth_noprocess_flag = 0
and a.auto_auth_flag = 1
and c.authorization_type_id = @authorization_type_id
and d.car_id = @car_id
order by 1

/** RITM0346585 Additional Response from Frank Noll 10/22/2021: This table also is used.  Apparently also it has some information for HMSA/Aetna. **/

--Health carrier Registration determination ---------------------------------
declare @car_id int = 54  --159
declare @authorization_type_id tinyint = 2 --16

select a.cpt4_code,  b.cpt4_descr, d.description from niacore..auto_auth_criteria_group a 
inner join niacore..cpt4_codes b on a.cpt4_code = b.cpt4_code
inner join niacore..authorization_type_exams c on b.exam_cat_id = c.exam_cat_id
inner join niacore..auto_auth_criteria d on a.auto_auth_criteria_id = d.auto_auth_criteria_id
where a.car_id = @car_id
and a.date_inactive is null 
and c.date_inactive is null
and c.authorization_type_id = @authorization_type_id   
order by 1

--Health Plan  Registration determination ---------------------------------
declare @car_id int = 54  --159
declare @authorization_type_id tinyint = 2 --16

select e.plan_name, a.cpt4_code,  b.cpt4_descr, d.description from niacore..auto_auth_criteria_group a 
inner join niacore..cpt4_codes b on a.cpt4_code = b.cpt4_code
inner join niacore..authorization_type_exams c on b.exam_cat_id = c.exam_cat_id
inner join niacore..auto_auth_criteria d on a.auto_auth_criteria_id = d.auto_auth_criteria_id
inner join niacore..health_plan e on a.plan_id = e.plan_id
where e.car_id = @car_id
and a.date_inactive is null 
and c.date_inactive is null
and c.authorization_type_id = @authorization_type_id   
order by 1,2