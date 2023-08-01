Please run below on Query analyzer connecting to STLMOSQL301 server
--- To view job history of job run below script. Need exact job name in parameter.
exec userUtility.dbo.[spMHCReportsviewjob] 'MHCReports - MINSO001I_Daily PCR Queue Report'

--- To Stop  job that's runing, run below script. Need exact job name in parameter.
exec userUtility.dbo.[spMHCReportsstopjob] 'MHCReports - MINSO001I_Daily PCR Queue Report'

--- To run job, run below script. Need exact job name in parameter.
exec userUtility.dbo.[spMHCReportsrunjob] 'MHCReports - MINSO001I_Daily PCR Queue Report'
