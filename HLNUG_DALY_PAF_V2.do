*--------------------------------------------------
* HLNUG -DALY Berechnung KHK & Depression 
* 2018 Dez 14, version 1
* 2019 Jan 07, - run over all AGS
* 2019 Nov 05, - Hauspunkte
* 2020 May 12 -- formula correction + makro var
* Hegewald, Janice
*--------------------------------------------------

*--------------------------------------------------
* Program Setup
*--------------------------------------------------
version 14              
set more off            
clear all               
set linesize 80         
macro drop _all         
capture log close       
*cd "D:\02_DALYs"
cd "C:\Users\Hegewald\Nextcloud\Shared\HLNUG\Daten\"

*log using HLNUG_DALY.txt, text replace      

*--------------------------------------------------
* PAF - leere Datensatz
*--------------------------------------------------
local val = 0 // counter for RRs later
clear
gen str Gemeinde=" "
gen pNOT_exp_u40 = .
gen NOT_exp_u40 = . 
gen lden = . 
gen ew_lden = .
gen GmdEW_u40 = . 
gen AnzahlEW = .
save DALY.dta, replace


*--------------------------------------------------
* Gemeinden - Gemeinde Ziffer =GeZif
*--------------------------------------------------
* Import EW Daten von HLNUG
import excel "C:\Users\Hegewald\Nextcloud\Shared\HLNUG\Daten\ANZAHL_EW_GMD.xlsx", ///
sheet("ANZAHL_EW_GMD") firstrow clear

bysort GKZ: egen  TotalEW =total(AnzahlEW)
	duplicates tag GKZ , generate(doubled)
	list if doubled != 0
	drop AnzahlEW
	duplicates drop 
	list if doubled != 0
	drop doubled 
	drop if TotalEW == 0 
	rename TotalEW AnzahlEW
save Anzahl_EW_GMD, replace

use Zensus_u40, clear
rename GeZif GKZ 
destring GKZ, replace
sort GKZ 
keep GKZ P_u40 Hessen_u40 // Anteil über 40J nach Zensus
merge 1:1 GKZ using Anzahl_EW_GMD 
drop _merge

save Anzahl_EW_GMD, replace


* Import GMD Lärmdaten & kombiniere mit RR
use Anzahl_EW_GMD, clear
levelsof GKZ, local(levels) 
/*foreach l in 411000
foreach l in 635019 {*/
foreach l of local levels {
 display `l'
 *local ds1 "C:\Users\Hegewald\Nextcloud\Shared\HLNUG\Daten\FassadenpunkteLuftLärm" //Verteilt auf alle Hausfassaden
 *local ds2 "_ROAD_FAS_P_LaermLuft.txt"*
			
 local ds1 "C:\Users\Hegewald\Nextcloud\Shared\HLNUG\Daten\HLNUG Daten\HauspunkteLuftLärm\Haus\P" //Lauteste Fassade pro Haus
 local ds2 "_ROAD_HAUS_P_LaermLuft.txt"
 
 local ds = "`ds1'\`l'`ds2'"
 display "`ds'"
 
 
/*--------------------------------------------------
* Lärmdaten - L24h
*--------------------------------------------------*/
import delimited using "`ds'", delimiter(tab) clear

gen  GKZ = `l' 


label var lngt "LNGT 22-06h"
label var lday "LDAY 06-18h"
label var levg "LEVG 18-22h"


* L24h berechnen
gen l24h = 10*log10((1/24) * (12*(10^(lday/10)) +  4*(10^(levg/10)) + 8*(10^(lngt/10))))
label var l24h "L24H" 
* gen test  = 10*log10((1/24) * (12*(10^(lday/10)) +  4*(10^((levg+5)/10)) + 8*(10^((lngt+10)/10)))) // test calculation with Lden comparison


*--------------------------------------------------
* Anteil exponierten Einwohner (über 40J)
*--------------------------------------------------

* Anteil über 40J im Gemeinde aus Zensus Daten zufügen 
*merge m:1 GeZif using Zensus_u40,  keepusing(Name Anz_u40 EWZ P_u40 Hessen_u40) keep(3)
merge m:1 GKZ using Anzahl_EW_GMD,  keepusing(Gemeinde GKZ AnzahlEW P_u40 Hessen_u40) keep(3)
drop _merge


* Einwohnerzahl(ew) über 40 i.d. Gemeinde 
gen GmdEW_u40 = AnzahlEW * P_u40

* Gesamt Stassenlaermexponierten in der Gemeinde
bysort GKZ: egen tot_GeExp = total(ew)

* Gesamt NICHT-Stassenlaermexponierten in der Gemeinde
gen NOT_exp_u40 = (AnzahlEW - tot_GeExp) * P_u40
gen pNOT_exp_u40 = (NOT_exp * P_u40)/Hessen_u40 // Proportion not exponierten


* Laermexponierten ueber 40J
display tot_GeExp * P_u40 


bysort lden: egen ew_lden = total(ew)
 

keep Gemeinde AnzahlEW GmdEW_u40 pNOT_exp_u40 NOT_exp_u40 lden ew_lden 

duplicates drop				

append using DALY.dta, keep( Gemeinde AnzahlEW GmdEW_u40 pNOT_exp_u40 NOT_exp_u40 lden ew_lden) force

save DALY.dta, replace

}

///





use DALY.dta, clear
 
bysort lden: egen Total_ew_lden = total(ew_lden)
egen Total_ew = total(GmdEW_u40)

keep lden Total_ew_lden  Total_ew 

duplicates drop
sort lden
gen p_exp = Total_ew_lden/Total_ew



*--------------------------------------------------
* RR - create dataset with the Relative Risks (RR)
*--------------------------------------------------
* Herzinfarkt Risiko  OR = 1,024	[1,016, 1,033] (Seidler et al. 2019)
* Depression  Risiko  OR 1,041 [1,031-1,05]

* data on disease risks as local stata variable
local d1 KHK 1.024 1.016 1.033
local d2 DEP 1.041 1.031 1.05

local dlist d1 d2
display "`dlist' `d1' `d2'"




local val = 0 // counter for RRs later

foreach a of local dlist  {
	local val = `val'+1
	display "`a' `val'"

 
 gen str30 A`val' = "``a''"
 
 split A`val' , generate(RRraw`val') destring 
  
*--------------------------------------------------
* PAF - L24h Herzinfarkt (NORAH)
*--------------------------------------------------

*** STRASSENVERKEHRSLAERM NORAH *****
*   Herzinfarkt Risiko  OR = 1,024	[1,016, 1,033] (Seidler et al. 2019)
* gen RR = exp(ln(RR_per10dB) * l24h)
*l24 oder lden
gen RR`val' = exp(ln(RRraw`val'2)*(lden-40)/10) 
gen LC`val' = exp(ln(RRraw`val'3)*(lden-40)/10)
gen UC`val' = exp(ln(RRraw`val'4)*(lden-40)/10)

* Lärmwerte unter 40dB einen Risiko von 1 zuweisen
replace RR`val' = 1 if lden < 40
replace LC`val' = 1 if lden < 40
replace UC`val' = 1 if lden < 40

list A`val' RR`val' LC`val' UC`val' in 1


* Population Attributable Fraction pro Haus - seperate nominator and denominator
gen PAFnom`val' = Total_ew_lden * (RR`val'-1) 
gen PAFden`val' = (Total_ew_lden * (RR`val')) 
gen lPAFnom`val' = Total_ew_lden * (LC`val'-1) 
gen lPAFden`val' = (Total_ew_lden * (LC`val'))
gen uPAFnom`val' = Total_ew_lden * (UC`val'-1) 
gen uPAFden`val' = (Total_ew_lden * (UC`val')) 

*Sum of PAFs
egen TotalPAFnom`val' = total(PAFnom`val') 
egen TotalPAFden`val' = total(PAFden`val')
gen  TotalPAF`val' = (TotalPAFnom`val')/(TotalPAFden`val') 
 
egen TotallPAFnom`val' = total(lPAFnom`val') 
egen TotallPAFden`val' = total(lPAFden`val')
gen  TotallPAF`val' = (TotallPAFnom`val')/(TotallPAFden`val') 

egen TotaluPAFnom`val' = total(uPAFnom`val') 
egen TotaluPAFden`val' = total(uPAFden`val')
gen  TotaluPAF`val' = (TotaluPAFnom`val')/(TotaluPAFden`val') 
 
list TotalPAF`val'  TotallPAF`val' TotaluPAF`val' in f/1
}


//
