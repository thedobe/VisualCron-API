USE []
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[usp_vc_job_populate_tables]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	insert into vc_job_schedule (jobid, jobName, triggerid, [description])
	select
		j.jobid, j.jobName, t.triggerid, t.[description]
	from vc_job j
	inner join vc_trigger t on t.jobid=j.jobid
	where 
		--t.is_active = 1 and
		t.type = 'Time' 
	;

	update vc_trigger
	set time_hour = (
		select 
		left(substring(t.description, charindex(':', t.description)-2,7),2)
		from vc_job j
		inner join vc_trigger t on t.jobid=j.jobid
		where 
			--t.is_active = 1 and
			t.type = 'Time' and
			left(substring(t.description, charindex(':', t.description)-2,7),2) not in ('Ho', 'Mi')
			and triggerid = vc_trigger.triggerid
	)

	create table #vc_job_schedule_build (
		[jobid] uniqueidentifier,
		[jobName] varchar(200),
		[triggerid] uniqueidentifier,
		[description] varchar(200),
		[freq_type] varchar(10),
		[freq_hms] varchar(5),
		[runtime_low] varchar(10),
		[runtime_high] varchar(10),
		[runtime_hour] varchar(10)
	)

	
	insert into #vc_job_schedule_build
	select t.jobid, t.jobName, t.triggerid, t.[description], t.freq_type, t.freq_hms, t.runtime_low, t.runtime_high, t.time_hour  from (
		select
		j.jobid,
		j.jobName,
		t.triggerid,
		t.[description],
		case
			when [description] like 'Daily%' then 'Daily'
			when [description] like 'Weekdays%' then 'Weekdays'
			when [description] like '%Monday at%' then 'Monday'
			when [description] like '%Tuesday at%' then 'Tuesday'
			when [description] like '%Wednesday at%' then 'Wednesday'
			when [description] like '%Thursday at%' then 'Thursday'
			when [description] like '%Friday at%' then 'Friday'
			when [description] like '%Saturday at%' then 'Saturday'
			when [description] like '%Sunday at%' then 'Sunday'
			when [description] like 'Every%and%' then 'Multiple Days'
			when [description] like '%Month%' then 'Monthly'
			when [description] like 'Minutely%' then 'Minutely'
			when [description] like 'Hourly%' then 'Hourly'
		end as [freq_type],
		case 
			--when [description] like '%Daily Every%minutes%' and [description] not like '%and%' then substring(t.description, charindex('minutes', t.description)-3,2) + 'm'
			when [description] like '%Daily Every%minute(s)%' and [description] not like '%and%' then substring(t.description, charindex('minute(s)', t.description)-3,2) + 'm'
			when [description] like '%hour(s)%' and [description] not like '%and%' then substring(t.description, charindex('hour(s)', t.description)-3,2) + 'h'
			when [description] like '%Minutely%%' and [description] not like '%and%' then substring(t.description, charindex('minute(s)', t.description)-3,2) + 'm'
		end as [freq_hms],
		case 
			when [description] like 'Daily Every%between%' then left(substring(t.description, charindex('-', t.description)-8,7),2) + right(substring(t.description, charindex('-', t.description)-8,7),2)
			when [description] like 'Weekdays%between%' then left(substring(t.description, charindex('-', t.description)-8,7),2) + right(substring(t.description, charindex('-', t.description)-8,7),2)
		end as [runtime_low],
		case 
			when [description] like 'Daily Every%between%' then replace(left(substring(t.description, charindex('-', t.description)+2,7),2), ':', '') + right(substring(t.description, charindex('-', t.description)+2,7),2)
					when [description] like 'Weekdays%between%' then replace(left(substring(t.description, charindex('-', t.description)+2,7),2), ':', '') + right(substring(t.description, charindex('-', t.description)+2,7),2)
		end as [runtime_high],
		case 
			when [description] like '%AM%' then cast(time_hour as varchar(2)) + 'AM'
			when [description] like '%PM%' then cast(time_hour as varchar(2)) + 'PM'
		end as time_hour
		from vc_job j
		inner join vc_trigger t on t.jobid=j.jobid
		where 
			--t.is_active = 1 and
			t.type = 'Time' 
	) as t

	
	declare @jobid uniqueidentifier, @jobName varchar(50), @triggerid uniqueidentifier, @description varchar(200), @freq_type varchar(10), @runtime_hour datetime, @runtime_low datetime, @runtime_high datetime, @runtime_offset varchar(5), @dateadd_offset varchar(3), @runtime_offset_tinyint tinyint, @sSQL varchar(max)


	declare cur_vc cursor for select jobid, jobName, triggerid, [description], freq_type, runtime_hour, runtime_low, runtime_high, freq_hms from #vc_job_schedule_build 
		open cur_vc 
			fetch cur_vc into @jobid, @jobName, @triggerid, @description, @freq_type, @runtime_hour, @runtime_low, @runtime_high, @runtime_offset 
				while @@fetch_status <> -1
				begin
					if @@fetch_status <> - 2
					begin
						set @runtime_hour = (select cast(runtime_hour as datetime) from #vc_job_schedule_build where triggerid = @triggerid)
						set @runtime_low = (select cast(runtime_low as datetime) from #vc_job_schedule_build where triggerid = @triggerid)
						set @runtime_high = (select cast(runtime_high as datetime) from #vc_job_schedule_build where triggerid = @triggerid)
						set @runtime_offset = (select [freq_hms] from #vc_job_schedule_build where triggerid = @triggerid)

						--select 'executing for job - ' + @jobName

						if (@runtime_low is null)
						begin
							set @sSQL = '
							update v
							set [' + replace(left(convert(varchar, cast(@runtime_hour as time), 100),2), ':', '') + right(convert(varchar, cast(@runtime_hour as time), 100),2) + '] =  s.freq_type 
							from vc_job_schedule v
							inner join #vc_job_schedule_build s on s.triggerid=v.triggerid
							where 
								v.triggerid = ''' + cast(@triggerid as varchar(100)) + '''
							'
							exec(@sSQL)
						end

						if (@runtime_low is null and (left(@freq_type, 2) = 'Mi' or left(@freq_type, 2) = 'Ho'))
						begin
							set @runtime_low = cast('12AM' as datetime)
							set @runtime_high = cast('11PM' as datetime)
						end

						while (@runtime_low <= @runtime_high) 
						begin
							set @sSQL = '
							update v
							set [' + replace(left(convert(varchar, cast(@runtime_low as time), 100),2), ':', '') + right(convert(varchar, cast(@runtime_low as time), 100),2) + '] =  s.freq_type 
							from vc_job_schedule v
							inner join #vc_job_schedule_build s on s.triggerid=v.triggerid
							where v.triggerid = ''' + cast(@triggerid as varchar(100)) + '''
							'
							exec(@sSQL)

							set @runtime_offset_tinyint = stuff(@runtime_offset, 3, 1, '')
						
							if right(@runtime_offset, 1) = 'm'
								set @runtime_low = dateadd(mi, @runtime_offset_tinyint, @runtime_low) 
							else if right(@runtime_offset, 1) = 'h'
								set @runtime_low = dateadd(hh, @runtime_offset_tinyint, @runtime_low) 
						end
					end
			fetch next from cur_vc into @jobid, @jobName, @triggerid, @description, @freq_type, @runtime_hour, @runtime_low, @runtime_high, @runtime_offset 
			end
	close cur_vc
	deallocate cur_vc

	update vc_job_schedule 	set [12AM] = '' where [12AM] is null
	update vc_job_schedule 	set [1AM] = '' where [1AM] is null
	update vc_job_schedule 	set [2AM] = '' where [2AM] is null
	update vc_job_schedule 	set [3AM] = '' where [3AM] is null
	update vc_job_schedule 	set [4AM] = '' where [4AM] is null
	update vc_job_schedule 	set [5AM] = '' where [5AM] is null
	update vc_job_schedule 	set [6AM] = '' where [6AM] is null
	update vc_job_schedule 	set [7AM] = '' where [7AM] is null
	update vc_job_schedule 	set [8AM] = '' where [8AM] is null
	update vc_job_schedule 	set [9AM] = '' where [9AM] is null
	update vc_job_schedule 	set [10AM] = '' where [10AM] is null
	update vc_job_schedule 	set [11AM] = '' where [11AM] is null
	update vc_job_schedule 	set [12PM] = '' where [12PM] is null
	update vc_job_schedule 	set [1PM] = '' where [1PM] is null
	update vc_job_schedule 	set [2PM] = '' where [2PM] is null
	update vc_job_schedule 	set [3PM] = '' where [3PM] is null
	update vc_job_schedule 	set [4PM] = '' where [4PM] is null
	update vc_job_schedule 	set [5PM] = '' where [5PM] is null
	update vc_job_schedule 	set [6PM] = '' where [6PM] is null
	update vc_job_schedule 	set [7PM] = '' where [7PM] is null
	update vc_job_schedule 	set [8PM] = '' where [8PM] is null
	update vc_job_schedule 	set [9PM] = '' where [9PM] is null
	update vc_job_schedule 	set [10PM] = '' where [10PM] is null
	update vc_job_schedule 	set [11PM] = '' where [11PM] is null

END
