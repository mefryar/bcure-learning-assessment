******************************************************************************
* TABLE OF CONTENTS:
* 1. INTRODUCTION
* 2. SET ENVIRONMENT
* 3. APPEND CLEANED DATA
* 4. OVERALL SUMMARY TABLE
* 5. COUNTRY SUMMARY TABLES
* 6. SENIORITY SUMMARY TABLES
* 7. COHORT SUMMARY TABLES
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
*               pak_2017_mcmc23.dta, pak_2017_smc21.dta, pak_2017_nmc106.dta
* Creates:      all_cohorts.tex, female_only.tex, male_only.tex
*               ind_cohorts.tex, npl_cohorts.tex, pak_cohorts.tex
*               ind_2015_phaseiv.tex, ind_2016_phasei.tex, ind_2016_phaseiv.tex
*               npl_2016_nasc.tex, npl_2017_nasc.tex,
*               pak_2015_mcmc20.tex, pak_2015_smc17.tex, pak_2015_smc18.tex,
*               pak_2016_mcmc21.tex, pak_2016_mcmc22.tex, pak_2016_nmc105.tex,
*               pak_2016_smc19.tex, pak_2016_smc20.tex, pak_2017_ctp44.tex,
*               pak_2017_mcmc23.tex, pak_2017_smc21.tex, pak_2017_nmc106.tex

*** 2. SET ENVIRONMENT ***

version 14.2        // Set version number for backward compatibility
set more off        // Disable partitioned output
clear all           // Start with a clean slate
set linesize 80     // Limit line size to make output more readable
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

// Create country identifier
gen country = ""
replace country = "ind" if strpos(cohort,"ind")
replace country = "pak" if strpos(cohort,"pak")
replace country = "npl" if strpos(cohort,"npl")

// Identify trainings led by ToT alumni
gen tot_alumni = 0
replace tot_alumni = 1 if strpos(cohort,"pak_2016") | strpos(cohort,"pak_2017")


*** 4. ALL COHORTS SUMMARY TABLE ***
cd "$bcure_learning_assessment/tables/inputs"

forv i = 1/5{
preserve

    local matname: word `i' of "All_Cohorts" "Female_Only" "Male_Only" ///
        "EPoD_Led" "ToT_Led"
    if `i' == 2 keep if female == 1
    if `i' == 3 keep if female == 0
    if `i' == 4 keep if tot_alumni == 0
    if `i' == 5 keep if tot_alumni == 1

    matrix `matname' = J(6,5,.)
    forv i = 1/6 {
        local unit: word `i' of "agg" "com" "cba" "des" "imp" "sys"
        qui ttest `unit'_score_std_diff == 0
        matrix `matname'[`i',1] = r(mu_1)
        matrix `matname'[`i',2] = r(p)
        qui ttest `unit'_confidence_std_diff == 0
        matrix `matname'[`i',3] = r(mu_1)
        matrix `matname'[`i',4] = r(p)
        matrix `matname'[`i',5] = r(N_1)
    }

    matrix rownames `matname' = AGG COM CBA DES IMP SYS
    matrix colnames `matname' = Knowledge P-Value Confidence P-Value N
    esttab matrix(`matname', fmt(%9.2f %9.2f %9.2f %9.2f %9.0f)) ///
        using `matname'.tex, replace

restore
}

*** 5. COUNTRY SUMMARY TABLES ***
forv i = 1/3 {
    local country: word `i' of "ind" "npl" "pak"
    local title: word `i' of "India" "Nepal" "Pakistan"

    preserve
        keep if country == "`country'"

        matrix `title'_Cohorts = J(6,5,.)
        forv j = 1/6 {
            local unit: word `j' of "agg" "com" "cba" ///
                        "des" "imp" "sys"
            quietly count if `unit'_score_std_diff == .
            capture assert r(N) != _N
            if !_rc {
                qui ttest `unit'_score_std_diff == 0
                matrix `title'_Cohorts[`j',1] = r(mu_1)
                matrix `title'_Cohorts[`j',2] = r(p)
                qui ttest `unit'_confidence_std_diff == 0
                matrix `title'_Cohorts[`j',3] = r(mu_1)
                matrix `title'_Cohorts[`j',4] = r(p)
                matrix `title'_Cohorts[`j',5] = r(N_1)
            }
            else {
                forv k = 1/5 {
                    matrix `title'_Cohorts[`j',`k'] = .
                }
            }
        }

        matrix rownames `title'_Cohorts = AGG COM CBA DES IMP SYS
        matrix colnames `title'_Cohorts = Knowledge  P-Value ///
                          Confidence P-Value N
        esttab matrix(`title'_Cohorts, ///
            fmt(%9.2f %9.2f %9.2f %9.2f %9.0f)) ///
            using `country'_cohorts.tex, replace
    restore
}

*** 6. SENIORITY SUMMARY TABLES ***

// Generate variable for seniority level
gen seniority = ""
forv i = 1/6 {
    local var: word `i' of "ctp" "mcmc" "smc" "nmc" "phasei" "phaseiv"
    local value: word `i' of "CTP" "MCMC" "SMC" "NMC" "PhaseI" "PhaseIV"
    replace seniority = "`value'" if strpos(cohort,"`var'")
}
levelsof seniority, local(seniority)
foreach level in `seniority' {
    preserve
        keep if seniority == "`level'"

        matrix `level' = J(6,5,.)
        forv j = 1/6 {
            local unit: word `j' of "agg" "com" "cba" ///
                        "des" "imp" "sys"
            quietly count if `unit'_score_std_diff == .
            capture assert r(N) != _N
            if !_rc {
                qui ttest `unit'_score_std_diff == 0
                matrix `level'[`j',1] = r(mu_1)
                matrix `level'[`j',2] = r(p)
                qui ttest `unit'_confidence_std_diff == 0
                matrix `level'[`j',3] = r(mu_1)
                matrix `level'[`j',4] = r(p)
                matrix `level'[`j',5] = r(N_1)
            }
            else {
                forv k = 1/5 {
                    matrix `level'[`j',`k'] = .
                }
            }
        }

        matrix rownames `level' = AGG COM CBA DES IMP SYS
        matrix colnames `level' = Knowledge  P-Value ///
                          Confidence P-Value N
        esttab matrix(`level', ///
            fmt(%9.2f %9.2f %9.2f %9.2f %9.0f)) ///
            using `level'.tex, replace
    restore
}



*** 6. COHORT SUMMARY TABLES ***
levelsof cohort, local(cohorts)
foreach cohort in `cohorts' {
    preserve
        keep if cohort == "`cohort'"

        matrix `cohort' = J(6,5,.)
        forv j = 1/6 {
            local unit: word `j' of "agg" "com" "cba" ///
                        "des" "imp" "sys"
            quietly count if `unit'_score_std_diff == .
            capture assert r(N) != _N
            if !_rc {
                qui ttest `unit'_score_std_diff == 0
                matrix `cohort'[`j',1] = r(mu_1)
                matrix `cohort'[`j',2] = r(p)
                qui ttest `unit'_confidence_std_diff == 0
                matrix `cohort'[`j',3] = r(mu_1)
                matrix `cohort'[`j',4] = r(p)
                matrix `cohort'[`j',5] = r(N_1)
            }
            else {
                forv k = 1/5 {
                    matrix `cohort'[`j',`k'] = .
                }
            }
        }

        matrix rownames `cohort' = AGG COM CBA DES IMP SYS
        matrix colnames `cohort' = Knowledge  P-Value ///
                          Confidence P-Value N
        esttab matrix(`cohort', ///
            fmt(%9.2f %9.2f %9.2f %9.2f %9.0f)) ///
            using `cohort'.tex, replace
    restore
}


log close
