******************************************************************************
* TABLE OF CONTENTS:
* 1. INTRODUCTION
* 2. SET ENVIRONMENT
* 3. APPEND CLEANED DATA
* 4. GENERATE VARIABLES FOR ANALYSIS
* 5. ANALYSIS
******************************************************************************

*** 1. INTRODUCTION ***

* Date created: March 30, 2017.
* Created by:   Michael Fryar (mfryar.hks@gmail.com)
* Project:      Building Capacity to Use Research Evidence (BCURE) Training
* PIs:          Dan Levy, Michael Callen, Asim Khwaja, Rohini Pande
* Description:  This file analyzes learning assessment data from all of the
*               BCURE trainings held to date.
* Uses:         ind_2015_phaseiv.dta, ind_2016_phasei.dta, ind_2016_phaseiv.dta
*               npl_2016_nasc.dta, npl_2017_nasc.dta,
*               pak_2015_mcmc20.dta, pak_2015_smc17.dta, pak_2015_smc18.dta,
*               pak_2016_mcmc21.dta, pak_2016_mcmc22.dta, pak_2016_nmc105.dta,
*               pak_2016_smc19.dta, pak_2016_smc20.dta, pak_2017_ctp44.dta,
*               pak_2017_mcmc23.dta, pak_2017_smc21.dta, pak_2017_nmc106.dta,
*
* Creates:


*** 2. SET ENVIRONMENT ***

version 14.2        // Set version number for backward compatibility
set more off        // Disable partitioned output
clear all           // Start with a clean slate
pause on            // Enable pause for program debugging
capture log close   // Close existing log files

// Start log (use .txt format to ensure readability outside Stata)
log using "$bcure_learning_assessment/logs/analysis_all_cohorts.txt", ///
    replace text

*** 3. APPEND CLEANED DATA ***

// Create master data set
cd "$bcure_learning_assessment/data/coded/cohorts"
local cohort_data : dir . files "*.dta"
foreach file in `cohort_data'{
    append using `file'
}

*** 4. GENERATE VARIABLES FOR ANALYSIS ***

// Create country identifiers
gen india = strpos(cohort,"ind")
gen pakistan = strpos(cohort,"pak")
gen nepal = strpos(cohort,"npl")
label var india "India"
label var nepal "Nepal"
label var pakistan "Pakistan"

// Identify trainings led by ToT alumni
gen tot_alumni = 0
replace tot_alumni = 1 if strpos(cohort,"pak_2016") | strpos(cohort,"pak_2017")

// Identify trainings held on epodx
gen epodx = 0
replace epodx = 1 if strpos(cohort,"2017") | strpos(cohort,"ind_2016") ///
    | strpos(cohort,"npl") ///
    | inlist(cohort,"pak_2016_mcmc22","pak_2016_smc20","pak_2016_nmc105")

// Generate variable for seniority level
gen seniority = ""
forv i = 1/6 {
    local var: word `i' of "ctp" "mcmc" "smc" "nmc" "phasei" "phaseiv"
    local value: word `i' of "CTP" "MCMC" "SMC" "NMC" "Phase I" "Phase IV"
    replace seniority = "`value'" if strpos(cohort,"`var'")
}
rename seniority seniority_str
encode seniority_str, gen(seniority)

// Generate cohort_campus variable to use as cluster
gen cohort_campus = cohort + "_" + campus

*** 5. LABEL VARIABLES USED IN ANALYSIS ***
forv i = 1/6 {
    local unit: word `i' of "agg" "com" "cba" "des" "imp" "sys"
    local label: word `i' of "Aggregating" "Commissioning" "CBA" ///
            "Descriptive" "Impact" "Systematic"

    label var `unit'_score_std_diff "`label'"
}
label var female "Female Trainee"
label var tot_alumni "ToT Faculty"


*** 6. ANALYSIS ***
cd "$bcure_learning_assessment/tables/inputs"

// All countries
eststo clear
forv i = 1/6 {
    local unit: word `i' of "agg" "com" "cba" "des" "imp" "sys"

    eststo: reg `unit'_score_std_diff epodx tot_alumni female ///
        india nepal, vce(robust)


    sum `unit'_score_std if epodx == 0 & tot_alumni == 0 & female == 0 ///
        & india == 0 & nepal == 0
    estadd local baseline = round(r(mean),0.001)
}
local p "\textit{p} $<$"
local note1 "Robust standard errors in parentheses."
local note2 "Coefficients on India and Nepal indicator variables are calculated"
local note2 "`note2' relative to average learning gains for Pakistani cohorts."
esttab * using monitoring_data_all_countries, replace booktabs title() ///
    label se nonotes nonumber star(* 0.10 ** 0.05 *** 0.01) ///
    drop (_cons) scalars("baseline Comparison Baseline") ///
    addnotes("`note1'" "`note2'" ///
        "* `p' 0.10, ** `p' 0.05, *** `p' 0.01")

// India
eststo clear
forv i = 1/4 {
    local unit: word `i' of "cba" "des" "imp" "sys"

    eststo: reg `unit'_score_std_diff epodx female ib(5).seniority ///
        if india == 1, vce(robust)

    sum `unit'_score_std if epodx == 0 & female == 0 & seniority == 5
    estadd local baseline = round(r(mean),0.001)
}
local p "\textit{p} $<$"
local note "Coefficient on Phase I indicator variable is calculated relative"
local note "`note' to average learning gains for Phase IV cohorts."
esttab * using monitoring_data_ind, replace booktabs title() ///
    label se nonotes nonumbers ///
    star(* 0.10 ** 0.05 *** 0.01) drop(_cons 5.seniority) ///
    sfmt(%9.3f) scalars("baseline Comparison Baseline") ///
    addnotes("Robust standard errors in parentheses." "`note'" ///
        "* `p' 0.10, ** `p' 0.05, *** `p' 0.01")

// Nepal
eststo clear
forv i = 1/6 {
    local unit: word `i' of "agg" "com" "cba" "des" "imp" "sys"

    eststo: reg `unit'_score_std_diff female ///
        if nepal == 1, vce(robust)

    sum `unit'_score_std if female == 0 & nepal == 1
    estadd local baseline = round(r(mean),0.001)
}
local p "\textit{p} $<$"
esttab * using monitoring_data_npl, replace booktabs title() ///
    label se nonote nonumbers star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("baseline Comparison Baseline") drop(_cons) ///
    addnotes("Robust standard errors in parentheses." ///
        "* `p' 0.10, ** `p' 0.05, *** `p' 0.01")

// Pakistan
eststo clear
forv i = 1/6 {
    local unit: word `i' of "agg" "com" "cba" "des" "imp" "sys"

    eststo: reg `unit'_score_std_diff epodx tot_alumni female ///
        ib(2).seniority if pakistan == 1, vce(robust)

    sum `unit'_score_std if epodx == 0 & tot_alumni == 0 & female == 0 ///
        & seniority == 2
    estadd local baseline = round(r(mean),0.001)
}
local p "\textit{p} $<$"
local note "Coefficients on CTP, SMC, and NMC indicator variables are"
local note "`note' calculated relative to average learning gains for MCMC"
local note "`note' cohorts."
esttab * using monitoring_data_pak, replace booktabs title() ///
    label se nonotes nonumbers ///
    star(* 0.10 ** 0.05 *** 0.01) drop(2.seniority _cons) ///
    scalars("baseline Comparison Baseline") ///
    addnotes("Robust standard errors in parentheses." "`note" ///
        "* `p' 0.10, ** `p' 0.05, *** `p' 0.01")


// Online-only retention
cd "$bcure_learning_assessment/data/coded/pilots"
use "pak_ctp44_online_blended_merged", clear

// Append variables for analysis
preserve
    keep fullname cohort female pre_des_score pre_imp_score
    tempfile blended_pre
    save `blended_pre'
restore
keep fullname cohort female post_des_online_score post_imp_online_score
append using `blended_pre'

// Generate variables for analysis
forv i = 1/2 {
    local unit: word `i' of "des" "imp"
    local label: word `i' of "Descriptive" "Impact"
    gen `unit'_score = post_`unit'_online_score
    replace `unit'_score = pre_`unit'_score if mi(`unit'_score)
    label var `unit'_score "`label'"
}
gen blended = (!mi(pre_des_score))
label var female "Female Trainee"
label var blended "Retention"

cd "$bcure_learning_assessment/tables/inputs"
eststo clear
forv i = 1/2 {
    local unit: word `i' of "des" "imp"

    eststo: reg `unit'_score blended female, vce(robust)

    sum `unit'_score if blended == 0 & female == 0
    estadd local baseline = round(r(mean),0.001)
}
local p "\textit{p} $<$"
esttab * using monitoring_data_online_only_retention, replace booktabs ///
    title() label se nonotes nonumbers ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("baseline Comparison Baseline") drop(_cons) ///
    addnotes("Robust standard errors in parentheses." ///
        "* `p' 0.10, ** `p' 0.05, *** `p' 0.01")

log close

