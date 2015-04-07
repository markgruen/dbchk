# dbchk
 This is a handy script developed to quickly assess client sites database environments.

The script provides a detailed and quick assessment of the database environment to aid in quickly putting together an action plan. The script checks for NLS settings, version and patch level, OS memory, kernel, file system, number of cores, db size, database file system layout, control files, wallet files, default passwords, db option usage, non default parameters, oracle memory, auditing and auditing cleanup, archive logs, object counts formated in a fancy cross-tab, index counts, large tables without indexes, segments with high number of extents, backup up summaries, and standby communication setup and errors. We look at undo history because from here we can get a sense how busy the database is and long running queues, session statistics, and patch level from oracle inventory.

While writing this article I realized the script is missing showing how many instances are running and configured on the host. I will add this as a to do. This is a good use case to show how powerful and easy it is to use python with shell scripts where python is doing the heavy lifting. I've implemented this functionality in a pure shell script in oraenv_local and we can compare how much easier it is to use python to do the heavy lifting while still using it like a shell script.

Another less obvious feature is the log file naming convention. This was done so you could run a many reports on many systems and review them and still provide enough meta data to know which databases the reports were run against.

The dbchk.sql generates 3 files:

    dbchk_<instance_name>_<host>.log
    dbchk_undo_history_<instance_name>_<host>.log
    dbchk_undo_sql_hist_<instance_name>_<host>.log

The script generates a lot of output, so the output is separated into 3 files. The first shows the general output while the last two contain the undo history information that can be used to get a sense of how busy the database is and also we can see the SQL that is running. These files may contain sensitive information which is another reason why I split these off from the main output. 
