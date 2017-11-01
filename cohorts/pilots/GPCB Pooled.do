/**********************************************************************
*
*	Title: GPCB 2016 Learning Assessment Analyses
*	Purpose: Measure learning gains among officers participating in
			EPoD's GPCB Trainings
*	Author: Michael Fryar
*	Date created: 7 July 2016
*	Date modifited: 7 July 2016
*
**********************************************************************/
 
version 13
clear all
capture log close

** Setting up references **

global assessment 	"C:/Users/ifmruser/Dropbox (CID)/DFID - BCURE - Training/Digital Learning Lab/Learning Outcomes Assessment/analyses and data"
global	user		"mfryar"

local	date: 		di %tdCCYY.NN.DD date(c(current_date),"DMY")
local 	cti = 		substr("`c(current_time)'", 1,5)
local 	cti: 		subinstr local cti ":" ".", all

** Log **

log using "$assessment/2016 analyses/logs/GPCB_Pooled_`date'_at_`cti'_by_$user.log", replace

** GPCB January 2016 Cohort **
import delimited "$assessment/raw_data/GPCB_Pre_Post_Jan16_Cleaned.csv", varnames(1) clear
/*Note: This data was manually entered because the pre-post test was administered offline.
The data was entered where a correct answer was coded as 1 and the data therefore does not need to be recoded.*/
save "$assessment/2016 analyses/data/data_for_append/GCPB_Jan16.dta", replace

** GPCB March 2016 Cohort **
import delimited "$assessment/raw_data/GPCB_Pre_Post_Mar16.csv", varnames(1) clear
/*Note: This data was manually entered because the pre-post test was administered offline.
The data was entered where 1 indicates that the response was selected so the data needs to be recoded
such that selecting an incorrect response equals 0 and not selecting an incorrect response equals 1.*/
rename (*dsc1 *dsc6 *dsc11) (*dsc_idk1 *dsc_idk2 *dsc_idk3)
rename (*dsc2 *dsc3 *dsc7 *dsc13 *dsc14 *dsc15) (*dsc_true1 *dsc_true2 *dsc_true3 *dsc_true4 *dsc_true5 *dsc_true6)
rename (*dsc4 *dsc5 *dsc8 *dsc9 *dsc10 *dsc12) (*dsc_false1 *dsc_false2 *dsc_false3 *dsc_false4 *dsc_false5 *dsc_false6)
rename *16 *_confidence
foreach x of varlist *false*{
	replace `x' = 0 if `x'==1
	replace `x' = 1 if mi(`x')
}
** Appending the January data set **
append using "$assessment/2016 analyses/data/data_for_append/GCPB_Jan16.dta"

** Analysis **
egen pre_dsc_score = rowtotal(pre_dsc_true* pre_dsc_false*)
egen post_dsc_score = rowtotal(post_dsc_true* post_dsc_false*)
gen dsc_score_diff = post_dsc_score - pre_dsc_score
gen dsc_confidence_diff = post_dsc_confidence - pre_dsc_confidence

gen motivation_diff = post_motivation - pre_motivation
gen incentives_diff = post_incentives - pre_incentives

*** Pooled analysis ***
sum pre_dsc_score 
local sd_pre_dsc_score = r(sd)
gen dsc_score_std_diff = dsc_score_diff/`sd_pre_dsc_score'
**** Were there significant gains in score on the learning assessment? ****
ttest dsc_score_std_diff = 0
sum pre_dsc_confidence
local sd_pre_dsc_confidence = r(sd)
tab pre_dsc_confidence
tab post_dsc_confidence 
gen dsc_confidence_std_diff = dsc_confidence_diff/`sd_pre_dsc_confidence'
**** Were there significant changes in confidence in the helpfulness of descriptive evidence? ****
ttest dsc_confidence_std_diff = 0

local attitudes "motivation incentives"
foreach a of local attitudes{
		sum pre_`a'
		local sd_pre_`a' = r(sd)
		tab pre_`a'
		tab post_`a' 
		qui gen `a'_std_diff = `a'_diff/`sd_pre_`a''
**** Were there significant changes in motivation and incentives to use data and evidence? ****
		ttest `a'_std_diff = 0
}
*** Individual cohort analysis ***
gsort -cohort
tab cohort, gen(c)
foreach c of varlist c1 c2{
	sum pre_dsc_score if `c'==1
	local `c'_sd_pre_dsc_score = r(sd)
	gen `c'_dsc_score_std_diff = dsc_score_diff/``c'_sd_pre_dsc_score' if `c'==1
**** Were there significant gains in score on the learning assessment? ****
	ttest `c'_dsc_score_std_diff = 0
	sum pre_dsc_confidence if `c'==1
	local `c'_sd_pre_dsc_confidence = r(sd)
	tab pre_dsc_confidence if `c'==1
	tab post_dsc_confidence if `c'==1
	gen `c'_dsc_confidence_std_diff = dsc_confidence_diff/``c'_sd_pre_dsc_confidence' if `c'==1
**** Were there significant changes in confidence in the helpfulness of descriptive evidence? ****
	ttest `c'_dsc_confidence_std_diff = 0
	foreach a of local attitudes{
		sum pre_`a' if `c'==1
		local `c'_sd_pre_`a' = r(sd)
		tab pre_`a' if `c'==1
		tab post_`a' if `c'==1
		gen `c'_`a'_std_diff = `a'_diff/``c'_sd_pre_`a'' if `c'==1
**** Were there significant changes in motivation and incentives to use data and evidence? ****
		ttest `c'_`a'_std_diff = 0 if `c'==1
	}
}
save "$assessment/2016 analyses/data/GPCB_2016_Pooled.dta", replace

log close
