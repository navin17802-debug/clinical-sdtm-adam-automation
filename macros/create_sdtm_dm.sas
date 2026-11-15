/*******************************************************************************
* Macro Name:    create_sdtm_dm
* Purpose:       Transforms raw demographics CSV into CDISC SDTM DM domain
* Input:         raw_path - File path to raw_dm.csv
* Output:        out_ds   - Output SDTM DM dataset name
*******************************************************************************/

%macro create_sdtm_dm(raw_path=, out_ds=sdtm.dm);

    /* 1. Define Controlled Terminology Formats (aligned with specs/ct_mapping.json) */
    proc format;
        value $sexfmt
            'M' = 'MALE'
            'F' = 'FEMALE'
            'U' = 'UNKNOWN'
            other = 'UNKNOWN';
        value $racefmt
            '1' = 'WHITE'
            '2' = 'BLACK OR AFRICAN AMERICAN'
            '3' = 'ASIAN'
            '4' = 'OTHER'
            other = 'UNKNOWN';
        value $armfmt
            'TRT_A' = 'Active Treatment 50mg'
            'TRT_B' = 'Active Treatment 100mg'
            'PBO'   = 'Placebo';
    run;

    /* 2. Import Raw Data */
    proc import datafile="&raw_path."
        out=work.raw_dm
        dbms=csv
        replace;
        getnames=yes;
        guessingrows=max;
    run;

    /* 3. Derive SDTM DM Variables */
    data &out_ds. (keep=STUDYID DOMAIN USUBJID SUBJID SITEID BRTHDTC AGE AGEU SEX RACE ARMCD ARM RFSTDTC);
        attrib
            STUDYID length=$20 label="Study Identifier"
            DOMAIN  length=$2  label="Domain Abbreviation"
            USUBJID length=$40 label="Unique Subject Identifier"
            SUBJID  length=$20 label="Subject Identifier for the Study"
            SITEID  length=$10 label="Study Site Identifier"
            BRTHDTC length=$10 label="Date/Time of Birth"
            AGE     length=8   label="Age"
            AGEU    length=$6  label="Age Units"
            SEX     length=$10 label="Sex"
            RACE    length=$40 label="Race"
            ARMCD   length=$20 label="Planned Arm Code"
            ARM     length=$40 label="Description of Planned Arm"
            RFSTDTC length=$10 label="Subject Reference Start Date/Time";

        set work.raw_dm;

        DOMAIN  = "DM";
        USUBJID = catx("-", strip(STUDYID), strip(put(SITEID, best.)), strip(put(SUBJID, z3.)));

        /* Standardize Controlled Terminology */
        SEX   = put(upcase(strip(SEX_RAW)), $sexfmt.);
        RACE  = put(strip(put(RACE_RAW, best.)), $racefmt.);
        ARM   = put(upcase(strip(ARMCD)), $armfmt.);

        /* Calculate Age at Reference Start Date */
        if not missing(BRTHDTC) and not missing(RFSTDTC) then do;
            _brthdt = input(BRTHDTC, yymmdd10.);
            _rfstdt = input(RFSTDTC, yymmdd10.);
            AGE     = floor(yrdif(_brthdt, _rfstdt, 'AGE'));
            AGEU    = "YEARS";
        end;
    run;

    /* 4. Sort by CDISC DM Key Variables */
    proc sort data=&out_ds.;
        by STUDYID USUBJID;
    run;

%mend create_sdtm_dm;

/* Example Execution:
libname sdtm "./sdtm_output";
%create_sdtm_dm(raw_path=./raw_data/raw_dm.csv, out_ds=sdtm.dm);
*/
