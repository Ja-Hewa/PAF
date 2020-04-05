*--------------------------------------------------
* HLNUG -DALY Berechnung Annoyance
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
* PAF - L24h Annoyance
*--------------------------------------------------
gen id = . 
gen gHA = .
gen str Gemeinde=" "
save DALY_ANNOY.dta, replace


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

egen Total_HE =total(AnzahlEW)

save Anzahl_EW_GMD, replace


* Import GMD Lärmdaten & kombiniere mit RR
use Anzahl_EW_GMD, clear

levelsof GKZ, local(levels) 
*foreach l in 411000 {
*foreach l in 635019 {
*foreach l in 635019 {

foreach l of local levels {

display `l'
 *local ds1 "C:\Users\Hegewald\Nextcloud\Shared\HLNUG\Daten\FassadenpunkteLuftLärm" //Verteilt auf alle Hausfassaden
 *local ds2 "_ROAD_FAS_P_LaermLuft.txt"*
 local ds1 "C:\Users\Hegewald\Nextcloud\Shared\HLNUG\Daten\HauspunkteLuftLärm\Haus\P" //Lauteste Fassade pro Haus
 local ds2 "_ROAD_HAUS_P_LaermLuft.txt"
 
 local ds = "`ds1'\`l'`ds2'"
 display "`ds'"
 
 
/*--------------------------------------------------
* Lärmdaten - Lden
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

merge m:1 GKZ using Anzahl_EW_GMD, ///
	keepusing(Gemeinde GKZ AnzahlEW P_u40 Hessen_u40 Total_HE) keep(3)
drop _merge
 
*--------------------------------------------------
* %HA - Lden Annoyance 
*--------------------------------------------------

*Estimated %HA = 78.9270 − 3.1162 × Lden + 0.0342 × Lden2.
*(Guski et al. 2017)
*l24 oder lden
gen pHA = 78.9270 - (3.1162*lden) + (0.0342*(lden^2))

*gen pHA =  116.4304 - (4.7342*lden) + (0.0497*(lden^2))
gen AnzHA = ew*(pHA/100)



* Gesamt PAF in der Gemeinde
bysort GKZ: egen gHA=total(AnzHA)


keep id Gemeinde gHA 
keep in 1

append using DALY_ANNOY.dta, keep(id Gemeinde gHA ) force
save DALY_ANNOY.dta, replace

}
*

use DALY_ANNOY.dta, clear
 
egen TotalHA = sum(gHA)

list TotalHA in f/1
