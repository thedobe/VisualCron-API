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
CREATE PROCEDURE [dbo].[usp_vc_job_create_prepare_tables]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	if not exists (select * from sys.tables where name = 'vc_job')
	begin
		create table vc_job (
		jobid uniqueidentifier null,
		jobName varchar(250) null,
		[group] varchar(250) null,
		is_active bit null
		)
	end

	if not exists (select * from sys.tables where name = 'vc_trigger')
	begin
		create table vc_trigger (
			triggerid uniqueidentifier null,
			jobid uniqueidentifier null,
			[description] varchar(200) null,
			[type] varchar(50) null,
			time_hour tinyint null,
			is_active bit null,
		)
	end

	if not exists (select * from sys.tables where name = 'vc_job_schedule')
	begin
		create table vc_job_schedule (
			triggerid uniqueidentifier null,
			jobid uniqueidentifier null,
			jobName varchar(200) null,
			[description] varchar(200) null,
			[12AM] varchar(300), [1AM] varchar(300), [2AM] varchar(300), [3AM] varchar(300), [4AM] varchar(300), [5AM] varchar(300), [6AM] varchar(300), [7AM] varchar(300), [8AM] varchar(300), [9AM] varchar(300), [10AM]varchar(300), [11AM] varchar(300), 
			[12PM] varchar(300), [1PM] varchar(300), [2PM] varchar(300), [3PM] varchar(300), [4PM] varchar(300), [5PM] varchar(300), [6PM] varchar(300), [7PM] varchar(300), [8PM] varchar(300), [9PM] varchar(300), [10PM] varchar(300), [11PM] varchar(300)
		)
	end

	if not exists (select * from sys.tables where name = 'vc_task')
	begin
		create table vc_task (
		taskid uniqueidentifier null,
		jobid uniqueidentifier null,
		taskName varchar(250) null,
		taskType varchar(100) null,
		[connection] sysname null,
		[sql] varchar(max) null,
		rCmd varchar(4000) null,
		rArgs varchar(4000) null,
		rHost sysname null,
		runJob varchar(4000) null,
		ftpType varchar(100) null,
		[source] varchar(1000) null,
		dest varchar(1000) null,
		is_active bit null
		)
	end

	truncate table vc_job;
	truncate table vc_trigger;
	truncate table vc_job_schedule;
	truncate table vc_task;

END
