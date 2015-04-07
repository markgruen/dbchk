# dbchk
 This is a handy script developed to quickly assess client sites database environments.

The script provides a detailed and quick assessment of the database environment to aid in quickly putting together an action plan. The script checks for NLS settings, version and patch level, OS memory, kernel, file system, number of cores, db size, database file system layout, control files, wallet files, default passwords, db option usage, non default parameters, oracle memory, auditing and auditing cleanup, archive logs, object counts formated in a fancy cross-tab, index counts, large tables without indexes, segments with high number of extents, backup up summaries, and standby communication setup and errors. We look at undo history because from here we can get a sense how busy the database is and long running queues, session statistics, and patch level from oracle inventory.

Check the link for more documentation:

http://wiki.markgruenberg.info/doku.php?id=oracle:script_to_check_oracle_environment_and_health_of_a_database
