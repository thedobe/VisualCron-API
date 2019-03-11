#database vars
$dbServer = 'someServer'
$db = 'someDb'
$q = ''

# create or truncate respective tables
Invoke-Sqlcmd -Server $dbServer -Database $db -query 'execute [dbo].[usp_vc_job_create_prepare_tables]'

#vicsual cron
$VCpath = 'C:\Program Files (x86)\VisualCron\VisualCron.dll'
$VCAPIpath = 'C:\Program Files (x86)\VisualCron\VisualCronAPI.dll'
  
# load the VisualCron API Dlls
$VC = [Reflection.Assembly]::LoadFrom($VCpath);
$VCAPI = [Reflection.Assembly]::LoadFrom($VCAPIpath);


# Define Client & Server Objects
$Global:Client = New-Object -TypeName VisualCronAPI.Client
$Global:Server = New-Object -TypeName VisualCronAPI.Server

# define Connection Object
$Conn = New-Object -TypeName VisualCronAPI.Connection

# set Connection Values
$Conn.Address = 'Address'
$Conn.UserName = 'UserName'
$Conn.PassWord = 'PassWord'
$Conn.Port = 16444
$Conn.ConnectionType = 'Remote'

# try to Connect to the VisualCron Server
try {
	$Global:Server = $Client.Connect($conn, $true);
}
catch {
	Write-Output "2 VisualCron ExecTime=0 Error: Could Not Connect to VisualCron Server"
}

# get the jobs
$jobs = $Global:Server.jobs.GetAll()

# Loop job(s) 
foreach ($job in $jobs) {
    #if ($job.name -eq 'Load_Adobe_File_Feed') { # for debugging (please see ending if at the bottom of the script)    

    if ($job.Stats.Active -eq 'True') {
        $jStatus = 1
    } else {
        $jStatus = 0
    }

    $jName = $job.Name -replace "'", "''"

    # insert all visual cron jobs
    $q = '
    if (select ''' + $job.Id + ''' from DBA.dbo.vc_job where [jobid] = ''' + $job.Id + ''') is null
        insert into DBA.dbo.vc_job ([jobid], [jobName], [group], [is_active]) 
        values (''' + $job.Id + ''',''' + $jName + ''',''' + $job.Group + ''',''' + $jStatus + ''')
    '
    Invoke-Sqlcmd -Server $dbServer -Database $db -query $q

	# loop job trigger(s)
    foreach ($trigger in $job.Triggers) {

        if ($trigger.Description -ne '') {
            $triggerDesc = $trigger.Description
        } else {
            $triggerDesc = 'No Description'
        }

        if ($trigger.Active -eq 'True') {
            $triggerStatus = 1
        } else {
            $triggerStatus = 0
            }

        if ($trigger.TriggerType -eq 'TimeType') {
            $triggerType = 'Time'
        } else {
            $triggerType = 'Event' 
        }

        # insert all job related triggers (trigger = 'schedule')
        $q = '
        if (select ''' + $trigger.Id + ''' from DBA.dbo.vc_trigger where [triggerid] = ''' + $trigger.Id + ''') is null
            insert into DBA.dbo.vc_trigger ([triggerid], [jobid], [description], [type], [is_active]) 
            values (''' + $trigger.Id + ''',''' + $job.Id + ''', ''' + $triggerDesc + ''',''' + $triggerType + ''',''' + $triggerStatus + ''')
        '
        Invoke-Sqlcmd -Server $dbServer -Database $db -query $q
            
        }
    # loop job tasks 
    foreach ($task in $job.Tasks) {   
    
       # set 'task type' variables 
       $taskType = $task.TaskType
       
       $taskName = $task.Name -replace "'", "''"
       if ($task.Stats.Active -eq 'True') {
           $taskStatus = 1
        } else {
            $taskStatus = 0
        }
       $taskSql = $Client.Decrypt($task.$taskType.EncryptedCommand) -replace "'", "''"
       $taskConName = $server.Connections.Get($task.$taskType.ConnectionId).Name
       $taskCmd = $task.$taskType.CmdLine -replace "'", "''"
       $taskArgs = $task.$taskType.Arguments
       $taskHost = $task.$taskType.HostName        
       $taskRunJob = $Server.Jobs.Get($task.$taskType.JobId).Name -replace "'", "''"
       $taskFtpType = $task.$taskType.FTPCommands.CommandType
       $taskSource = $task.$taskType.FileCopyItems.FileFilter.SourceFolder
       $taskCred =  $Client.Decrypt($server.Credentials.Get($task.$taskType.Credential).UserName)

       if ($task.taskType -eq 'CopyFile') {
           $taskDest = $task.$taskType.FileCopyItems.DestinationDirectory
       }
       elseif ($task.taskType -eq 'FileWrite') {
           $taskDest = $task.$tasktype.FilePath
       }
    
        # insert specific 'task' related information (e.g., sql, execute, ftp, etc)
       $q = '
        if (select ''' + $task.Id + ''' from DBA.dbo.vc_task where [taskid] = ''' + $task.Id + ''') is null
            insert into DBA.dbo.vc_task (
            [taskid], [jobid], [taskName], [taskType], [credential], [connection], [sql], [rCmd], [rArgs], [rHost], [runJob], [ftpType], [source], [dest], [is_active]
            ) 
            values (
            ''' + $task.Id + ''',''' + $job.Id + ''', ''' + $taskName + ''',''' + $taskType + ''',''' + $taskCred + ''',''' + $taskConName + ''',''' + $taskSql + ''',''' + 
                $taskCmd + ''',''' + $taskArgs + ''',''' + $taskHost + ''',''' + $taskRunJob + ''',''' + $taskFtpType + ''',''' +
                $taskSource + ''',''' + $taskDest + ''',''' + $taskStatus + '''
            
            )
       '
       Invoke-Sqlcmd -Server $dbServer -Database $db -query $q
    }
#} #debug if <<

}

#  cross your fingers
Invoke-Sqlcmd -Server $dbServer -Database $db -query 'execute [dbo].[usp_vc_job_populate_tables]'
