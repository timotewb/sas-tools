%macro egScheduler;

%let today=%sysfunc(today());
%put &=today;
%let rundays=30;
%do i=1 %to &rundays;

	data null;
		logdate=put(&today., date9.);
		call symput('logdate', logdate);
	run;

	%if %eval(&i. >= 27) %then %do;
		%let daysleft=%eval(&rundays.-&i.);
		*--- code to send email notification;
    
	%end;

	%let logfile=/dir01/dir02/egScheduler_&logdate..log;
	%put &=logfile.;

	filename logf "&logfile";
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

	proc printto;
	run;

	%let today=%eval(&today+1);
	%put &=today.;
%end;

%mend egScheduler;

%egScheduler;
