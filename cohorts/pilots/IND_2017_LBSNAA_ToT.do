******************************************************************************
* TABLE OF CONTENTS:
* 1. INTRODUCTION
* 2. SET ENVIRONMENT 
* 3. CLEAN PRE-TEST
* 4. CALCULATE PRE-SCORES
* 5. COMPILE SUMMARY TABLE
******************************************************************************

*** 1. INTRODUCTION ***

* Date created: February 17, 2017.
* Created by: 	Michael Fryar (mfryar.hks@gmail.com)
* Project: 	Building Capacity to Use Research Evidence (BCURE) Training
* PIs: 		Dan Levy, Michael Callen, Asim Khwaja, Rohini Pande
* Description: 	Cleans modified learning assessment data from the faculty 
*		members of the Lal Bahadur Shastri National Academy of 
*		Administration in Mussoorie, India who completed blended 
*		learning sessions covering the BCURE modules: 
* 		Systematic Approaches to Policy Decisions (SYS), Becoming an 
*		Effective Consumer of Cost-Benefit Analysis (CBA), Becoming an
*		Effective Consumer of Descriptive Evidence (DES). The post-test
*		was never administered for this cohort.
* Uses: 	IND_2017_LBSNAA_ToT_Pre.csv

*** 2. SET ENVIRONMENT ***

version 14.1 		// Set version number for backward compatibility
set more off		// Disable partitioned output
clear all		// Start with a clean slate
set linesize 80		// Limit line size to make output more readable
pause on 		// Enable pause for program debugging
capture log close 	// Close existing log files 

// Set local to identify cohort
local cohort "ind_2017_lbsnaa_tot"

// Start log (use .txt format to ensure readability outside Stata)
log using "$bcure_learning_assessment/logs/`cohort'.txt", replace text

/* Define keep_first program: used in data cleaning for keeping only the first 
observation when participants have taken the test more than once*/
capture program drop keep_first
program keep_first 
		args startdatevarname
		
		// Generate temporary variables
		tempvar starttime tag
		
		// Convert string time variable to numeric
		gen double `starttime' = clock(`startdatevarname', "YMDhms")
		
		// Capture alternate MDYhm time format
		replace `starttime' = clock(`startdatevarname', "MDYhm") ///
					if mi(`starttime') 
		
		// Tag first observation per participant
		bysort fullname: egen double `tag' = min(`starttime')
		
		// Keep only the first observation
		keep if `starttime'==`tag'
end

*** 3. CLEAN PRE-TEST ***

cd "$bcure_learning_assessment/data/raw/incomplete_or_offline"
import delimited `cohort'_pre.csv, varnames(1) clear

/*Although first row are imported as variable names, the second 
row contains more informative names for v8-v10*/
capture confirm variable v8 // Not all data have same labeling
if !_rc{
	forval j = 8/10 {
		replace v`j' = lower(v`j') in 1
		rename v`j' `=strtoname(v`j'[1])'
	}
}
// Drop second row if it contains variable labels	
drop if finished=="finished"
// Keep only complete responses
drop if finished=="0"

// Questions were named differently in Qualtrics for this cohort
rename (sys* cba* des*) (pre_sys* pre_cba* pre_dsc*)
quietly destring pre_*, replace

// Standardize capitalization and trim spaces of fullname
replace fullname = strproper(strtrim(stritrim(fullname)))
drop if mi(fullname)

// Generate variable for gender
capture destring gender, replace
gen female = .
replace female = 0 if gender==1
replace female = 1 if gender==2

// Identify duplicate observations and keep only the first
quietly duplicates report fullname
if r(N)!=r(unique_value) keep_first startdate
quietly duplicates report fullname
assert r(N)==r(unique_value)

// Keep only necessary variables
keep cohort pre_* fullname

// Label cohort
replace cohort = "`cohort'"

//  Rename variables for clarity
// Note: Only two questions were asked per module
rename 	(*sys1_1   *sys2_1) ///
	(*sys_idk1 *sys_idk3)

rename 	(*sys1_2    *sys2_2    *sys2_3) ///
	(*sys_true1 *sys_true4 *sys_true5)

rename 	(*sys1_3     *sys1_4     *sys1_5     *sys2_4     *sys2_5) ///
	(*sys_false1 *sys_false2 *sys_false3 *sys_false6 *sys_false7)

rename 	(*cba1_1   *cba2_1) ///
	(*cba_idk1 *cba_idk3)

rename 	(*cba1_3    *cba1_4    *cba1_5     *cba2_2    *cba2_5) ///
	(*cba_true1 *cba_true2 *cba_true3  *cba_true6 *cba_true7)

rename 	(*cba1_2     *cba2_3     *cba2_4) ///
	(*cba_false1 *cba_false4 *cba_false5)

rename 	(*dsc1_1   *dsc2_1) ///
	(*dsc_idk1 *dsc_idk3)

rename 	(*dsc1_2    *dsc1_3    *dsc2_3    *dsc2_4    *dsc2_5) ///
	(*dsc_true1 *dsc_true2 *dsc_true4 *dsc_true5 *dsc_true6)

rename 	(*dsc1_4     *dsc1_5     *dsc2_2) ///
	(*dsc_false1 *dsc_false2 *dsc_false6)

rename (*conf1 *conf2) (*conf_trainees *conf_faculty)

/* Note: Since the questions were "select all that apply," the data needs to 
be recoded such that selecting a correct answer equals 1 but selecting an 
incorrect answer equals 0.*/
foreach var of varlis *idk*{
	replace `var' = 0 if mi(`var')
}
foreach var of varlist *true*{
	replace `var' = 0 if mi(`var')
}
foreach var of varlist *false*{
	replace `var' = 0 if `var'==1
	replace `var' = 1 if mi(`var')
}

// If participants select "I don't know," other selections are made equal to 0.
forval i = 1/3{
	local unit: word `i' of "sys" "cba" "dsc"
	forval j = 1(2)3{
		forval k = 1/4{
			if "`unit'" == "sys" {
				if `j'==1 local q: word `k' of  "true1" ///
								"false1" ///
								"false2" ///
								"false3"
				if `j' == 3 local q: word `k' of  "true4" ///
								"true5" ///
								"false6" ///
								"false7"
			}
			if "`unit'" == "cba" {
				if `j'==1 local q: word `k' of  "true1" ///
								"true2" ///
								"true3" ///
								"false1"
				if `j' == 3 local q: word `k' of  "true6" ///
								"true7" ///
								"false4" ///
								"false5"
			}
			if "`unit'" == "dsc" {
				if `j'==1 local q: word `k' of  "true1" ///
								"true2" ///
								"false1" ///
								"false2"
				if `j' == 3 local q: word `k' of  "true4" ///
								"true5" ///
								"true6" ///
								"false6"
			}
			replace pre_`unit'_`q' = 0 if pre_`unit'_idk`j'==1
		}
	}
}

*** 4. CALCULATE PRE-SCORES ***

forv i = 1/6{
	local unit: word `i' of "sys" "cba" "dsc" "imp" "agg" "com"
	capture confirm variable pre_`unit'_true1
	if !_rc{
		egen pre_`unit'_score = ///
			rowtotal(pre_`unit'_true* pre_`unit'_false*)
	}
}

*** 5. COMPILE SUMMARY TABLE ***
matrix PreScores = J(6,7,.)
forv i = 1/6{
	local unit: word `i' of "agg" "com" "cba" "dsc" "imp" "sys"
	capture confirm variable pre_`unit'_score
	if !_rc{
		qui sum pre_`unit'_score
		matrix PreScores[`i',1] = r(mean)
		matrix PreScores[`i',2] = r(sd)
		qui sum pre_`unit'_conf_trainees
		matrix PreScores[`i',3] = r(mean)
		matrix PreScores[`i',4] = r(sd)
		qui sum pre_`unit'_conf_faculty
		matrix PreScores[`i',5] = r(mean)
		matrix PreScores[`i',6] = r(sd)
		matrix PreScores[`i',7] = r(N)
	}
	else{
		forv j = 1/7 {
			matrix PreScores[`i',`j'] = .	
		}
	}
	
}

matrix rownames PreScores = AGG COM CBA DSC IMP SYS
matrix colnames PreScores = ///
	Knowledge StdDev Conf_Trainees StdDev Conf_Faculty StdDev N
esttab matrix(PreScores, fmt(%9.2f %9.2f %9.2f %9.2f %9.2f %9.2f %9.0f)) 

log close
