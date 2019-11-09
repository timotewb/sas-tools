*----------------------------------------------------------------------------------------;
* scheduler.sas
*----------------------------------------------------------------------------------------;

/*

To Do: 
 - validate jobs list csv file, duplicates
 - investigate multithreading includes
 - add priority to job_list
 - kill switch

*/

/* required to keep sript running after error in include job*/
options NOSYNTAXCHECK ;
options emailhost = mail.emailserver.com;

*----------------------------------------------------------------------------------------;
* define macro variables
*----------------------------------------------------------------------------------------;

%let run_date = %sysfunc(sum(%sysfunc(today()),0),date9.);
%let run_month= %sysfunc(putN(%sysfunc(month("&run_date."d)),z2));
%let run_year = %sysfunc(year("&run_date."d));
%put &=run_date;
%put &=run_month;
%put &=run_year;

/* business acronym used if there are multiple business areas/units*/
%let business = B1;
/* business area/unit full name */
%let bus_name = Sainsburys;
/* environment switch */
%let env = Prod;
/* to and from email addresses */
%let note_from_email = someone@somewhere.com;
%let note_to_email = someone@somewhere.com;

/* log_dir - location where log files will be written to */
%let log_dir = /unix/share/&business./&env./Scheduler/Logs/&run_year.&run_month./; 
/* win_log_dir - Windows share location where log files will be written to */
%let win_log_dir = \\winodws\share\&business.\&env.\Scheduler\Logs\&run_year.&run_month.\; 
/* web_dir - locaiton where web page will be written to */
%let web_dir = /unix/share/&business./&env./Scheduler/; 
/* win_web_dir - locaiton where web page will be written to */
%let win_web_dir = \\winodws\share\&business.\&env.\Scheduler\; 
/* archive_web_dir - locaiton where web page will be written to */
%let archive_web_dir = /unix/share/&business./&env./Scheduler/Run\ Sheets/; 
/* sched_data_dir - location where scheduler data can be written permanently */
%let sched_data_dir = /unix/share/&business./&env./Data/Scheduler/Daily/; 
/* job_list_dir - location where job list csv file is located */
%let job_list_dir = /unix/share/&business./&env./Scheduler/; 



*----------------------------------------------------------------------------------------;
* define macro functions to use later
*----------------------------------------------------------------------------------------;
%macro send_error_email(filename);

	proc sql noprint;
		select strip(compress(f1,'%/')) into: error_msg
		from error;
	quit;

	data _null_;
		file BASEMail email 
			to = ("&note_to_email.")
			from = "&note_from_email."
			subject = "CEDW4 - JS ERROR - &filename";
		put "The following code FAILED with an error:";
		fn = strip("&filename.");
		put fn;
		put " ";
		put "First Error message:";
		em = strip("&error_msg");
		put em;
		put " ";
		put "Please check log for more information:";
		lf = strip("&log_file.");
		put lf;
		put " ";
		put "You can find the Run Sheet here:";
		rs = strip("&win_web_dir.");
		put rs;

	run;

%mend send_error_email;



%macro update_scheduler_web(web_dir,run_date);

%let run_dt = %sysfunc(sum(%sysfunc(datetime()),0),datetime.);
%put &=run_dt;

* write the head of the file;
data _null_;
	file "&web_dir.run_sheet.html";
	put 
"<html>
<head>
<style>
th, td {
  padding: 5px;
}
th {
  text-align: left;
  background-color: #A4D3FF;
}
</style>
</head>
<body>
<h1>&bus_name. Scheduler - &run_date.</h1>
<h4>Status as at: &run_dt.</h4>
<table>
<tr>
<th>Job Name</th>
<th>Status</th>
<th>Duration</th>
<th>Avg. Duration</th>
<th>Start</th>
<th>End</th>
<th>Est. End</th>
<th>Log</th>
</tr>
";
run;

* update the body of the file;
data _null_;
	set sched.jobs_to_run;
	if run_today = 1 then do; 
		file "&web_dir.run_sheet.html" mod;
		put "<tr><td>";
		put filename;
		put "</td><td>";
		put status;
		put "</td><td>";
		dif = round((end_dt) - (start_dt),0.1);
		put dif;
		put "</td><td>";
		put avg_duration;
		put "</td><td>";
		put start_dt;

		if end_dt ne . then do;
			put "</td><td>";
			put end_dt;
			put "</td><td>";
			*--- est_end_dt;
			put '</td><td><a href="';
			put win_log_file;
			put '">Link</a></td></tr>';
		end;
		else do;
			put "</td><td>";
			*--- end_dt;
			put "</td><td>";
			ee = put(start_dt + avg_duration,datetime.);
			put ee;
			put "</td><td>";
			*--- win_log_file;
			put "</td></tr>";
			
		end;
	end;
run;

* write the bottom of the file;
data _null_;
	file "&web_dir.run_sheet.html" mod;
	put 
"</table>
</html>
";
run;

%mend update_scheduler_web;



*----------------------------------------------------------------------------------------;
* read in job schedule
*----------------------------------------------------------------------------------------;
data work.job_list;
	length
		active           8.
		filename         $250
		location         $250
		dow              $30
		dom              $30 ;
	format
		active			 best12.
		filename         $char250.
		location         $char250.
		dow              $char30.
		dom              $char30. ;
	informat
		active			 best12.
		filename         $char250.
		location         $char250.
		dow              $char30.
		dom              $char30. ;
	infile "&job_list_dir.job_list.csv"
		lrecl=32767
		firstobs=2
		encoding="utf-8"
		dlm=','
		missover
		dsd ;
	input
		filename         : $char250.
		location         : $char250.
		dow              : $char30.
		dom              : $char30. 
		active			 : best12.;
run;



*----------------------------------------------------------------------------------------;
* define dates and directoriy macros
*----------------------------------------------------------------------------------------;
data _null_;

	* define date varaibles;
	dow = put(weekday("&run_date."d),$1.);
	dom = strip(put(day("&run_date."d),$2.));

	* put varaiables into macro vars;
	call symput('dow',dow);
	call symput('dom',dom);

run;

x "mkdir -p &log_dir.";

* put macros to the log;
%put &=dow;
%put &=dom;
%put &=run_date;
%put &=log_dir;
%put &=web_dir;
%put &=sched_data_dir;
%put &=job_list_dir;




*----------------------------------------------------------------------------------------;
* decide which jobs will run today
*----------------------------------------------------------------------------------------;
libname sched "&sched_data_dir.";

%macro setup_joblist();

	%if %sysfunc(exist(sched.jobs_to_run_history)) %then %do;

		data jobs_to_run;
			set job_list;

			priority = _n_;

			format start_dt datetime.
				end_dt datetime.
				status $50.
				log_file $200.
				win_log_file $200.;

			* check for daily jobs;
			if strip(dow) = '*' and strip(dom) = '*' and active = 1 then do;
				run_today = 1;
			end;
			else if (find(strip(dow),"|&dow|") or find(strip(dom),"|"||strip("&dom")||"|")) and active = 1 then do;
				run_today = 1;
			end;
		run;
		proc sql;
			create table avg_duration as 
			select t1.filename, 
				t1.location, 
				round(mean(t1.duration),.1) as avg_duration
			from sched.jobs_to_run_history t1
			group by t1.filename,
				t1.location;
		quit;
		proc sql;
			create table sched.jobs_to_run as 
			select t1.active, 
				t1.filename, 
				t1.location, 
				t1.dow, 
				t1.dom, 
				t1.start_dt, 
				t1.end_dt, 
				t1.status, 
				t1.log_file, 
				t1.win_log_file, 
				t1.run_today, 
				t2.avg_duration,
				t1.priority
			from work.jobs_to_run t1
				left join work.avg_duration t2 
					on (t1.filename = t2.filename) 
					and (t1.location = t2.location)
			order by t1.priority;
		quit;

	%end;
	%else %do;


		data sched.jobs_to_run;
			set job_list;

			priority = _n_;

			format start_dt datetime.
				end_dt datetime.
				status $50.
				log_file $200.
				win_log_file $200.;

			* set empty average durations;
			avg_duration = .;

			* check for daily jobs;
			if strip(dow) = '*' and strip(dom) = '*' and active = 1 then do;
				run_today = 1;
			end;
			else if (find(strip(dow),"|&dow|") or find(strip(dom),"|"||strip("&dom")||"|")) and active = 1 then do;
				run_today = 1;
			end;

		run;

		proc sort data=sched.jobs_to_run; by priority; run;

	%end;


%mend setup_joblist;

%setup_joblist();



*----------------------------------------------------------------------------------------;
* execute jobs
*----------------------------------------------------------------------------------------;
proc printto; 
run;

%macro execute_jobs;

*--- count number of jobs to run for;
proc sql noprint;
	select count(*) into: nobs
	from sched.jobs_to_run;
quit;
%put &=nobs;

%do i_sched=1 %to &nobs;

	%put &=i_sched;

	* reset varaibles to 0;
	%let run_job = 0;
	%let warn_count = 0;
	%let error_count = 0;

	* setup macro varaibles if the job is to run today;
    data _null;
        set sched.jobs_to_run (firstobs=&i_sched obs=&i_sched);
        if run_today = 1 then do;

			log_file = cat("&log_dir",tranwrd(strip(filename),'.sas',''),'_',strip(put(datetime(),B8601DT19.)),'.log');
	        call symputx('log_file',log_file);

			lst_file = cat("&log_dir",tranwrd(strip(filename),'.sas',''),'_',strip(put(datetime(),B8601DT19.)),'.lst');
	        call symputx('lst_file',lst_file);

			win_log_file = cat("&win_log_dir",tranwrd(strip(filename),'.sas',''),'_',strip(put(datetime(),B8601DT19.)),'.log');
	        call symputx('win_log_file',win_log_file);

			job_file = cat(strip(location),tranwrd(strip(filename),'.sas',''),'.sas');
	        call symputx('job_file',job_file);		

			call symputx('filename',strip(upcase(tranwrd(strip(filename),'.sas',''))));

			call symputx('run_job',1);

			put log_file;

		end;

    run;

	%if &run_job = 1 %then %do;

		%put &=filename;
		%put &=job_file;
		%put &=log_file;

		*----------------------------------------------------------------------------------------;
		* run the job
		*----------------------------------------------------------------------------------------;

		* update jobs table with start time;
		proc sql;
			update sched.jobs_to_run
				set start_dt = datetime(),
					status = '<font color="green">Running</font>',
					log_file = "&log_file.",
					win_log_file = "&win_log_file."
			where upcase(filename) = upcase(strip("&filename"));
		quit;
		%update_scheduler_web(&web_dir,&run_date.);

		* clear the work directory;
		proc datasets library=work kill; run;

		* setup the jobs log and lst file;
		filename mylog "&log_file";
		proc printto log = mylog; run;
		proc printto print="&lst_file." new; run;

		* write header to log file;
		%put ;
		%put --------------------------------------------------------------------------------;
		%put NOTE: Start processing for: &filename;
		%put --------------------------------------------------------------------------------;
		%put ;

		* run the job;
		%include "&job_file";

		* write footer to log file;
		%put ;
		%put --------------------------------------------------------------------------------;
		%put NOTE: Processing Complete for: &filename;
		%put --------------------------------------------------------------------------------;
		%put ;

		* reset logfile back;
		proc printto; run;

		* update jobs table with end time;
		proc sql;
			update sched.jobs_to_run
				set end_dt = datetime()
			where upcase(filename) = upcase(strip("&filename"));
		quit;
		%update_scheduler_web(&web_dir,&run_date.);

		*----------------------------------------------------------------------------------------;
		* check the log
		*----------------------------------------------------------------------------------------;

		* import log file;
		data log_file;
		    infile "&log_file"
		        lrecl=32767
		        encoding="utf-8"
		        truncover;
		    length
		        f1 $1000;
		    format
		        f1 $char1000.;
		    informat
		        f1 $char1000.;
		    input
		        @1 f1 $char1000.;

			line = _n_;

		run;

		* check for warnings;
		data warns;
			set log_file;

			f1 = trim(upcase(f1));

			where substrn(f1,0,8) = 'WARNING';

		run;
		proc sort data = warns; 
			by line; 
		run;
		data warn;
			set warns (firstobs=1 obs=1);

			keep f1;

		run;
		proc sql noprint;
			select count(*) into: warn_count
			from warn;
		quit;


		%if &warn_count >0 %then %do;

			* update jobs table with warning status;
			proc sql;
				update sched.jobs_to_run
					set status = '<font color="orange">Warning</font>'
				where upcase(filename) = upcase(strip("&filename"));
			quit;
			%update_scheduler_web(&web_dir,&run_date.);

		%end;


		* check for errors;
		data errors;
			set log_file;

			f1 = trim(upcase(f1));

			where substrn(f1,0,6) = 'ERROR';

		run;
		proc sort data = errors; 
			by line; 
		run;
		data error;
			set errors (firstobs=1 obs=1);

			keep f1;

		run;
		proc sql noprint;
			select count(*) into: error_count
			from error;
		quit;


		%if &error_count = 1 %then %do;

			* update jobs table with error status;
			proc sql;
				update sched.jobs_to_run
					set status = '<font color="red">Error</font>'
				where upcase(filename) = upcase(strip("&filename"));
			quit;
			%update_scheduler_web(&web_dir,&run_date.);

			%send_error_email(&filename);

		%end;

		%if &error_count = 0 and &warn_count = 0 %then %do;

			* update jobs table with error status;
			proc sql;
				update sched.jobs_to_run
					set status = 'Complete'
				where upcase(filename) = upcase(strip("&filename"));
			quit;
			%update_scheduler_web(&web_dir,&run_date.);

		%end;

		%put &=filename;
		%put &=warn_count;
		%put &=error_count;

	%end;

%end;


%mend execute_jobs;

%execute_jobs;


%macro tidy_up_scheduler();

	*--- archive the run sheet;
	x "cp &web_dir.run_sheet.html  &archive_web_dir";
	x "mv &archive_web_dir.run_sheet.html  &archive_web_dir.run_sheet_&run_date..html";

	*--- append run stats;
	proc sql;
		create table jobs_to_run_history as 
		select t1.filename, 
			t1.location,
			t1.start_dt,
			t1.end_dt,
			round(t1.end_dt - t1.start_dt,.1) as duration,
			case
				when find(t1.status,'Error','it') then 'Error'
				when find(t1.status,'Warning','it') then 'Warning' 
				when find(t1.status,'Complete','it') then 'Complete' 
				else 'UNKNOWN'
			end as status,
			"&run_date."d format=date9. as run_date
		from sched.jobs_to_run t1
		where t1.run_today = 1
		order by t1.start_dt;
	quit;

	%if %sysfunc(exist(sched.jobs_to_run_history)) %then %do;

	data sched.jobs_to_run_history;
		set sched.jobs_to_run_history
			jobs_to_run_history;
	run;

	%end;
	%else %do;

	data sched.jobs_to_run_history;
		set jobs_to_run_history;
	run;

	%end;

%mend tidy_up_scheduler;

%tidy_up_scheduler();
