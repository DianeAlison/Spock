--dB:			Avaya-p

select
 logid
,row_date
,sum(acdcalls) acd_calls
,sum(i_acdtime) acd_talk_time
,sum(acwtime) acd_acw_time
,sum(holdacdtime) acd_hold_time
from
 root.dagent
where
        row_date = ?
and acd =1
and split in (10,11,186,215,225,226,230,235,129,804,165,230,174,209,139,219,235,207,208)
group by
 logid
,row_date
order by
 logid
,row_date