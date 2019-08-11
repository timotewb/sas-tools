%macro egScheduler;

*--- SAS Enterprise Guide Scheduler;
* &today: date when the scheduler was kicked off;
* &rundays: max days scheduler will run continuously;
* &notificationdays: send notification when shceudler reaches this number of rundays;
* &logdir: directory where log fiels are to be saved;
* &job_name: full path to code including name + extension;

%let today=%sysfunc(today()); 
%let rundays=30;              
%let notificationdays = 27;   
%let logdir = /dir01/dir02/;  

%put &=today;
%put &=rundays;
%put &=notificationdays;
%put &=logdir;

%do i=1 %to &rundays;

	data null;
		logdate=put(&today., date9.);
		call symput('logdate', logdate);
	run;

	%if %eval(&i. >= &notificationdays.) %then %do;
		%let daysleft=%eval(&rundays.-&i.);
		*--- code to send notification that the scheduler is nearing the rundays value;
    
	%end;

	*--- output to daily logfile;
	%let logfile=&logdir.egScheduler_&logdate..log;
	%put &=logfile.;
	filename logf "&logfile.";
	proc printto log=logf;
	run;

	data null;
		today=&today;
		tomorrow=today+1;
		length msg $240;

		*----------------------------------------------------------------------------------------; 
		*Today - 10pm
		*----------------------------------------------------------------------------------------; 
		*--- 10pm;
		sleeptime=dhms(today,22,0,0)-datetime();
		call sleep(sleeptime, 1);

		%let job_name = /dir01/dir02/sas_job_01.sas;
		msg=put(datetime(), datetime20.)||" .... Running &job_name.";
		put msg;
		call system("&job_name.");

		*----------------------------------------------------------------------------------------; 
		*Tomorrow - 4am
		*----------------------------------------------------------------------------------------; 
		*--- 4.10am;
		sleeptime=dhms(tomorrow,4,10,0)-datetime();
		call sleep(sleeptime, 1);

		%let job_name = /dir01/dir02/sas_job_02.sas;
		msg=put(datetime(), datetime20.)||" .... Running &job_name.";
		put msg;
		call system("&job_name.");

		*--- 4.20am;
		sleeptime=dhms(tomorrow,4,20,0)-datetime();
		call sleep(sleeptime, 1);

		%let job_name = /dir01/dir02/sas_job_03.sas;
		msg=put(datetime(), datetime20.)||" .... Running &job_name.";
		put msg;
		call system("&job_name.");

	run;

	*--- switch back to EG log;
	proc printto;
	run;

	*--- output t EG log the date so you can check where the scheduler is upto from EG;
	%let today=%eval(&today+1);
	%put &=today.;
%end;

%mend egScheduler;

*--- run the macro definition;
%egScheduler;
