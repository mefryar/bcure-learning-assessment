******************************************************************************
* TABLE OF CONTENTS:
* 1. INTRODUCTION
* 2. SET ENVIRONMENT 
* 3. MERGE ONILNE-ONLY AND BLENDED DATA
* 4. GROUP UNMATCHED OBSERVATIONS
* 5. SAVE DATA
******************************************************************************

*** 1. INTRODUCTION ***

* Date created: May 26, 2017.
* Created by: 	Michael Fryar (mfryar.hks@gmail.com)
* Project: 	Building Capacity to Use Research Evidence (BCURE) Training
* PIs: 		Dan Levy, Michael Callen, Asim Khwaja, Rohini Pande
* Description:  Merges learning assessment data from the 44th CTP cohort in 
*		Lahore, Pakistan which completed "online-only" versions of the 
*		Becoming an Effective Consumer of Descriptive Evidence (DES) 
*		and Becoming an Effective Consumer of Impact Evaluations (IMP), 
*		between October 26 and November 9, 2016 and then completed 
*		blended learning sessions between January 18 and February 8, 
*		2017.
* Uses: 	pak_2016_ctp44_online.dta, pak_2017_ctp44.dta
* Creates: 	pak_ctp44_online_blended_merged.dta

*** 2. SET ENVIRONMENT ***

version 14.2 		// Set version number for backward compatibility
set more off		// Disable partitioned output
clear all		// Start with a clean slate
set linesize 80		// Limit line size to make output more readable
pause on 		// Enable pause for program debugging
capture log close 	// Close existing log files 

*** 3. MERGE ONILNE-ONLY AND BLENDED DATA ***
use "$bcure_learning_assessment/data/coded/pilots/pak_2016_ctp44_online", clear

// Rename to distinguish after merge
rename (*des* *imp*) (*des_online* *imp_online*)

// Merge with blended data
merge 1:1 fullname ///
	using "$bcure_learning_assessment/data/coded/cohorts/pak_2017_ctp44"

// Drop variables from modules not covered in online-only
drop *agg* *com* *cba* *sys*

*** 4. GROUP UNMATCHED OBSERVATIONS ***

/* Strgroup is used to identify online-only and blended observations from 
participants who did not type their name identically on both tests (e.g. they 
included a space or title such as Dr. on the online only test but not the 
blended test) */
strgroup fullname if _merge != 3, gen(group) threshold(0.3) normalize(longer)
		
// Manually ungroup those with strgroup incorrectly grouped 
replace group = 141 if fullname == "Muhammad Yasir Nabi"
replace group = 142 if fullname == "Muhammad Qais Khan"
replace group = 143 if fullname == "Muhammad Usman Ali"
replace group = 144 if fullname == "Muhammad Azhar"
replace group = 145 if fullname == "Muhammad Qasim"
replace group = 146 if fullname == "Muhammad Ali"
replace group = 147 if fullname == "Muhammad Adeel"
replace group = 148 if fullname == "Muhammad Usman"
replace group = 149 if fullname == "Muhammad Qasim"
replace group = 150 if fullname == "Sehrish Khan"

/* Manually group those which strgroup failed to group
correctly */
forv i = 1/7 {
	local online_group: word `i' of   1  3  8  14  15  20  21
	local blended_group: word `i' of 27 33 45 142 106 122 138
	replace group = `online_group' if group == `blended_group'
}

// Note: Shahrukh Atta Ullah Khan and Shahrukh Khan are distinct officers

duplicates tag group, generate(group_matched)

assert group_matched <= 1 if !missing(group)

sort group _merge
list fullname group pre*motivation post*motivation ///
	if group_matched == 1

sort fullname
list fullname group pre*motivation post*motivation ///
	if group_matched == 0

pause Check grouping done correctly 

drop if group_matched == 0

/* Replace missing data with matching data. Since online-only data was 
the "master" during the merge, the data is sorted descending by merge so the 
first observation within each group is from blended. */
gsort group -_merge
foreach score of varlist *online* {
	by group: replace `score' = `score'[_n+1] if _merge == 2
}

// Drop online-only observations
drop if _merge == 1
drop _merge group group_matched*

// Check
egen anymiss = rowmiss(*motivation *incentives)
assert anymiss == 0
drop anymiss

*** 5. SAVE DATA ***
cd "$bcure_learning_assessment/data/coded/pilots"
save pak_ctp44_online_blended_merged.dta, replace
