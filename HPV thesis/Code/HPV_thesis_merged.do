*******************************************************************************
* HPV THESIS ANALYSIS PIPELINE
* Socioeconomic inequalities in HPV vaccine awareness and uptake
* Vietnam MICS6, women aged 15-29 years
*
* This do-file is intentionally portable:
* - run it from Thesis_2026, or from HPV thesis/Code;
* - read-only raw data input;
* - all derived outputs go to HPV thesis/Output.
*******************************************************************************
clear all
set more off
set linesize 255
set type double
macro drop _all

*******************************************************************************
* 1. PROJECT PATHS
*******************************************************************************

local cwd "`c(pwd)'"
local root "`cwd'"

if !fileexists("`root'/HPV thesis/Dataset/data_raw_mics6_inter_format.dta") {
    local root = subinstr("`cwd'", "\HPV thesis\Code", "", .)
    local root = subinstr("`root'", "/HPV thesis/Code", "", .)
}

if !fileexists("`root'/HPV thesis/Dataset/data_raw_mics6_inter_format.dta") {
    di as error "Cannot find project root. Run from Thesis_2026 or HPV thesis/Code."
    di as error "Current working directory: `cwd'"
    error 601
}

cd "`root'"

local proj          "`root'/HPV thesis"
local data_dir      "`proj'/Dataset"
local code_dir      "`proj'/Code"
local out_dir       "`proj'/Output"
local tab_dir       "`out_dir'/tables"
local fig_dir       "`out_dir'/figures"
local log_dir       "`out_dir'/logs"
local int_dir       "`out_dir'/intermediate"
local latex_fig_dir "`root'/Latex_Thesis/Figures"

foreach d in "`out_dir'" "`tab_dir'" "`fig_dir'" "`log_dir'" "`int_dir'" {
    capture mkdir "`d'"
}

capture log close _all
log using "`log_dir'/hpv_analysis_master.log", replace text name(master)

di as txt "Project root : `root'"
di as txt "Start time   : `c(current_date)' `c(current_time)'"

*******************************************************************************
* 2. DEPENDENCY CHECKS
*******************************************************************************

capture which conindex
if _rc {
    di as error "Required Stata package not found: conindex."
    di as error "Install in Stata with: ssc install conindex"
    error 199
}

*******************************************************************************
* 3. LOAD DATA AND CONFIRM REQUIRED VARIABLES
*******************************************************************************

use "`data_dir'/data_raw_mics6_inter_format.dta", clear

local required "CCP5 CCP6 WAGE MSTATUS welevel insurance ethnicity2"
local required "`required' wscore windex5 HH1 HH6 wmweight PSU stratum"
local required "`required' MT1 MT2 MT3 MT5 MT10 MT12"
local required "`required' DV1A DV1B DV1C DV1D DV1E SB1"

foreach v of local required {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable: `v'"
        error 111
    }
}

*******************************************************************************
* 4. ANALYTIC SAMPLE AND SURVEY DESIGN
*******************************************************************************

keep if inrange(WAGE, 1, 3)
drop if missing(wmweight, PSU, stratum) | wmweight <= 0

count
local N_analytic = r(N)
di as result "Analytic sample, women aged 15-29: `N_analytic'"

rename wscore  ses
rename windex5 ses5
rename HH1     ea
rename HH6     area

svyset PSU [pweight=wmweight], strata(stratum) vce(linearized) singleunit(centered)

*******************************************************************************
* 5. CLEANING, RECODING, AND LABELS
*******************************************************************************

replace MSTATUS    = . if !inlist(MSTATUS, 1, 2, 3)
replace insurance  = . if !inlist(insurance, 1, 2)
replace ethnicity2 = . if !inlist(ethnicity2, 1, 2)
replace welevel    = . if !inlist(welevel, 0, 1, 2, 3, 4, 5)
replace ses5       = . if !inrange(ses5, 1, 5)

label define yn          0 "No" 1 "Yes", replace
label define area_lab    1 "Urban" 2 "Rural", replace
label define wage_lab    1 "15-19" 2 "20-24" 3 "25-29", replace
label define mstatus_lab 1 "Currently married/union" ///
                         2 "Formerly married/union"  ///
                         3 "Never married/union", replace
label define edu_lab     1 "Primary or less" ///
                         2 "Lower secondary" ///
                         3 "Upper secondary+", replace
label define ses5_lab    1 "Q1 poorest" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 richest", replace
label define eth_lab     1 "Kinh/Hoa" 2 "Ethnic minority", replace
label define insu_lab    0 "Insured" 1 "Uninsured", replace

label values WAGE       wage_lab
label values area       area_lab
label values MSTATUS    mstatus_lab
label values ses5       ses5_lab
label values ethnicity2 eth_lab

* Outcomes.
gen byte ccp5_bin = .
replace ccp5_bin = 1 if CCP5 == 1
replace ccp5_bin = 0 if CCP5 == 2
label values ccp5_bin yn
label variable ccp5_bin "Heard about HPV vaccination"

gen byte ccp6_bin = .
replace ccp6_bin = 1 if CCP6 == 1
replace ccp6_bin = 0 if inlist(CCP6, 2, 8)
replace ccp6_bin = 0 if missing(CCP6) & CCP5 == 2
label values ccp6_bin yn
label variable ccp6_bin "Received HPV vaccine"

gen byte gap = .
replace gap = 1 if ccp5_bin == 1 & ccp6_bin == 0
replace gap = 0 if ccp5_bin == 1 & ccp6_bin == 1
label define gap_lab 0 "Aware and vaccinated" 1 "Aware but unvaccinated", replace
label values gap gap_lab
label variable gap "Awareness-vaccination gap"

gen byte ccp6_aware = ccp6_bin if ccp5_bin == 1
label values ccp6_aware yn
label variable ccp6_aware "Received HPV vaccine among aware women"

* Covariates.
gen byte edu = .
replace edu = 1 if inlist(welevel, 0, 1)
replace edu = 2 if welevel == 2
replace edu = 3 if inlist(welevel, 3, 4, 5)
label values edu edu_lab
label variable edu "Education group"

gen byte insu = .
replace insu = 1 if insurance == 2
replace insu = 0 if insurance == 1
label values insu insu_lab
label variable insu "Health insurance"

gen byte rural = .
replace rural = 1 if area == 2
replace rural = 0 if area == 1
label values rural yn
label variable rural "Rural residence"

gen byte minority = .
replace minority = 1 if ethnicity2 == 2
replace minority = 0 if ethnicity2 == 1
label values minority yn
label variable minority "Ethnic minority"

* Media frequencies: 0 none, 1-3 any exposure.
foreach v in MT1 MT2 MT3 MT5 MT10 MT12 {
    replace `v' = . if !inlist(`v', 0, 1, 2, 3)
    gen byte `v'_use = .
    replace `v'_use = 1 if inrange(`v', 1, 3)
    replace `v'_use = 0 if `v' == 0
}

egen mme_obs = rownonmiss(MT1_use MT2_use MT3_use)
egen mme_any = rowmax(MT1_use MT2_use MT3_use)
gen byte mme = .
replace mme = mme_any if mme_obs > 0
drop mme_obs mme_any
label values mme yn
label variable mme "Any mass media exposure"

egen ict_obs = rownonmiss(MT5_use MT10_use MT12_use)
egen ict_any = rowmax(MT5_use MT10_use MT12_use)
gen byte ict = .
replace ict = ict_any if ict_obs > 0
drop ict_obs ict_any
label values ict yn
label variable ict "Any ICT exposure"

* Gender-equitable attitude: rejects all five wife-beating justifications.
foreach v in DV1A DV1B DV1C DV1D DV1E {
    replace `v' = . if !inlist(`v', 1, 2)
}
gen byte dvindex = .
replace dvindex = 1 if DV1A == 2 & DV1B == 2 & DV1C == 2 & DV1D == 2 & DV1E == 2
replace dvindex = 0 if DV1A == 1 | DV1B == 1 | DV1C == 1 | DV1D == 1 | DV1E == 1
label values dvindex yn
label variable dvindex "Rejects all wife-beating justifications"

replace SB1 = . if inlist(SB1, 8, 98, 99)
gen byte sb1n = .
replace sb1n = 0 if SB1 == 0
replace sb1n = 1 if inrange(SB1, 1, 95)
label values sb1n yn
label variable sb1n "Ever had sexual intercourse"

* ICT is kept for descriptive and bivariate analysis, but excluded from adjusted
* models if near universal or near absent.
quietly summarize ict [aw=wmweight]
local ict_mean = r(mean)
local include_ict = 1
if `ict_mean' > 0.95 | `ict_mean' < 0.05 {
    local include_ict = 0
    di as txt "NOTE: ICT weighted prevalence = " %5.3f `ict_mean' ///
        "; excluded from adjusted models because of sparse contrast."
}

local model_ict ""
local decomp_ict ""
if `include_ict' {
    local model_ict "i.ict"
    local decomp_ict "ict"
}

compress
save "`int_dir'/hpv_women_15_29_clean.dta", replace

*******************************************************************************
* 6. QUALITY CONTROL LOG
*******************************************************************************

capture log close qc
log using "`tab_dir'/qc_summary.log", replace text name(qc)
count
summarize ccp5_bin ccp6_bin ccp6_aware gap [aw=wmweight]
foreach v in ccp5_bin ccp6_bin ccp6_aware gap WAGE area minority insu MSTATUS edu ses5 mme ict dvindex sb1n {
    count if missing(`v')
    di as txt "`v' missing N = " %9.0f r(N) " (" %5.1f 100*r(N)/_N "%)"
}
svy: mean ccp5_bin ccp6_bin
svy, subpop(ccp5_bin): mean ccp6_bin ccp6_aware gap
log close qc

*******************************************************************************
* 7. DESCRIPTIVE TABLE WITH SURVEY-WEIGHTED 95% CI
*******************************************************************************

capture postclose t1
tempname t1
postfile `t1' str40 variable str60 category double(unweighted_n pct lci uci) ///
    using "`tab_dir'/table1_descriptive.dta", replace

local profile_vars "WAGE area minority insu MSTATUS edu ses5 ccp5_bin ccp6_bin gap mme ict dvindex sb1n"
foreach v of local profile_vars {
    local vlabel : variable label `v'
    if "`vlabel'" == "" local vlabel "`v'"
    levelsof `v' if !missing(`v'), local(levels)
    foreach lev of local levels {
        local cat : label (`v') `lev'
        if "`cat'" == "" local cat "`lev'"
        quietly count if `v' == `lev'
        scalar __n = r(N)
        tempvar ind
        gen byte `ind' = (`v' == `lev') if !missing(`v')
        quietly svy: mean `ind'
        matrix __m = r(table)
        scalar __pct = __m[1,1] * 100
        scalar __lci = __m[5,1] * 100
        scalar __uci = __m[6,1] * 100
        post `t1' ("`vlabel'") ("`cat'") (__n) (__pct) (__lci) (__uci)
        drop `ind'
    }
}
postclose `t1'

preserve
use "`tab_dir'/table1_descriptive.dta", clear
format pct lci uci %6.2f
export delimited using "`tab_dir'/table1_descriptive.csv", replace
restore

*******************************************************************************
* 8. BIVARIATE TABLES: SURVEY-WEIGHTED ROW % AND DESIGN-BASED PEARSON TEST
*******************************************************************************

local assoc_vars "WAGE area minority insu MSTATUS edu ses5 mme ict dvindex sb1n"

foreach outcome in ccp5_bin ccp6_bin gap ccp6_aware {
    if "`outcome'" == "ccp5_bin" {
        local outname "awareness"
        local outfile "`tab_dir'/table2_awareness_bivariate"
    }
    else if "`outcome'" == "ccp6_bin" {
        local outname "vaccination"
        local outfile "`tab_dir'/table3_vaccination_bivariate"
    }
    else if "`outcome'" == "ccp6_aware" {
        local outname "vaccination_aware"
        local outfile "`tab_dir'/table7_vaccination_aware_sensitivity"
    }
    else {
        local outname "gap"
        local outfile "`tab_dir'/table3b_gap_bivariate"
    }

    capture postclose tbiv
    tempname tbiv
    postfile `tbiv' str40 variable str60 category str20 outcome ///
        double(unweighted_n pct lci uci pvalue) using "`outfile'.dta", replace

    capture log close `outname'_biv
    log using "`outfile'.log", replace text name(`outname'_biv)

    foreach v of local assoc_vars {
        local vlabel : variable label `v'
        if "`vlabel'" == "" local vlabel "`v'"

        scalar __p = .
        if inlist("`outcome'", "gap", "ccp6_aware") {
            capture noisily svy, subpop(ccp5_bin): tabulate `v' `outcome', row percent ci pearson format(%5.1f)
        }
        else {
            capture noisily svy: tabulate `v' `outcome', row percent ci pearson format(%5.1f)
        }
        capture scalar __p = e(p_Pear)
        if missing(__p) {
            capture scalar __p = e(p_Penl)
        }

        levelsof `v' if !missing(`v'), local(levels)
        foreach lev of local levels {
            local cat : label (`v') `lev'
            if "`cat'" == "" local cat "`lev'"
            if inlist("`outcome'", "gap", "ccp6_aware") {
                quietly count if `v' == `lev' & ccp5_bin == 1 & !missing(gap)
                scalar __n = r(N)
                tempvar sub
                gen byte `sub' = (`v' == `lev' & ccp5_bin == 1) if !missing(`v') & !missing(ccp5_bin)
                replace `sub' = 0 if missing(`sub')
                quietly svy, subpop(`sub'): proportion `outcome'
            }
            else {
                quietly count if `v' == `lev' & !missing(`outcome')
                scalar __n = r(N)
                tempvar sub
                gen byte `sub' = (`v' == `lev') if !missing(`v') & !missing(`outcome')
                replace `sub' = 0 if missing(`sub')
                quietly svy, subpop(`sub'): proportion `outcome'
            }
            matrix __m = r(table)
            scalar __pct = __m[1,2] * 100
            scalar __lci = __m[5,2] * 100
            scalar __uci = __m[6,2] * 100
            post `tbiv' ("`vlabel'") ("`cat'") ("`outcome'") (__n) (__pct) (__lci) (__uci) (__p)
            drop `sub'
        }
    }
    log close `outname'_biv

    postclose `tbiv'
    preserve
    use "`outfile'.dta", clear
    format pct lci uci %6.2f
    format pvalue %9.4f
    export delimited using "`outfile'.csv", replace
    restore
}

*******************************************************************************
* 9. CONCENTRATION INDICES
*******************************************************************************

capture postclose ciout
tempname ciout
postfile `ciout' str12 outcome str12 index_type double(n estimate se lci uci pvalue) ///
    using "`tab_dir'/table4_concentration_indices.dta", replace

foreach y in ccp5_bin ccp6_bin gap {
    foreach kind in standard erreygers {
        if "`kind'" == "standard" {
            capture noisily conindex `y', rankvar(ses) truezero limits(0 1) svy
        }
        else {
            capture noisily conindex `y', rankvar(ses) bounded limits(0 1) erreygers svy
        }
        if _rc == 0 {
            scalar __ci = r(CI)
            scalar __se = r(CIse)
            scalar __n  = r(N)
            scalar __l  = __ci - invnormal(0.975) * __se
            scalar __u  = __ci + invnormal(0.975) * __se
            scalar __p  = 2 * normal(-abs(__ci / __se))
            post `ciout' ("`y'") ("`kind'") (__n) (__ci) (__se) (__l) (__u) (__p)
        }
    }
}
postclose `ciout'

preserve
use "`tab_dir'/table4_concentration_indices.dta", clear
format estimate se lci uci %9.5f
format pvalue %9.4f
export delimited using "`tab_dir'/table4_concentration_indices.csv", replace
restore

*******************************************************************************
* 10. ADJUSTED POISSON MODELS AND LOGISTIC SENSITIVITY MODELS
*******************************************************************************

local X_model "i.rural ib3.WAGE ib1.MSTATUS ib3.edu i.insu i.minority ib5.ses5 i.mme `model_ict' i.dvindex i.sb1n"

capture postclose modout
tempname modout
postfile `modout' str24 model str16 outcome str60 term double(n estimate lci uci pvalue) ///
    using "`tab_dir'/table5_models.dta", replace

capture postclose margout
tempname margout
postfile `margout' str24 model str16 outcome byte ses5 str20 wealth_quintile ///
    double(n pct lci uci) using "`tab_dir'/table8_adjusted_predicted_by_wealth.dta", replace

foreach y in ccp5_bin ccp6_bin gap ccp6_aware {
    if "`y'" == "gap" {
        quietly svy, subpop(ccp5_bin): poisson gap `X_model'
        local modelname "aPR_gap"
    }
    else if "`y'" == "ccp6_aware" {
        quietly svy, subpop(ccp5_bin): poisson ccp6_aware `X_model'
        local modelname "aPR_vaccination_aware"
    }
    else {
        quietly svy: poisson `y' `X_model'
        if "`y'" == "ccp5_bin" local modelname "aPR_awareness"
        if "`y'" == "ccp6_bin" local modelname "aPR_vaccination"
    }

    local df = e(df_r)
    local nobs = e(N)

    matrix __b = e(b)
    local terms : colnames __b
    foreach term of local terms {
        if "`term'" == "_cons" continue
        if strpos("`term'", "b.") continue
        if strpos("`term'", "o.") continue
        local nice "`term'"
        if "`term'" == "1.rural"    local nice "Rural (ref: urban)"
        if "`term'" == "1.WAGE"     local nice "Age 15-19 (ref: 25-29)"
        if "`term'" == "2.WAGE"     local nice "Age 20-24 (ref: 25-29)"
        if "`term'" == "2.MSTATUS"  local nice "Formerly married/union (ref: current)"
        if "`term'" == "3.MSTATUS"  local nice "Never married/union (ref: current)"
        if "`term'" == "1.edu"      local nice "Primary or less (ref: upper secondary+)"
        if "`term'" == "2.edu"      local nice "Lower secondary (ref: upper secondary+)"
        if "`term'" == "1.insu"     local nice "Uninsured (ref: insured)"
        if "`term'" == "1.minority" local nice "Ethnic minority (ref: Kinh/Hoa)"
        if "`term'" == "1.ses5"     local nice "Q1 poorest (ref: Q5 richest)"
        if "`term'" == "2.ses5"     local nice "Q2 (ref: Q5 richest)"
        if "`term'" == "3.ses5"     local nice "Q3 (ref: Q5 richest)"
        if "`term'" == "4.ses5"     local nice "Q4 (ref: Q5 richest)"
        if "`term'" == "1.mme"      local nice "Mass media exposure (ref: no)"
        if "`term'" == "1.ict"      local nice "ICT exposure (ref: no)"
        if "`term'" == "1.dvindex"  local nice "Rejects all wife-beating justifications (ref: no)"
        if "`term'" == "1.sb1n"     local nice "Ever had sexual intercourse (ref: no)"
        scalar __est = exp(_b[`term'])
        scalar __se  = _se[`term']
        scalar __tcrit = invttail(`df', 0.025)
        scalar __l = exp(_b[`term'] - __tcrit * __se)
        scalar __u = exp(_b[`term'] + __tcrit * __se)
        scalar __p = 2 * ttail(`df', abs(_b[`term'] / __se))
        post `modout' ("`modelname'") ("`y'") ("`nice'") (`nobs') (__est) (__l) (__u) (__p)
    }
}

foreach y in ccp5_bin ccp6_bin gap ccp6_aware {
    if "`y'" == "gap" {
        quietly svy, subpop(ccp5_bin): logistic gap `X_model'
        local modelname "OR_gap"
        local predname "pred_gap"
    }
    else if "`y'" == "ccp6_aware" {
        quietly svy, subpop(ccp5_bin): logistic ccp6_aware `X_model'
        local modelname "OR_vaccination_aware"
        local predname "pred_vaccination_aware"
    }
    else {
        quietly svy: logistic `y' `X_model'
        if "`y'" == "ccp5_bin" local modelname "OR_awareness"
        if "`y'" == "ccp6_bin" local modelname "OR_vaccination"
        if "`y'" == "ccp5_bin" local predname "pred_awareness"
        if "`y'" == "ccp6_bin" local predname "pred_vaccination"
    }

    local df = e(df_r)
    local nobs = e(N)

    quietly margins ses5
    matrix __marg = r(table)
    forvalues q = 1/5 {
        local qlab : label ses5_lab `q'
        scalar __mpct = __marg[1,`q'] * 100
        scalar __mlci = __marg[5,`q'] * 100
        scalar __muci = __marg[6,`q'] * 100
        post `margout' ("`predname'") ("`y'") (`q') ("`qlab'") (`nobs') (__mpct) (__mlci) (__muci)
    }

    matrix __b = e(b)
    local terms : colnames __b
    foreach term of local terms {
        if "`term'" == "_cons" continue
        if strpos("`term'", "b.") continue
        if strpos("`term'", "o.") continue
        local nice "`term'"
        if "`term'" == "1.rural"    local nice "Rural (ref: urban)"
        if "`term'" == "1.WAGE"     local nice "Age 15-19 (ref: 25-29)"
        if "`term'" == "2.WAGE"     local nice "Age 20-24 (ref: 25-29)"
        if "`term'" == "2.MSTATUS"  local nice "Formerly married/union (ref: current)"
        if "`term'" == "3.MSTATUS"  local nice "Never married/union (ref: current)"
        if "`term'" == "1.edu"      local nice "Primary or less (ref: upper secondary+)"
        if "`term'" == "2.edu"      local nice "Lower secondary (ref: upper secondary+)"
        if "`term'" == "1.insu"     local nice "Uninsured (ref: insured)"
        if "`term'" == "1.minority" local nice "Ethnic minority (ref: Kinh/Hoa)"
        if "`term'" == "1.ses5"     local nice "Q1 poorest (ref: Q5 richest)"
        if "`term'" == "2.ses5"     local nice "Q2 (ref: Q5 richest)"
        if "`term'" == "3.ses5"     local nice "Q3 (ref: Q5 richest)"
        if "`term'" == "4.ses5"     local nice "Q4 (ref: Q5 richest)"
        if "`term'" == "1.mme"      local nice "Mass media exposure (ref: no)"
        if "`term'" == "1.ict"      local nice "ICT exposure (ref: no)"
        if "`term'" == "1.dvindex"  local nice "Rejects all wife-beating justifications (ref: no)"
        if "`term'" == "1.sb1n"     local nice "Ever had sexual intercourse (ref: no)"
        scalar __est = exp(_b[`term'])
        scalar __se  = _se[`term']
        scalar __tcrit = invttail(`df', 0.025)
        scalar __l = exp(_b[`term'] - __tcrit * __se)
        scalar __u = exp(_b[`term'] + __tcrit * __se)
        scalar __p = 2 * ttail(`df', abs(_b[`term'] / __se))
        post `modout' ("`modelname'") ("`y'") ("`nice'") (`nobs') (__est) (__l) (__u) (__p)
    }
}
postclose `modout'
postclose `margout'

preserve
use "`tab_dir'/table5_models.dta", clear
format estimate lci uci %8.3f
format pvalue %9.4f
export delimited using "`tab_dir'/table5_models.csv", replace
restore

preserve
use "`tab_dir'/table8_adjusted_predicted_by_wealth.dta", clear
bysort outcome: egen q5_pct = max(cond(ses5 == 5, pct, .))
gen diff_vs_q5 = pct - q5_pct
replace lci = 0 if lci < 0
replace uci = 100 if uci > 100
sort model ses5
format pct lci uci diff_vs_q5 %8.2f
export delimited using "`tab_dir'/table8_adjusted_predicted_by_wealth.csv", replace
restore

*******************************************************************************
* 11. ERREYGERS DECOMPOSITION
*******************************************************************************

gen byte age_15_19 = (WAGE == 1) if !missing(WAGE)
gen byte age_20_24 = (WAGE == 2) if !missing(WAGE)
gen byte mstatus2  = (MSTATUS == 2) if !missing(MSTATUS)
gen byte mstatus3  = (MSTATUS == 3) if !missing(MSTATUS)
gen byte edu1      = (edu == 1) if !missing(edu)
gen byte edu2      = (edu == 2) if !missing(edu)
gen byte ses1      = (ses5 == 1) if !missing(ses5)
gen byte ses2      = (ses5 == 2) if !missing(ses5)
gen byte ses3      = (ses5 == 3) if !missing(ses5)
gen byte ses4      = (ses5 == 4) if !missing(ses5)

local X_decomp "age_15_19 age_20_24 rural minority insu mstatus2 mstatus3 edu1 edu2 ses1 ses2 ses3 ses4 mme `decomp_ict' dvindex sb1n"

capture postclose dp
tempname dp
postfile `dp' str12 outcome str40 variable double(dydx mean_x ci_x contribution percentage) ///
    using "`tab_dir'/table6_decomposition.dta", replace

capture log close table6
log using "`tab_dir'/table6_decomposition.log", replace text name(table6)

foreach y in ccp5_bin ccp6_bin gap {
    capture noisily conindex `y', rankvar(ses) bounded limits(0 1) erreygers svy
    if _rc != 0 {
        di as error "conindex failed for `y'; decomposition skipped."
        continue
    }
    scalar __ci_total = r(CI)
    scalar __sum_contrib = 0

    quietly svy: glm `y' `X_decomp', family(binomial) link(probit)
    tempvar esamp
    gen byte `esamp' = e(sample)
    quietly margins, dydx(*) post
    matrix __bm = e(b)

    foreach x of local X_decomp {
        local col = colnumb(__bm, "`x'")
        if `col' >= . continue
        scalar __dydx = __bm[1, `col']
        quietly conindex `x' if `esamp', rankvar(ses) truezero limits(0 1) svy
        scalar __ci_x = r(CI)
        quietly summarize `x' if `esamp' [aw=wmweight]
        scalar __mean_x = r(mean)
        scalar __contrib = 4 * __dydx * __mean_x * __ci_x
        scalar __pct = (__contrib / __ci_total) * 100
        scalar __sum_contrib = __sum_contrib + __contrib
        post `dp' ("`y'") ("`x'") (__dydx) (__mean_x) (__ci_x) (__contrib) (__pct)
    }

    scalar __res = __ci_total - __sum_contrib
    scalar __respct = (__res / __ci_total) * 100
    post `dp' ("`y'") ("Residual") (.) (.) (.) (__res) (__respct)
    drop `esamp'
}

log close table6
postclose `dp'

preserve
use "`tab_dir'/table6_decomposition.dta", clear
gen variable_label = variable
replace variable_label = "Age 15-19" if variable == "age_15_19"
replace variable_label = "Age 20-24" if variable == "age_20_24"
replace variable_label = "Rural residence" if variable == "rural"
replace variable_label = "Ethnic minority" if variable == "minority"
replace variable_label = "Uninsured" if variable == "insu"
replace variable_label = "Formerly married/union" if variable == "mstatus2"
replace variable_label = "Never married/union" if variable == "mstatus3"
replace variable_label = "Primary or less" if variable == "edu1"
replace variable_label = "Lower secondary" if variable == "edu2"
replace variable_label = "Q1 poorest" if variable == "ses1"
replace variable_label = "Q2" if variable == "ses2"
replace variable_label = "Q3" if variable == "ses3"
replace variable_label = "Q4" if variable == "ses4"
replace variable_label = "Mass media exposure" if variable == "mme"
replace variable_label = "ICT exposure" if variable == "ict"
replace variable_label = "Gender-equitable attitude" if variable == "dvindex"
replace variable_label = "Ever had sex" if variable == "sb1n"
format dydx mean_x ci_x contribution %9.5f
format percentage %9.2f
export delimited using "`tab_dir'/table6_decomposition.csv", replace
restore

*******************************************************************************
* 12. FIGURES
*******************************************************************************

graph bar (mean) ccp5_bin ccp6_bin [aw=wmweight], over(ses5) asyvars ///
    title("HPV Awareness and Vaccination by Wealth Quintile", size(medium)) ///
    subtitle("Women aged 15-29, Vietnam MICS6", size(small)) ///
    ytitle("Weighted prevalence") ylabel(0(0.2)1, format(%3.1f)) ///
    legend(order(1 "Awareness" 2 "Vaccination") rows(1)) ///
    blabel(bar, format(%4.2f) size(vsmall)) graphregion(color(white)) plotregion(color(white))
graph export "`fig_dir'/fig1_awareness_vaccination_by_ses.png", replace width(2400)

graph bar (mean) gap [aw=wmweight] if ccp5_bin == 1, over(ses5) ///
    title("Awareness-Vaccination Gap by Wealth Quintile", size(medium)) ///
    subtitle("Among aware women aged 15-29", size(small)) ///
    ytitle("Weighted prevalence") ylabel(0(0.2)1, format(%3.1f)) ///
    blabel(bar, format(%4.2f) size(vsmall)) graphregion(color(white)) plotregion(color(white))
graph export "`fig_dir'/fig2_gap_by_ses.png", replace width(2400)

graph bar (mean) ccp5_bin ccp6_bin [aw=wmweight], over(WAGE) asyvars ///
    title("HPV Awareness and Vaccination by Age Group", size(medium)) ///
    subtitle("Women aged 15-29, Vietnam MICS6", size(small)) ///
    ytitle("Weighted prevalence") ylabel(0(0.2)1, format(%3.1f)) ///
    legend(order(1 "Awareness" 2 "Vaccination") rows(1)) ///
    blabel(bar, format(%4.2f) size(vsmall)) graphregion(color(white)) plotregion(color(white))
graph export "`fig_dir'/fig3_awareness_vaccination_by_age.png", replace width(2400)

graph bar (mean) ccp5_bin ccp6_bin [aw=wmweight], over(area) asyvars ///
    title("HPV Awareness and Vaccination by Residence", size(medium)) ///
    subtitle("Women aged 15-29, Vietnam MICS6", size(small)) ///
    ytitle("Weighted prevalence") ylabel(0(0.2)1, format(%3.1f)) ///
    legend(order(1 "Awareness" 2 "Vaccination") rows(1)) ///
    blabel(bar, format(%4.2f) size(vsmall)) graphregion(color(white)) plotregion(color(white))
graph export "`fig_dir'/fig4_awareness_vaccination_by_area.png", replace width(2400)

graph bar (mean) ccp5_bin ccp6_bin [aw=wmweight], over(edu) asyvars ///
    title("HPV Awareness and Vaccination by Education", size(medium)) ///
    subtitle("Women aged 15-29, Vietnam MICS6", size(small)) ///
    ytitle("Weighted prevalence") ylabel(0(0.2)1, format(%3.1f)) ///
    legend(order(1 "Awareness" 2 "Vaccination") rows(1)) ///
    blabel(bar, format(%4.2f) size(vsmall)) graphregion(color(white)) plotregion(color(white))
graph export "`fig_dir'/fig5_awareness_vaccination_by_edu.png", replace width(2400)

graph bar (mean) ccp5_bin ccp6_bin [aw=wmweight], over(minority) asyvars ///
    title("HPV Awareness and Vaccination by Ethnicity", size(medium)) ///
    subtitle("Women aged 15-29, Vietnam MICS6", size(small)) ///
    ytitle("Weighted prevalence") ylabel(0(0.2)1, format(%3.1f)) ///
    legend(order(1 "Awareness" 2 "Vaccination") rows(1)) ///
    blabel(bar, format(%4.2f) size(vsmall)) graphregion(color(white)) plotregion(color(white))
graph export "`fig_dir'/fig6_awareness_vaccination_by_ethnicity.png", replace width(2400)

preserve
keep if !missing(ses, wmweight, ccp5_bin, ccp6_bin)
sort ses
gen double wt = wmweight
egen double total_w = total(wt)
gen double x_rank = sum(wt) / total_w
foreach y in ccp5_bin ccp6_bin {
    gen double wy_`y' = `y' * wt
    egen double total_`y' = total(wy_`y')
    gen double cy_`y' = sum(wy_`y') / total_`y'
}
twoway ///
    (line cy_ccp5_bin x_rank, sort lcolor(orange) lwidth(medthick)) ///
    (line cy_ccp6_bin x_rank, sort lcolor(forest_green) lpattern(longdash) lwidth(medthick)) ///
    (function y=x, range(0 1) lcolor(maroon) lpattern(dot) lwidth(medthick)), ///
    title("Concentration Curves for HPV Awareness and Vaccination", size(medium)) ///
    ytitle("Cumulative share of outcome") ///
    xtitle("Cumulative share of women ranked by wealth score") ///
    legend(order(1 "Awareness" 2 "Vaccination" 3 "Line of equality") rows(1) position(6)) ///
    graphregion(color(white)) plotregion(color(white))
graph export "`fig_dir'/fig7_concentration_curve.png", replace width(2400)
restore

foreach y in ccp5_bin ccp6_bin gap {
    preserve
    use "`tab_dir'/table6_decomposition.dta", clear
    keep if outcome == "`y'" & variable != "Residual"
    gen variable_label = variable
    replace variable_label = "Age 15-19" if variable == "age_15_19"
    replace variable_label = "Age 20-24" if variable == "age_20_24"
    replace variable_label = "Rural residence" if variable == "rural"
    replace variable_label = "Ethnic minority" if variable == "minority"
    replace variable_label = "Uninsured" if variable == "insu"
    replace variable_label = "Formerly married/union" if variable == "mstatus2"
    replace variable_label = "Never married/union" if variable == "mstatus3"
    replace variable_label = "Primary or less" if variable == "edu1"
    replace variable_label = "Lower secondary" if variable == "edu2"
    replace variable_label = "Q1 poorest" if variable == "ses1"
    replace variable_label = "Q2" if variable == "ses2"
    replace variable_label = "Q3" if variable == "ses3"
    replace variable_label = "Q4" if variable == "ses4"
    replace variable_label = "Mass media" if variable == "mme"
    replace variable_label = "ICT exposure" if variable == "ict"
    replace variable_label = "Gender-equitable attitude" if variable == "dvindex"
    replace variable_label = "Ever had sex" if variable == "sb1n"
    gen abs_c = abs(contribution)
    gen str90 variable_label_pct = variable_label + " (" + string(percentage, "%4.1f") + "%)"
    gsort -abs_c
    keep in 1/10
    if "`y'" == "ccp5_bin" {
        local figname "fig8_decomposition_awareness"
        local figtitle "HPV vaccine awareness"
    }
    if "`y'" == "ccp6_bin" {
        local figname "fig9_decomposition_vaccination"
        local figtitle "HPV vaccination"
    }
    if "`y'" == "gap" {
        local figname "fig10_decomposition_gap"
        local figtitle "Awareness-vaccination gap"
    }
    graph hbar contribution, over(variable_label_pct, sort(abs_c) descending label(labsize(vsmall))) ///
        title("Top contributors: `figtitle'", size(medium)) ///
        ytitle("Contribution to Erreygers CI") ///
        yline(0, lcolor(gray) lpattern(dash)) ///
        blabel(bar, format(%6.4f) size(tiny)) ///
        xsize(9) ysize(5) graphregion(color(white) margin(l+8 r+8)) plotregion(color(white))
    graph export "`fig_dir'/`figname'.png", replace width(3600)
    restore
}

foreach f in fig1_awareness_vaccination_by_ses fig2_gap_by_ses fig3_awareness_vaccination_by_age fig4_awareness_vaccination_by_area fig5_awareness_vaccination_by_edu fig6_awareness_vaccination_by_ethnicity fig7_concentration_curve fig8_decomposition_awareness fig9_decomposition_vaccination fig10_decomposition_gap {
    capture copy "`fig_dir'/`f'.png" "`latex_fig_dir'/`f'.png", replace
}

di as result "All outputs saved in: `out_dir'"
di as result "End time: `c(current_date)' `c(current_time)'"
log close master
exit, clear
