******************************************************************************
* TABLE OF CONTENTS:
* 1. INTRODUCTION
* 2. SET ENVIRONMENT 
* 3. PREPARE PRE AND POST TEST FOR MERGE
* 4. MERGE AND ENUSRE PRE-POST OBSERVATIONS MATCH
* 5. CLEAN MERGED AND MATCHED DATA
* 6. CALCULATE STANDARDIZED DIFFERENCES FOR EACH METRIC
* 7. COUNT CHANGE IN "I DON'T HAVE ENOUGH INFO" RESPONSES
* 8. COUNT NUMBER OF SCORE INCREASES (SUJOY STAT)
* 9. COMPILE SUMMARY TABLE
* 10. EXPORT SCORES TO EXCEL SPREADSHEET
******************************************************************************

*** 1. INTRODUCTION ***

* Date created: March 28, 2017.
* Created by: 	Michael Fryar (mfryar.hks@gmail.com)
* Project: 	Building Capacity to Use Research Evidence (BCURE) Training
* PIs: 		Dan Levy, Michael Callen, Asim Khwaja, Rohini Pande
* Description: 	This file cleans learning assessment data from the BCURE 
*		training held at four of the National Institutes of Management
*		which are the constituent units of the National School of 
*		Public Policy in Pakistan for officers in the 23rd Mid-Career
*		Management Cohort. The trainings took place from March 6-10 at
*		NIM Lahore, March 20-23 at NIM Peshawar, April 3-6 at NIM
*		Karachi, & April 10-14 at NIM Quetta. Each training covered the 
*		BCURE modules: Systematic Approaches to Policy Decisions (SYS), 
*		Becoming an Effective Consumer of Cost-Benefit Analysis (CBA), 
*		Becoming an Effective Consumer of Descriptive Evidence (DES), 
*		Becoming an Effective Consumer of Impact Evaluations (IMP), 
*		Aggregating Evidence (AGG) and Commissioning Evidence (COM).
* Uses: 	PAK_2017_MCMC23_Karachi_Pre.csv,
*		PAK_2017_MCMC23_Lahore_Pre.csv,
*		PAK_2017_MCMC23_Peshawar_Pre.csv,
*		PAK_2017_MCMC23_Quetta_Pre.csv,
*		PAK_2017_MCMC23_Karachi_Post.csv 
*		PAK_2017_MCMC23_Lahore_Post.csv, 
*		PAK_2017_MCMC23_Peshawar_Post.csv 
*		PAK_2017_MCMC23_Quetta_Post.csv 
* Creates: 	PAK_2017_MCMC23.dta, pak_2017_mcmc23_karachi_scores.xlsx,
*		pak_2017_mcmc23_lahore_scores.xlsx,
*		pak_2017_mcmc23_peshawar_scores.xlsx,
*		pak_2017_mcmc23_quetta_scores.xlsx

*** 2. SET ENVIRONMENT ***

version 14.2 		// Set version number for backward compatibility
set more off		// Disable partitioned output
clear all		// Start with a clean slate
set linesize 80		// Limit line size to make output more readable
pause on 		// Enable pause for program debugging
capture log close 	// Close existing log files 

// Set local to identify cohort
local cohort "pak_2017_mcmc23"

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
		quietly replace `starttime' = ///
			clock(`startdatevarname', "MDYhm") if mi(`starttime') 
		
		// Tag first observation per participant
		bysort fullname: egen double `tag' = min(`starttime')
		
		// Keep only the first observation
		keep if `starttime' == `tag'

		// Drop any duplicates in terms of all observations
		quietly duplicates report
		if r(unique_value) != r(N) duplicates drop
end

*** 3. CLEAN PRE AND POST TEST ***

// Clean the pre test data and then repeat for post test data
forval i = 1/2 {
	local period: word `i' of "pre" "post"
	cd "$bcure_learning_assessment/data/raw/`period'"

	/* Since training was administered on four campuses, we need to clean 
	eight files */
	forval j = 1/4 {
		
		local campus: word `j' of ///
			"karachi" "lahore" "peshawar" "quetta"
		
		display "Cleaning `campus' `period'"

		import delimited `cohort'_`campus'_`period'.csv, ///
			varnames(1) clear
		
		/*Although first row are imported as variable names, the second 
		row contains more informative names for v8-v10*/
		capture confirm variable v8 // Not all data have same labeling
		if !_rc {
			forval k = 8/10 {
				quietly quietly replace v`k' = lower(v`k') in 1
				rename v`k' `=strtoname(v`k'[1])'
			}
		}
		display "Drop observation containing variable lables"
		drop if finished == "finished" | finished == "Finished"		
		
		display "Drop unfinished responses"
		drop if finished == "0"

		/*Rename variables corresponding to content questions. Not all
		cohorts complete all units so this is generic code that first
		checks which questions are present.*/
		capture drop q35 q36 // Not content questions
		local unit_questions 	q3_1-q5   q6_1-q9   q10_1-q13 /// 
					q14_1-q17 q26_1-q29 q30_1-q33
		foreach v of local unit_questions {
			capture unab unit_questions_list: `v'
			capture confirm variable `unit_questions_list'
			if !_rc {
				forval k = 1/6 {
					local old: word `k' of 	"q3_1-q5" ///
								"q6_1-q9" ///
								"q10_1-q13" ///
					 			"q14_1-q17" ///
					 			"q26_1-q29" ///
					 			"q30_1-q33"
					local new: word `k' of 	"sys#" ///
								"cba#" ///
								"des#" ///
								"imp#" ///
								"agg#" ///
								"com#"
					if "`v'" == "`old'" ///
					rename `old' `period'_`new', addnumber
					local unit_questions_list ""
				}			
			}
		}
		rename (q18 q19) (`period'_motivation `period'_incentives)
		quietly destring `period'_*, replace
		
		// Standardize capitalization and trim spaces of fullname
		rename q24 fullname
		qui replace fullname = strproper(strtrim(stritrim(fullname)))
		
		display "Drop observations without a name"
		drop if mi(fullname)
		
		// Generate variable for gender
		capture destring q25, replace
		quietly gen female = .
		quietly replace female = 0 if q25 == 1
		quietly replace female = 1 if q25 == 2

		display "If there are duplicates by name, keep only the first"
		quietly duplicates report fullname
		if r(N) != r(unique_value) keep_first startdate
		quietly duplicates report fullname
		assert r(N) == r(unique_value)

		// Identify campus
		gen campus = "`campus'"

		/* There were two unique participants with the name 
		Khalid Hussain so we will distinguish them by campus */
		quietly replace fullname = fullname + " - " + campus ///
			if fullname == "Khalid Hussain"

		// Keep only necessary variables
		keep cohort campus `period'_* fullname female

		// Identify cohort
		quietly replace cohort = "`cohort'"
		
		// Save data from first campus in temporary file
		if `j' == 1 {
			tempfile `cohort'_`period' 	
			quietly save ``cohort'_`period''
		}

		/* Append data from subsequent campuses to data from first 
		campus */
		else if `j' >= 2 {
			append using ``cohort'_`period'' 
			quietly save ``cohort'_`period'', replace
		}
	}
}

*** 4. MERGE AND ENUSRE PRE-POST OBSERVATIONS MATCH ***

// Merge
merge 1:1 fullname using ``cohort'_pre'

// Ensure that each observation contains matched pre- and post-test data
count if _merge != 3

/* If there are unmatched observations, strgroup is used to identify pre- and 
post-observations from participants who did not type their name identically on 
the pre-test and post-test (e.g. they included a space or title such as Dr. on 
the pre-test but not the post-test) */
if r(N) != 0 {
	strgroup fullname if _merge != 3, ///
				gen(group) threshold(0.3) normalize(longer)
			
	/* If there is only one ungrouped observation, it can 
	be safely dropped */
	quietly duplicates tag group, generate(group_matched)
	count if group_matched == 0

	if r(N) == 1 drop if group_matched == 0
	
	/* Otherwise, observations which strgroup failed to group correctly 
	must be examined and regrouped manually */
	else {
		assert cohort[1] == "pak_2017_mcmc23"
		
		// Manually ungroup those with strgroup incorrectly grouped 
		replace group = 53 if fullname == "Zafar Ahmad Siddiqui"
		replace group = 54 if strpos(fullname,"Muhammad Nadeem") ///
					& campus == "karachi"
		replace group = 55 if strpos(fullname,"Muhammad Hashim")
		replace group = 56 if fullname == "Mohammad Naeem"
		replace group = 57 if fullname == "Muhammad Ali"
		replace group = 58 if fullname == "Mohammad Zia Ul Haq"

		/* Manually group those which strgroup failed to group
		correctly */
		forv i = 1/7 {
			local pre_group: word `i' of  8  12 24 25 30 31 15
			local post_group: word `i' of 40 41 44 45 47 49 58
			quietly replace group =  `post_group' ///
				     if group == `pre_group'
		}

		quietly duplicates tag group, gen(group_matched_new)

		assert group_matched_new <= 1 if !missing(group)

		sort group _merge
		list fullname group *motivation if group_matched_new == 1

		sort fullname
		list fullname group *motivation if group_matched_new == 0
		
		pause Check grouping done correctly 

		preserve 
			gen tests = "Pre Only" if (mi(post_motivation) ///
				& group_matched_new == 0)
			replace tests = "Post Only" if (mi(pre_motivation) ///
				& group_matched_new == 0)
			keep if !mi(tests)
			keep fullname campus tests
			label var fullname "Full Name"
			label var tests "Tests Completed"
			label var campus "Campus"
			levelsof campus, local(campuses)
			cd "$bcure_learning_assessment/scores"
			foreach campus in `campuses' {
				export excel using ///
					`cohort'_`campus'_scores.xlsx ///
					if campus == "`campus'", ///
					firstrow(varlabels) sheetreplace ///
					sheet("Incomplete")
			}
		restore

		drop if group_matched_new == 0
	}

	/* Replace missing post-test data with matching pre-test data. Since
	post-test data was the "master" during the merge, the data is sorted
	by group and then _merge so that the first observation within each
	group is the post-test. */
	sort group _merge
	foreach score of varlist pre_* {
		by group: replace `score' = `score'[_n+1] if _merge == 1 
	}
	
	// Drop pre-test observations
	drop if _merge == 2 
	drop _merge group group_matched*

	// Check
	egen anymiss = rowmiss(*motivation *incentives)
	assert anymiss == 0
	drop anymiss
}
	
*** 5. CLEAN MERGED AND MATCHED DATA ***

//  Rename variables for clarity
capture confirm variable pre_sys1
if !_rc {
	rename 	(*sys1     *sys9     *sys11) ///
		(*sys_idk1 *sys_idk2 *sys_idk3)

	rename 	(*sys2      *sys6      *sys7      *sys12     *sys13) ///
		(*sys_true1 *sys_true2 *sys_true3 *sys_true4 *sys_true5)

	rename 	(*sys3       *sys4       *sys5       *sys8) ///
		(*sys_false1 *sys_false2 *sys_false3 *sys_false4)

	rename 	(*sys10      *sys14      *sys15) ///
		(*sys_false5 *sys_false6 *sys_false7)
}
capture confirm variable pre_cba1
if !_rc {
	rename 	(*cba1     *cba6     *cba11) ///
		(*cba_idk1 *cba_idk2 *cba_idk3)

	rename 	(*cba3      *cba4      *cba5      *cba7      *cba10) ///
		(*cba_true1 *cba_true2 *cba_true3 *cba_true4 *cba_true5)

	rename  (*cba12     *cba15) ///
		(*cba_true6 *cba_true7)

	rename 	(*cba2       *cba8       *cba9       *cba13      *cba14) ///
		(*cba_false1 *cba_false2 *cba_false3 *cba_false4 *cba_false5)
}
capture confirm variable pre_des1
if !_rc {
	rename 	(*des1     *des6     *des11) ///
		(*des_idk1 *des_idk2 *des_idk3)

	rename 	(*des2      *des3      *des7	  *des13     *des14) ///
		(*des_true1 *des_true2 *des_true3 *des_true4 *des_true5)

	rename  (*des15) ///
		(*des_true6)

	rename 	(*des4       *des5       *des8	     *des9	 *des10) ///
		(*des_false1 *des_false2 *des_false3 *des_false4 *des_false5)

	rename  (*des12) ///
		(*des_false6)
}
capture confirm variable pre_imp1
if !_rc {
	rename 	(*imp1     *imp10    *imp15) ///
		(*imp_idk1 *imp_idk2 *imp_idk3)

	rename 	(*imp2      *imp3      *imp4      *imp5      *imp6) ///
		(*imp_true1 *imp_true2 *imp_true3 *imp_true4 *imp_true5)

	rename  (*imp14) ///
		(*imp_true6)

	rename 	(*imp7       *imp8       *imp9       *imp11      *imp12) ///
		(*imp_false1 *imp_false2 *imp_false3 *imp_false4 *imp_false5)

	rename  (*imp13) ///
		(*imp_false6)
}
capture confirm variable pre_agg1
if !_rc {
	rename 	(*agg5     *agg10    *agg15) ///
		(*agg_idk1 *agg_idk2 *agg_idk3)

	rename 	(*agg1      *agg3      *agg6      *agg7      *agg13) ///
		(*agg_true1 *agg_true2 *agg_true3 *agg_true4 *agg_true5)
	
	rename 	(*agg2       *agg4       *agg8	     *agg9       *agg11) ///
		(*agg_false1 *agg_false2 *agg_false3 *agg_false4 *agg_false5)

	rename  (*agg12      *agg14) ///
		(*agg_false6 *agg_false7)
}
capture confirm variable pre_com1
if !_rc {
	rename 	(*com5     *com9     *com14) ///
		(*com_idk1 *com_idk2 *com_idk3)

	rename 	(*com1      *com2      *com3      *com4      *com6) ///
		(*com_true1 *com_true2 *com_true3 *com_true4 *com_true5)
	
	rename 	(*com10      *com11     *com13     *com15) ///
		(*com_true6  *com_true7 *com_true8 *com_true9)

	rename  (*com7     *com8     *com12) ///
		(*com_false1 *com_false2 *com_false3)
}
rename *16 *_confidence
order cohort-pre_incentives, alphabetic

/* Note: Since the questions were "select all that apply," the data needs to 
be recoded such that selecting a correct answer equals 1 but selecting an 
incorrect answer equals 0.*/
foreach var of varlis *idk* {
	quietly replace `var' = 0 if mi(`var')
}
foreach var of varlist *true* {
	quietly replace `var' = 0 if mi(`var')
}
foreach var of varlist *false* {
	quietly replace `var' = 0 if `var' == 1
	quietly replace `var' = 1 if mi(`var')
}

// If participants select "I don't know," other selections are made equal to 0.
forval i = 1/6 {
	local unit: word `i' of "sys" "cba" "des" "imp" "agg" "com"
	capture confirm variable pre_`unit'_true1
	if !_rc {
		forval j = 1/3 {
			forval k = 1/4 {
				if "`unit'" == "sys" {
					if `j' == 1 local q: word `k' of ///
							"true1" "false1" /// 
							"false2" "false3"

					if `j' == 2 local q: word `k' of ///
							"true2" "true3" ///
							"false4" "false5"

					if `j' == 3 local q: word `k' of ///
							"true4" "true5" ///
							"false6" "false7"
				}
				if "`unit'" == "cba" {
					if `j' == 1 local q: word `k' of ///
							"true1" "true2" ///
							"true3" "false1"

					if `j' == 2 local q: word `k' of ///
							"true4" "true5" ///
							"false2" "false3"

					if `j' == 3 local q: word `k' of ///
							"true6" "true7" ///
							"false4" "false5"
				}
				if "`unit'" == "des" {
					if `j' == 1 local q: word `k' of ///
							"true1" "true2" ///
							"false1" "false2"

					if `j' == 2 local q: word `k' of ///
							"true3" "false3" ///
							"false4" "false5"

					if `j' == 3 local q: word `k' of ///
							"true4" "true5" ///
							"true6" "false6"
				}
				if "`unit'" == "imp" {
					if `j' == 1 local q: word `k' of ///
							"true1" "true2" ///
							"true3" "true4"

					if `j' == 2 local q: word `k' of ///
							"true5" "false1" ///
							"false2" "false3"

					if `j' == 3 local q: word `k' of ///
							"true6" "false4" ///
							"false5" "false6"
				}
				if "`unit'" == "agg" {
					if `j' == 1 local q: word `k' of ///
							"true1" "true2" ///
							"false1" "false2"

					if `j' == 2 local q: word `k' of ///
							"true3" "true4" ///
							"false3" "false4"

					if `j' == 3 local q: word `k' of ///
							"true5" "false5" ///
							"false6" "false7"
				}
				if "`unit'" == "com" {
					if `j' == 1 local q: word `k' of ///
							"true1" "true2" ///
							"true3" "true4"

					if `j' == 2 local q: word `k' of ///
							"true5" "true6" ///
							"false1" "false2"

					if `j' == 3 local q: word `k' of ///
							"true7" "true8" ///
							"true9" "false3"
				}
				quietly replace pre_`unit'_`q' = 0 ///
					     if pre_`unit'_idk`j' == 1
				quietly replace post_`unit'_`q' = 0 ///
					     if post_`unit'_idk`j' == 1
			}
		}
	}
}

*** 6. CALCULATE STANDARDIZED DIFFERENCES FOR EACH METRIC ***

forv i = 1/6 {
	local unit: word `i' of "sys" "cba" "des" "imp" "agg" "com"
	capture confirm variable pre_`unit'_true1
	if !_rc {

		egen pre_`unit'_score = ///
			rowtotal(pre_`unit'_true* pre_`unit'_false*)
		egen post_`unit'_score = ///
			rowtotal(post_`unit'_true* post_`unit'_false*)
		gen `unit'_score_diff = post_`unit'_score - pre_`unit'_score
		gen `unit'_confidence_diff = ///
			post_`unit'_confidence - pre_`unit'_confidence

		quietly sum pre_`unit'_score
		local sd_pre_`unit'_score = r(sd)
		gen `unit'_score_std_diff = ///
			`unit'_score_diff/`sd_pre_`unit'_score'	

		quietly sum pre_`unit'_confidence	
		local sd_pre_`unit'_confidence = r(sd)
		gen `unit'_confidence_std_diff = ///
			`unit'_confidence_diff/`sd_pre_`unit'_confidence'
	}
}
save "$bcure_learning_assessment/data/coded/cohorts/`cohort'.dta", replace

*** 7. COUNT CHANGE IN "I DON'T HAVE ENOUGH INFO" RESPONSES ***
egen pre_idk = rowtotal(pre_*idk*)
egen post_idk = rowtotal(post_*idk*)

tab pre_idk  if pre_idk  != 0
tab post_idk if post_idk != 0

*** 8. COUNT NUMBER OF SCORE & CONFIDENCE INCREASES (SUJOY STAT) ***
forv i = 1/6 {
	local unit: word `i' of "sys" "cba" "des" "imp" "agg" "com"
	capture confirm variable `unit'_score_diff
	if !_rc {
		quietly count if `unit'_score_diff < 0
		display "Percent of learners whose `unit' scores dropped"
		display r(N)/_N
	}
}

forv i = 1/6 {
	local unit: word `i' of "sys" "cba" "des" "imp" "agg" "com"
	capture confirm variable pre_`unit'_confidence
	if !_rc {
		qui count if pre_`unit'_confidence == 4
		local pre_full = r(N)/_N
		qui count if post_`unit'_confidence == 4
		local post_full = r(N)/_N
		di "Percentage increase in 'full confidence' in `unit'"
		di (`post_full'-`pre_full')/`pre_full'	
	}
}

*** 9. COMPILE SUMMARY TABLE ***
matrix Results = J(6,5,.)
forv i = 1/6 {
	local unit: word `i' of "agg" "com" "cba" "des" "imp" "sys"
	capture confirm variable `unit'_score_std_diff
	if !_rc {
		qui ttest `unit'_score_std_diff == 0
		matrix Results[`i',1] = r(mu_1)
		matrix Results[`i',2] = r(p)
		qui ttest `unit'_confidence_std_diff == 0
		matrix Results[`i',3] = r(mu_1)
		matrix Results[`i',4] = r(p)
		matrix Results[`i',5] = r(N_1)
	}
	else {
		forv j = 1/5 {
			matrix Results[`i',`j'] = .	
		}
	}	
}

matrix rownames Results = AGG COM CBA DES IMP SYS
matrix colnames Results = Knowledge P-Value Confidence P-Value N
esttab matrix(Results, fmt(%9.2f %9.2f %9.2f %9.2f %9.0f)) 

*** 10. EXPORT SCORES TO EXCEL SPREADSHEET ***

// Determine units completed
local units_completed = ""
local total_units = 0
local total_questions = 0
forv i = 1/6 {
	local unit: word `i' of "sys" "cba" "des" "imp" "agg" "com"
	capture confirm variable pre_`unit'_score
	if !_rc {
		local units_completed = "`units_completed' `unit'"
		local total_units = (`total_units' + 1)
		local total_questions = (`total_questions' + 12)
	}
}

// Create local containing campus identifiers
levelsof campus, local(campuses)

// Calculate total score
egen post_total_score = rowtotal(post_*_score)

/* Adjust total score so it is equal to 100% for the highest scorer within 
each campus*/ 
quietly gen adjustment = .
foreach campus in `campuses'{
	display "`campus'"
	sum post_total_score if campus=="`campus'"
	replace adjustment = `total_questions' - r(max) if campus=="`campus'"
}
gen adjusted_post_total_score = post_total_score + adjustment
gen adjusted_post_total_score_pct = ///
	string(round(adjusted_post_total_score/`total_questions'*100)) + "%"

// Label variables
if strpos("`units_completed'","sys") label var post_sys_score ///
	"Systematic Approaches to Policy Decisions Score (Out of 12)"
if strpos("`units_completed'","cba") label var post_cba_score ///
	"Cost Benefit Analysis Score (Out of 12)"	
if strpos("`units_completed'","des") label var post_des_score ///
	"Descriptive Evidence Score (Out of 12)"	
if strpos("`units_completed'","imp") label var post_imp_score ///
	"Impact Evaluations Score (Out of 12)"
if strpos("`units_completed'","agg") label var post_agg_score ///
	"Aggregating Evidence Score (Out of 12)"
if strpos("`units_completed'","com") label var post_com_score ///
	"Commissioning Evidence Score (Out of 12)"
label var post_total_score "Unadjusted Total Score (Out of `total_questions')"
label var adjusted_post_total_score ///
	"Adjusted Total Score (Out of `total_questions')"
label var adjusted_post_total_score_pct "Adjusted Total Score (Out of 100%)"
label var fullname "Name"
label var cohort "Cohort"
label var campus "Campus"

// Keep only necessary variables
keep cohort campus fullname *total_score* post_*_score 
order cohort campus fullname adjusted_post_total_score_pct ///
	adjusted_post_total_score post_total_score, first

// Export to Excel
cd "$bcure_learning_assessment/scores"
foreach campus in `campuses' {
	preserve
	keep if campus=="`campus'"
	sort fullname
	export excel using `cohort'_`campus'_scores.xlsx, ///
		firstrow(varlabels) sheetreplace sheet("Scores")
	restore
} 

log close
