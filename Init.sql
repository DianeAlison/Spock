SET ThousandSep=',';
SET DecimalSep='.';
SET MoneyThousandSep=',';
SET MoneyDecimalSep='.';
SET MoneyFormat='$#,##0.00;($#,##0.00)';
SET TimeFormat='h:mm:ss TT';
SET DateFormat='M/D/YYYY';
SET TimestampFormat='M/D/YYYY h:mm:ss[.fff] TT';
SET MonthNames='Jan;Feb;Mar;Apr;May;Jun;Jul;Aug;Sep;Oct;Nov;Dec';
SET DayNames='Mon;Tue;Wed;Thu;Fri;Sat;Sun';
SET FirstWeekDay=0;
?
Let vReload = today(1);
Let vRDate = date(today(),'YYYY-MM-DD');
Let vQuarterNum = if(Num(Ceil( Month('$(vReload)')/ 3 ), 'Q0')='Q4', 'Q3',
            if(Num(Ceil( Month('$(vReload)')/ 3 ), 'Q0')='Q3', 'Q2',
                    if(Num(Ceil( Month('$(vReload)')/ 3 ), 'Q0')='Q2', 'Q1',
                    if(Num(Ceil( Month('$(vReload)')/ 3 ), 'Q0')='Q1', 'Q4')))) & '_' & year(QuarterStart('$(vReload)',-1));
Let  vDatePeriod = year(QuarterStart('$(vReload)',-1)) & '-' & if(Num(Ceil( Month('$(vReload)')/ 3 ), 'Q0')='Q4', 'Q3',
            if(Num(Ceil( Month('$(vReload)')/ 3 ), 'Q0')='Q3', 'Q2',
                    if(Num(Ceil( Month('$(vReload)')/ 3 ), 'Q0')='Q2', 'Q1',
                    if(Num(Ceil( Month('$(vReload)')/ 3 ), 'Q0')='Q1', 'Q4'))));
                    
Let vQuarterYear = quartername('$(vReload)',-1);  
?
?
//Get Standard File Paths
Set vQVDPath = 'lib://AppFiles/2_FileGenerators/OutputFiles/Consolidated';
Set vPrebuiltQVDPath = 'lib://AppFiles/2_FileGenerators/OutputFiles/PrebuiltDashboardFiles';
?
//Pomerol standard variables
Let vStartTime = now();
?
//Use for keys and front-end fields that should be not included in data model or current selections
Set hideprefix = '%';   
?
let vStartDate = Timestamp(floor(QuarterStart(Today(1),-1)));
let vEndDate = Timestamp(floor(QuarterEnd(Today(1),-1)));
?
LIB CONNECT TO 'Nile-R1';
//LIB CONNECT TO 'Microsoft_SQL_Server_Nile-R1 (mbh_butlera)';
//LIB CONNECT TO 'Microsoft_SQL_Server_nile-r1 (mbh_gogaa)';
?
?
?