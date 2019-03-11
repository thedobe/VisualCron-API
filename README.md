# VisualCron-API
Leverages the API of VisualCron for analysis of jobs, tasks, etc

VisualCron (at least the version used at my last company [cannot remember the version 2.6X?]) had terrible reporting. Also, it was a flyby wire documented schedulder. Meaning, if Bob created a job and didn't give any type of description to anything it could inflict a lot of pain.

The usp_vc_job_populate_tables.sql sproc is pretty brutal, but, there was no access to VC's 'time' (or 'scheduling') lib. It's an extremely over convoluted way of populating a visual schedule for someone to read. 

If your company has a lot of inline SQL jobs, remote calls, or tasks firing other tasks this COULD help tremendously.

NOTE: Each job HAS to have its trigger specificed in a specific way e.g., Daily at 9:00AM, Daily every 30 minute(s) between 8:00AM - 7:00PM, Every Monday between 7:00AM - 10:30PM, etc.
