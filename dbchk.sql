/* 
-------------------------------------------------------------------------------
$Header: http://mysvn/svn/DBA/trunk/sql/dbchk.sql 197 2013-12-26 15:25:28Z  $                                              
 Revision of last commit: $Rev: 413 $
 Author of last commit:   $Author: mgruen $
 Date of last commit:     $Date: 2015-03-10 18:50:03 -0400 (Tue, 10 Mar 2015) $
-------------------------------------------------------------------------------
 
 Check db script
 by Mark Gruenberg
 
 07/11/12 by Mark Gruenberg
   added extents
   index counts
   inventory
 
 add top 10 waits
 redo log size
 busiest segment
 auditing
 asm info
 -- for ABC 
 users
 user sys privs
 user tab privs
 user role privs
 columns with balance
 -- added
 nls

 ----------
 To do:
 ----------

 Add check for indexes on fk columns

 Copyright (C) 2014 Mark Gruenberg

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.

* ------------------------------------------------------------------------------ */
set lines 500
set pages 20000
set trimout on
set trimspool on
-- set echo on

-- getting spool name
variable host varchar2(40)
variable instance varchar2(40)

begin
select INSTANCE_NAME into :instance from v$instance;
select HOST_NAME into :host from v$instance;
end;
/

col spoolname new_value spoolname
col undospoolname new_value undospoolname
col undosqlspoolname new_value undosqlspoolname

select 'dbchk_'||:instance||'_'||:host||'.log' spoolname from dual;
select 'dbchk_undo_hist_'||:instance||'_'||:host||'.log' undospoolname from dual;
select 'dbchk_undo_sql_hist_'||:instance||'_'||:host||'.log' undosqlspoolname from dual;

col wrl_parameter new_value wallet_path
select wrl_parameter wallet_path from  gv$encryption_wallet;

spo '&spoolname'

--db information
prompt --DB Information
prompt --  Script by Mark Gruenberg
prompt --  Copyright (C) 2014 Mark Gruenberg
col instance_name for a10
col protection_mode for a25
col db_unique_name for a10
col host_name for a20

select
instance_number,instance_name,host_name,db_unique_name,version,created,resetlogs_time,prior_resetlogs_time,log_mode,remote_archive,flashback_on,protection_mode
from gv$instance inner join gv$database using (inst_id)
order by inst_id;

prompt -- Update history
col action_time for a28
col version for a10
col comments for a35
col action for a25
col namespace for a12
select * from registry$history;

prompt -- DB High water marks 
col description for a60
col name for a40
select * from DBA_HIGH_WATER_MARK_STATISTICS;

prompt -- installed database options
col value for a10
select * from v$option;
col value clear

prompt -- NLS Settings
col parameter for a30
col db_value for a30
col inst_value for a30
selecT dp.parameter,dp.value db_value, dp.value inst_value 
from nls_database_parameters dp inner join nls_instance_parameters ip
  on ip.parameter = dp.parameter;
col db_value clear
col inst_value clear

prompt -- standby destinations
col DEST_NAME for a30 
col DESTINATION for a60
col error for a60

select DEST_NAME, DESTINATION, status, error from  v$archive_dest_status
order by status,error,DEST_NAME;

prompt -- Option Usage
col name for a60
col description for a126
SELECT name, currently_used,last_usage_date,description from dba_feature_usage_statistics
order by currently_used, name;

prompt -- Registery

col comp_id for a10
col comp_name for a40
col version for a11

select comp_id, comp_name, version, status from dba_registry
;

spo off

!echo "" | tee -a '&spoolname'
!echo "-- Unix kernal UNAME" | tee -a '&spoolname'
!uname -a | tee -a '&spoolname'

!echo "" | tee -a '&spoolname'
!echo "-- Mount Points" | tee -a '&spoolname'
!mount | tee -a '&spoolname'

!echo "" | tee -a '&spoolname'
!echo "-- Memory Info" | tee -a '&spoolname'
!cat /proc/mem* | tee -a '&spoolname'

!echo "" | tee -a '&spoolname'
!echo "-- CPU Info" | tee -a '&spoolname'
!cat /proc/cpu* | tee -a '&spoolname'

!echo "" | tee -a '&spoolname'
!echo "-- File System Usage" | tee -a '&spoolname'
!df -k | tee -a '&spoolname'

!echo "" | tee -a '&spoolname'
spo '&spoolname' append

prompt --Physical Memory
col stat_name for a30
with db as (
  select inst_id, dbid, name database_name, instance_name, version, host_name
  from gv$database d inner join gv$instance using (inst_id)
)
select
  to_char(end_interval_time, 'MM-DD-YY HH24:MI') ddate, inst_id, s.dbid, database_name, instance_name, version, host_name, stat_name, value
from DBA_HIST_OSSTAT s inner join dba_hist_snapshot h
  on (s.snap_id=h.snap_id and s.instance_number=h.instance_number and s.dbid=h.dbid)
join db
  on (db.dbid=s.dbid and db.inst_id=s.instance_number)
where
  stat_name='PHYSICAL_MEMORY_BYTES'
  and begin_interval_time>sysdate-2
  and end_interval_time > sysdate-2
order by h.snap_id desc, inst_id
/


prompt --DB SIZE

with dbsize as
(select ' '||tablespace_name tablespace_name,sum(bytes)/(1024*1024) size_mb from dba_data_files group by tablespace_name
union all
select ' '||tablespace_name,sum(bytes)/(1024*1024) size_mb from dba_temp_files group by tablespace_name
union all
select 'LOGFILES',sum(bytes)/(1024*1024) size_mb from v$log
)
select * from dbsize
union all
select 'Total',sum(size_mb) from dbsize
order by 1;


prompt --Control File Location
col name for a100
select * from v$controlfile;

prompt -- file layout

select 'datafile' "TYPE", name,bytes from v$datafile
union all
select 'tempfile',name,bytes from v$tempfile
union all
select 'logfile',member,bytes from v$logfile inner join v$log using (group#)
union all
select 'standbylog', member,bytes from v$logfile inner join v$standby_log using (group#)
order by 1, 2
;

prompt -- RAC instances/temp datafiles
with
  instance_count as (
    select count(*) instances from gv$instance),
  tempfile_count as (
    select count(*) temp_files from v$tempfile)
select instances, temp_files
from instance_count cross join tempfile_count
;


-- db wallet parameters
prompt -- db wallet parameters
col wrl_parameter for a70
select * from  gv$encryption_wallet;

prompt -- wallet permissions
!ls -ld '&wallet_path'
!ls -l '&wallet_path'

prompt -- db wallet
select * from gv$wallet;

-- db create parameters
prompt --DB Create Parameters

select 'MAXLOGHISTORY',records_total from v$controlfile_record_section where type like 'LOG HISTORY'
union all
select 'MAXDATAFILES',records_total from v$controlfile_record_section where type like 'DATAFILE'
union all
select 'MAXLOGMEMBERS',records_total from v$controlfile_record_section where type like 'REDO LOG'
;

prompt -- Hours of redo in Redo logs
select cast(max(next_time) - min(first_time) as number)*24 hours from v$log;

-- redolog and standby redo
prompt -- redolog and standby redo

col member for a70

select group#, thread#, type, member, bytes, blocksize,archived, to_char(first_time,'MM/DD/YY HH24:MI:SS') first_time, to_char(next_time,'MM/DD/YY HH24:MI:SS') next_time
from v$logfile inner join v$log using (group#)
union all
select group#, thread#, type, member, bytes, blocksize,archived, to_char(first_time,'MM/DD/YY HH24:MI:SS') first_time, to_char(next_time,'MM/DD/YY HH24:MI:SS') next_time
from v$logfile inner join v$standby_log using (group#)
order by type,group#,thread#,member;


-- High Water marks
prompt --High Water marks

col description for a80
col name for a30
select * from DBA_HIGH_WATER_MARK_STATISTICS
order by version, name;

prompt -- shared pool advice

select
INST_ID,
SHARED_POOL_SIZE_FOR_ESTIMATE size_est,
SHARED_POOL_SIZE_FACTOR size_fact,
ESTD_LC_SIZE,
ESTD_LC_MEMORY_OBJECTS est_lc_objects,
ESTD_LC_TIME_SAVED est_lc_tim_sav,
ESTD_LC_TIME_SAVED_FACTOR est_lc_time_sav_fact,
ESTD_LC_LOAD_TIME,
ESTD_LC_LOAD_TIME_FACTOR est_lc_loadtime_fact,
ESTD_LC_MEMORY_OBJECT_HITS est_lc_mem_obj_hits
from  gV$SHARED_POOL_ADVICE
order by inst_id,SHARED_POOL_SIZE_FOR_ESTIMATE
;


-- init parameters
col display_value for a90
col description for a80

prompt --INIT Parameters

select instance_name inst_name, name,display_value,ismodified,description 
from gv$parameter inner join gv$instance using(inst_id)
where isdefault='FALSE' or ismodified='TRUE'
order by name,inst_id;

col display_value clear
col description clear


-- SGA allocation
prompt --SGA Allocation
col name for a30
select * from gv$sga
order by inst_id, name

-- Calculate MEMORY_TARGET
prompt --Calculate MEMORY_TARGET

SELECT sga.value + GREATEST(pga.value, max_pga.value) AS cal_memory_target
FROM (SELECT TO_NUMBER(value) AS value FROM v$parameter WHERE name = 'sga_target') sga,
     (SELECT TO_NUMBER(value) AS value FROM v$parameter WHERE name = 'pga_aggregate_target') pga,
     (SELECT value FROM v$pgastat WHERE name = 'maximum PGA allocated') max_pga;

-- Memory values
COLUMN name FORMAT A30
COLUMN value FORMAT A10

prompt --Memory Values

col value for a50
SELECT inst_id, name, value
FROM gv$parameter
WHERE name IN ('pga_aggregate_target', 'sga_target', 'sga_max_size','memory_max_target')
UNION ALL
SELECT inst_id, 'maximum PGA allocated' AS name, TO_CHAR(value) AS value
FROM gv$pgastat
WHERE name = 'maximum PGA allocated'
order by inst_id,name
;

col value clear

-- dynamic memory
prompt --Dynamic Memory

col component for a30

SELECT  inst_id, component, current_size, min_size, max_size
FROM    gv$memory_dynamic_components
WHERE   current_size != 0
order by component, inst_id
;

-- target advice
prompt --Target Advice
col version clear

SELECT * FROM gv$memory_target_advice ORDER BY memory_size;

prompt -- default passwords

select username, password_versions,account_status
from dba_users 
  inner join dba_users_with_defpwd 
    using (username)
order by account_status, username;

prompt -- users
select username,account_status from dba_users
order by account_status, username;

prompt -- user sys privs
select grantee,privilege, admin_option from dba_sys_privs where grantee not in
('ANONYMOUS', 'APPQOSSYS', 'CTXSYS', 'DBSNMP','DIP', 'EXFSYS', 'MGMT_VIEW', 'OLAPSYS',
 'ORACLE_OCM', 'OUTLN', 'SYS', 'SYSMAN','SYSTEM', 'WMSYS', 'XDB', 'XS$NULL',
 'APEX_030200', 'APEX_PUBLIC_USER', 'AQ_ADMINISTRATOR_ROLE', 'BI', 'DBA',
 'HR', 'MDSYS', 'OEM_ADVISOR', 'OLAP_DBA', 'OLAP_USER', 'OWB$CLIENT', 'OWBSYS',
 'SPATIAL_CSW_ADMIN_USR', 'SPATIAL_WFS_ADMIN_USR' )
 order by grantee,privilege,admin_option;

set pages 35000

prompt -- user tab privs
select grantee, owner, table_name, privilege, grantable, hierarchy from dba_tab_privs
order by grantee, owner, table_name, grantable

/*
set pages 20000
-- investigating sensitive data columns for data hiding
prompt -- finding tables with a balance column
select owner, table_name, column_name from dba_tab_columns
where column_name like '%BAL%'
and owner not in
(
'APEX_030200',
'SYSMAN',
'SYSTEM',
'SYS')
order by 1,2;
*/

prompt -- auditing

col name for a30
col display_value for a40

select name, display_value, isdefault from v$parameter where name like 'audit%'
order by name
;

-- audit parameters
prompt -- audit parameters
prompt 

col PARAMETER_NAME for a40
col PARAMETER_VALUE for a30

select * from dba_audit_mgmt_config_params;

prompt -- audit trail commit delay if it takes more than this amout it will write audit record to the OS

select sys.DBMS_AUDIT_MGMT.GET_AUDIT_COMMIT_DELAY from dual;

-- auditing cleanup initialized
prompt -- auditing cleanup initialized

set serveroutput on
declare
  type table_audits  is table of integer(10);
  type table_audit_names  is table of varchar2(30);
  var_table_audits  table_audits;
  var_table_audit_names  table_audit_names;
  out varchar2(100);
begin
  var_table_audits  := table_audits(sys.DBMS_AUDIT_MGMT.AUDIT_TRAIL_AUD_STD,
                                    sys.DBMS_AUDIT_MGMT.AUDIT_TRAIL_FGA_STD,
                                    sys.DBMS_AUDIT_MGMT.AUDIT_TRAIL_OS,
                                    sys.DBMS_AUDIT_MGMT.AUDIT_TRAIL_XML,
                                    sys.DBMS_AUDIT_MGMT.AUDIT_TRAIL_ALL);
  var_table_audit_names := table_audit_names('AUDIT_TRAIL_AUD_STD',
                                             'AUDIT_TRAIL_FGA_STD',
                                             'AUDIT_TRAIL_OS',
                                             'AUDIT_TRAIL_XML',
                                             'AUDIT_TRAIL_ALL');
  for elem in 1 .. var_table_audits.count loop
    --dbms_output.put_line(elem || ': ' || var_table_audits(elem) || ': '|| var_table_audit_names(elem));
    out := var_table_audit_names(elem) ||' : ';
    IF sys.DBMS_AUDIT_MGMT.IS_CLEANUP_INITIALIZED(var_table_audits(elem))
    then
      dbms_output.put_line(out ||' TRUE');
    else
      dbms_output.put_line(out ||' FALSE');
    end if;
  end loop;
end;
/


-- audit trail counts
prompt -- audit trail counts
prompt 
select 'standard_audit_tail count' audit_trial,count(*)  from sys.aud$
union all
select 'finegrain_audit_tail count',count(*)  from sys.fga_log$
;

-- audit min and max dates
prompt -- audit min and max dates

select 'com_audit_trail', min(extended_timestamp) min_date, max(extended_timestamp) max_date from DBA_COMMON_AUDIT_TRAIL
union all
select 'fg_audit_trail', min(extended_timestamp) min_date, max(extended_timestamp) max_date from DBA_FGA_AUDIT_TRAIL
;

-- audit last archive time
prompt -- audit last archive time

select * from DBA_AUDIT_MGMT_LAST_ARCH_TS;

-- audit clean events
prompt-- audit clean events
col CLEANUP_TIME for a40

select * 
from dba_audit_mgmt_clean_events 
where cleanup_time > current_timestamp - interval '45' day
order by cleanup_time desc;

-- fine grain audit policies
prompt -- fine grain audit policies
col policy_text for a60
select * from DBA_AUDIT_POLICIES;

prompt -- object policies
select * from dba_obj_audit_opts;

prompt -- privilege policies
select * from DBA_PRIV_AUDIT_OPTS;


-- database object counts
prompt --Database Object Counts

select DECODE(GROUPING(a.owner), 1, 'All Owners',
a.owner) AS "Owner",
count(case when a.object_type = 'TABLE' then 1 else null end) "Tables",
count(case when a.object_type = 'INDEX' then 1 else null end) "Indexes",
count(case when a.object_type = 'PACKAGE' then 1 else null end) "Packages",
count(case when a.object_type = 'SEQUENCE' then 1 else null end) "Sequences",
count(case when a.object_type = 'TRIGGER' then 1 else null end) "Triggers",
count(case when a.object_type not in
('PACKAGE','TABLE','INDEX','SEQUENCE','TRIGGER') then 1 else null end) "Other",
count(case when 1 = 1 then 1 else null end) "Total"
from dba_objects a
group by rollup(a.owner)
;

-- index counts
prompt --Index Counts

col index_type for a25

with indexes as
(
select table_owner,table_name,index_type,
   count(*) OVER (PARTITION BY table_owner,table_name,index_type ) NUM_INDEXES,
   count(*) OVER (PARTITION BY table_owner,table_name ) total_indexes
from dba_indexes
where
   table_owner not in
   ('ANONYMOUS', 'APPQOSSYS', 'CTXSYS', 'DBSNMP','DIP', 'EXFSYS', 'MGMT_VIEW', 'OLAPSYS', 
    'ORACLE_OCM', 'OUTLN', 'SYS', 'SYSMAN','SYSTEM', 'WMSYS', 'XDB', 'XS$NULL' )
-- add APEX_030200 FLOWS_FILES MDSYS
)
select table_owner,table_name,index_type,num_indexes num_indx_by_type,total_indexes 
from indexes 
group by table_owner,table_name,index_type,num_indexes,total_indexes
order by table_owner,total_indexes desc, table_name,index_type
;

-- segments extents
prompt --Segment Extents

col segment_name for a30
col owner for a20

select OWNER, segment_name,PARTITION_NAME,tablespace_name,extents,bytes/(1024*1024) mbytes 
from dba_segments 
where owner not in
('ANONYMOUS', 'APPQOSSYS', 'CTXSYS', 'DBSNMP','DIP', 'EXFSYS', 'MGMT_VIEW', 'OLAPSYS',
'ORACLE_OCM', 'OUTLN', 'SYS', 'SYSMAN','SYSTEM', 'WMSYS', 'XDB', 'XS$NULL') 
and extents>10 
order by extents desc
;

prompt --Segment Extents Summary

with extents as
(
  select OWNER, segment_name,PARTITION_NAME,tablespace_name,extents,bytes/(1024*1024) mbytes
    ,case when extents>0  and extents<=10  then 1 else 0 end "1_to_10"
    ,case when extents>10 and extents<=20  then 1 else 0 end "10_to_20"
    ,case when extents>20 and extents<=50  then 1 else 0 end "20_to_50"
    ,case when extents>50 and extents<=100 then 1 else 0 end "50_to_100"
    ,case when extents>100                 then 1 else 0 end "more_100"
from dba_segments
)
select owner, sum("1_to_10"), sum("10_to_20"), sum("20_to_50"), sum("50_to_100"), sum("more_100")
from extents
where owner not in
  ('ANONYMOUS', 'APPQOSSYS', 'CTXSYS', 'DBSNMP','DIP', 'EXFSYS', 'MGMT_VIEW', 'OLAPSYS',
  'ORACLE_OCM', 'OUTLN', 'SYS', 'SYSMAN','SYSTEM', 'WMSYS', 'XDB', 'XS$NULL') 
group by owner
;

prompt -- Database backup summary
col input_bytes_display for a10
col output_bytes_display for a10

select
to_char(min_checkpoint_time,'MM/DD/YYYY HH24:MI:SS') first_time,
num_files_backed,
num_distinct_files_backed,
input_bytes_display,
output_bytes_display,
compression_ratio
from 
sys.V_$BACKUP_DATAFILE_SUMMARY
where trunc(min_checkpoint_time) > trunc(sysdate)-10
;

prompt -- Archivelog backup summary

select to_char(min_first_time,'MM/DD/YYYY HH24:MI:SS') first_time,
num_files_backed, 
num_distinct_files_backed,
input_bytes_display,
output_bytes_display,
compression_ratio
from sys.V_$BACKUP_ARCHIVELOG_SUMMARY
where trunc(min_first_time)> trunc(sysdate)-10
;

prompt -- Rman Backup Summary
col elapsed_seconds heading "ELAPSED|SECONDS"
col compression_ratio heading "COMPRESSION|RATIO"
col output_instance heading "OUTPUT|INSTANCE"
col output_rate for a10 heading "OUTPUT|RATE"
col time_taken for a10 heading "TIME|TAKEN"
col output_bytes for a10 heading "OUTPUT|BYTES"
col output_rate for a10 heading "OUTPUT|RATE"
col status for a15
col cf for 9,999
col df for 9,999
col i0 for 9,999
col i1 for 9,999
col l for 9,999

with 
  bkup_set_details as (
  select
    d.session_recid, d.session_stamp,
    sum(case when d.controlfile_included = 'YES' then d.pieces else 0 end) CF,
    sum(case when d.controlfile_included = 'NO'
             and d.backup_type||d.incremental_level = 'D' then d.pieces else 0 end) DF,
    sum(case when d.backup_type||d.incremental_level = 'D0' then d.pieces else 0 end) I0,
    sum(case when d.backup_type||d.incremental_level = 'I1' then d.pieces else 0 end) I1,
    sum(case when d.backup_type = 'L' then d.pieces else 0 end) L
  from
    V$BACKUP_SET_DETAILS d
    join v$backup_set s on s.set_stamp = d.set_stamp and s.set_count = d.set_count
  where 
    s.input_file_scan_only = 'NO'
  group by d.session_recid, d.session_stamp
  )
  ,
  rman_out as (
  select o.session_recid, o.session_stamp, min(inst_id) inst_id
    from gv$rman_output o
  group by o.session_recid, o.session_stamp
  )
select
--  j.session_recid, j.session_stamp,
  to_char(j.start_time, 'yyyy-mm-dd hh24:mi:ss') start_time,
--  to_char(j.end_time, 'yyyy-mm-dd hh24:mi:ss') end_time,
  j.input_type,
  j.status, 
  decode(to_char(j.start_time, 'd'), 1, 'Sunday', 2, 'Monday',
                                     3, 'Tuesday', 4, 'Wednesday',
                                     5, 'Thursday', 6, 'Friday',
                                     7, 'Saturday') day,
  j.output_bytes_display output_bytes,
  j.output_bytes_per_sec_display output_rate,                                     
  round(j.elapsed_seconds,2) elapsed_seconds, 
  j.time_taken_display time_taken,
  round(j.compression_ratio,2) compression_ratio,
  x.cf, x.df, x.i0, x.i1, x.l,
  ro.inst_id output_instance
from v$rman_backup_job_details j
  left outer join bkup_set_details x
    on x.session_recid = j.session_recid and x.session_stamp = j.session_stamp
  left outer join rman_out ro
    on ro.session_recid = j.session_recid and ro.session_stamp = j.session_stamp
where j.start_time > trunc(sysdate)-20
order by j.start_time;


spo off
set echo off
set heading off
spo ttschk.sql
prompt --  Script by Mark Gruenberg
prompt --  Copyright (C) 2014 Mark Gruenberg
--tts dependencies
select 'exec sys.DBMS_TTS.TRANSPORT_SET_CHECK('''||wm_concat(name)||''');' from v$tablespace where name not in ('SYSTEM','SYSAUX','TEMP') and name not like 'UNDO%';
spo off

-- top 10 wait events for each session
prompt -- top 10 wait events for each session

select sid,sh.seq#,username,osuser,machine,type,sh.event,sh.p1text,sh.p1,sh.p2text,sh.p2,sh.p3text,sh.p3,
sh.wait_time, sh.time_since_last_wait_micro
from v$session s inner join v$session_wait_history sh using (sid)
order by sid,sh.wait_time
;


set heading on
-- set echo on

--DBA_HIST_UNDOSTAT

prompt --UNDO Tablespaces
select TABLESPACE_NAME,BLOCK_SIZE,CONTENTS from dba_tablespaces where contents='UNDO';

prompt --DBA_HIST_UNDOSTAT

select max(UNDOBLKS),max(TXNCOUNT),max(MAXQUERYLEN),max(MAXCONCURRENCY),max(SSOLDERRCNT),max(NOSPACEERRCNT) from DBA_HIST_UNDOSTAT u inner join dba_hist_snapshot s on (u.snap_id=s.snap_id) where s.snap_flag=0

prompt --Max Query Length in period in Mins

--spo dbchk_undo_hist_sql.log
spo '&undosqlspoolname'
set lines 10000
set pages 50000 
col  MAXQUERYLEN_MIN head 'Max Query |Len (Min)'
--set recsep wrapped
set colsep "|"
--set recsepchar "~"

select to_char(begin_time,'DD/MM/YY HH24:MI:SS') begin_time,to_char(end_time,'HH24:MI:SS') end_time, (end_time-begin_time)*24*60 interval_min,TXNCOUNT,round(MAXQUERYLEN/60,2) maxquerylen_min,
SSOLDERRCNT,
SQL_FULLTEXT
from DBA_HIST_UNDOSTAT u inner join v$sql s on (u.maxquerysqlid=s.sql_id)
where begin_time > sysdate-10
order by begin_time
;

col  MAXQUERYLEN_MIN clear

spo off

prompt --UNDO Stats History

spo '&undospoolname'
--spo dbchk_undo_hist.log
prompt --  Script by Mark Gruenberg
prompt --  Copyright (C) 2014 Mark Gruenberg

select to_char(begin_time,'MM/DD/YY HH24:MI:SS') begin_time,to_char(end_time,'HH24:MI:SS') end_time,round((end_time-begin_time)*24*60,2) interval_min, 
UNDOBLKS,TXNCOUNT,round(MAXQUERYLEN/60,2) maxquerylen_min,
MAXCONCURRENCY,SSOLDERRCNT,NOSPACEERRCNT,TUNED_UNDORETENTION
from DBA_HIST_UNDOSTAT u inner join dba_hist_snapshot s on (u.snap_id=s.snap_id) 
where 
s.snap_flag=0
and begin_time>sysdate-10
order by begin_time;

select to_char(begin_time,'DD/MM/YY HH24:MI:SS') begin_time,to_char(end_time,'HH24:MI:SS') end_time, (end_time-begin_time)*24*60 interval_min,TXNCOUNT,round(MAXQUERYLEN/60,2) maxquerylen_min,
SSOLDERRCNT,
nospaceerrcnt,maxconcurrency,
TUNED_UNDORETENTION
from DBA_HIST_UNDOSTAT u inner join v$sql s on (u.maxquerysqlid=s.sql_id)
where begin_time > sysdate-10
order by begin_time
;

spo off

set colsep " "
set lines 500
spo '&spoolname' append
----spo dbchk.log append

--@ttschk.sql

prompt -- asm client
select * from gv$asm_client;

prompt -- asm disk groups
select * from gv$asm_diskgroup;


/*
-- tts dependencies results
prompt --TTS Dependencies Results

select * FROM sys.transport_set_violations;
*/

prompt -- Sessions Last 10 Wait Events
col sid for 9999
col seq# for 999
col username for a15
col osuser for a15
col machine for a25
col event for a58
col p1text for a20
col p2text for a20
col p3text for a20
col time_since_last_wait_micro heading 'time_since|last_wait|mico'

select to_char(sysdate,'MM/DD/YYYY HH24:MI:SS') run_date from dual;

select sid,sh.seq#,username,osuser,machine,type,sh.event,sh.p1text,sh.p1,sh.p2text,sh.p2,sh.p3text,sh.p3,
sh.wait_time, sh.time_since_last_wait_micro
from v$session s inner join v$session_wait_history sh using (sid)
order by type desc,sid,sh.wait_time desc
;


spo off
set pages 90

--!$ORACLE_HOME/OPatch/opatch lsinventory -detail | tee -a dbchk.log
!$ORACLE_HOME/OPatch/opatch lsinventory -detail | tee -a '&spoolname'

exit;
