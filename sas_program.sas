/* Import datasets */
proc import datafile="/home/u63874154/EPG1V2/hematology.csv"
           out=lb_data
           dbms=csv
           replace;
    getnames=yes;
run;

proc import datafile="/home/u63874154/EPG1V2/AdverseEvent.csv"
           out=ae   /* FIX: renamed to match later usage */
           dbms=csv
           replace;
    getnames=yes;
run;

/* Flag abnormal values */
data lb_flagged;
    set lb_data;
    
    if LBSTRESN < LBNRLO then LBFLAG = "LOW";   /* FIX: LBSTREN → LBSTRESN */
    else if LBSTRESN > LBNRHI then LBFLAG = "HIGH";
    else LBFLAG = "NORMAL";
run;   /* FIX: missing semicolon */

/* Create ADLB dataset */
data lb_prep;
    set lb_flagged;

    PARAM   = LBTEST;
    PARAMCD = LBTESTCD;
    AVAL    = LBSTRESN;
run;

proc sort data=lb_prep;
    by USUBJID PARAMCD VISIT;
run;

/* Baseline */
data baseline;
    set lb_prep;
    where VISIT = "Baseline";

    BASE = AVAL;
    keep USUBJID PARAMCD BASE;
run;

proc sort data=baseline;
    by USUBJID PARAMCD;
run;

/* Merge baseline */
data adlb;
    merge lb_prep baseline;
    by USUBJID PARAMCD;

    if BASE ne . then do;
        CHG = AVAL - BASE;
        if BASE ne 0 then PCHG = (CHG/BASE)*100;
    end;

    if VISIT ne "Baseline" then ANL01FL = "Y";
run;

/* Detect clinical conditions */
data adlb;
    set adlb;

    if PARAMCD = "HGB" and AVAL < 12 then CONDITION = "ANEMIA";
    else if PARAMCD = "WBC" and AVAL < 4 then CONDITION = "LEUKOPENIA";
    else if PARAMCD = "PLT" and AVAL < 150 then CONDITION = "THROMBOCYTOPENIA";
run;   /* FIX: missing semicolon */

/* Link ADLB with AE */
proc sort data=adlb; by USUBJID; run;
proc sort data=ae; by USUBJID; run;

data adlb_ae;
    merge adlb(in=a) ae(in=b);
    by USUBJID;

    if a;
run;

/* Apply CTCAE grading */
data adlb_ae;
    set adlb_ae;

    if PARAMCD = "HGB" then do;
        if AVAL < 8 then GRADE = 3;
        else if AVAL < 10 then GRADE = 2;
        else if AVAL < 12 then GRADE = 1;
    end;

    else if PARAMCD = "WBC" then do;
        if AVAL < 2 then GRADE = 3;
        else if AVAL < 3 then GRADE = 2;
        else if AVAL < 4 then GRADE = 1;
    end;
run;

/* Trend Graphs */
proc sgplot data=adlb;
    series x=VISIT y=AVAL / group=USUBJID markers;
    where PARAMCD = "HGB";
    title "Hemoglobin Trends";
run;

/* TFL Output */
proc means data=adlb mean min max;
    class PARAM VISIT;
    var AVAL CHG;
run;

proc freq data=adlb_ae;
    tables PARAM*GRADE;
run;
