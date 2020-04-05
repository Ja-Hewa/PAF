*--------------------------------------------------
* HLNUG -DALY Berechnung Depression
* 2018 Dez 14, version 1
* 2019 Jan 07, - run over all AGS
* 2019 NOV 05, - Hauspunkte
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
* PAF - L24h Depression (NORAH) - leere Datensatz
*--------------------------------------------------
gen id = . 
gen gPAF = .
gen glPAF = .
gen guPAF = .
gen str Gemeinde=" "
save DALY_DEP.dta, replace


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
*foreach l in 635019 {*/
foreach l of local levels {
 display `l'
 *local ds1 "C:\Users\Hegewald\Nextcloud\Shared\HLNUG\Daten\FassadenpunkteLuftLärm" //Verteilt auf alle Hausfassaden
 *local ds2 "_ROAD_FAS_P_LaermLuft.txt"*
 local ds1 "C:\Users\Hegewald\Nextcloud\Shared\HLNUG\Daten\HauspunkteLuftLärm\Haus\P" //Lauteste Fassade pro Haus
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



* Einwohnerzahl(ew) gewichten nach Anteil über 40 i.d. Gemeinde 
gen p = (ew * P_u40)/Hessen_u40 // Proportion exponierten

* Gesamt Stassenlaermexponierten in der Gemeinde
bysort GKZ: egen tot_GeExp = total(ew)

* Laermexponierten ueber 40J
display tot_GeExp * P_u40 

 
*--------------------------------------------------
* PAF - L24h Herzinfarkt (NORAH)
*--------------------------------------------------

*** STRASSENVERKEHRSLAERM NORAH *****
*   Herzinfarkt Risiko  OR = 1,024	[1,016, 1,033] (Seidler et al. 2019)
* gen RR = exp(ln(RR_per10dB) * l24h)
*l24 oder lden
gen RR = exp(ln(1.041)*(lden-40)/10) 
gen LC = exp(ln(1.031)*(lden-40)/10)
gen UC = exp(ln(1.05)*(lden-40)/10)

* Lärmwerte unter 40dB einen Risiko von 1 zuweisen
replace RR = 1 if lden < 40 
replace LC = 1 if lden < 40
replace UC = 1 if lden < 40

* Population Attributable Fraction pro Haus
gen PAF = (p * (RR-1)) / (p * (RR-1)+1)
gen lPAF = (p * (LC-1)) / (p * (LC-1)+1)
gen uPAF = (p * (UC-1)) / (p * (UC-1)+1)



* Gesamt PAF in der Gemeinde
bysort GKZ: egen gPAF=total(PAF)
bysort GKZ: egen glPAF=total(lPAF)
bysort GKZ: egen guPAF=total(uPAF)


keep id Gemeinde gPAF glPAF guPAF
keep in 1

append using DALY_DEP.dta, keep(id Gemeinde gPAF glPAF guPAF ) force
save DALY_DEP.dta, replace

}
*

 use DALY_DEP.dta, clear
 
 egen TotalPAF = sum(gPAF)
 egen Total_loPAF = sum(glPAF)
 egen Total_hiPAF = sum(guPAF)

list TotalPAF Total_loPAF Total_hiPAF in f/1
