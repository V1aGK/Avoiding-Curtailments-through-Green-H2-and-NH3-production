
$setglobal XFN    Scenarios1.xlsx
$setglobal GDXOUT Scenarios1.gdx

$if not exist "%XFN%" $abort 'Excel file not found: %XFN%'

$call gdxxrw i="%XFN%" o="%GDXOUT%" par=YD_S1 rng=Scenario1!H1:K21 rdim=1 cdim=1 par=YD_S2 rng=Scenario2!F1:I21 rdim=1 cdim=1 par=YD_S3 rng=Scenario3!F1:I21 rdim=1 cdim=1 par=YD_S4 rng=Scenario4!F1:I21 rdim=1 cdim=1 par=YD_S5 rng=Scenario5!F1:I21 rdim=1 cdim=1 par=YD_S6 rng=Scenario6!F1:I21 rdim=1 cdim=1 par=YD_S7 rng=Scenario7!F1:I21 rdim=1 cdim=1 > gdxxrw_all.log 2>&1
$if errorlevel 1 $abort 'gdxxrw failed (see gdxxrw_all.log)'
$if not exist "%GDXOUT%" $abort 'gdxxrw did not produce %GDXOUT% (see gdxxrw_all.log)'

$gdxin "%GDXOUT%"



SET y /y2026*y2045/;
SET y2030p(y) /y2030*y2045/;
ALIAS (y,yy);

SET scen /Scenario1*Scenario7/;
SET col  / 'Total Curtailed Energy [GWh]'
           'P25[MW]'
           'Eutilized(Percentile25) [GWh]' / ;

PARAMETER
  YD_S1(y,col) , YD_S2(y,col), YD_S3(y,col),
  YD_S4(y,col), YD_S5(y,col), YD_S6(y,col), YD_S7(y,col);
$load YD_S1 YD_S2 YD_S3 YD_S4 YD_S5 YD_S6 YD_S7

Scalar S1sum, P25max, CurtMax, EUtMax;

S1sum  = sum((y,col), YD_S1(y,col));
P25max = smax(y, YD_S1(y,'P25[MW]'));
CurtMax = smax(y, YD_S1(y,'Total Curtailed Energy [GWh]'));
EUtMax  = smax(y, YD_S1(y,'Eutilized(Percentile25) [GWh]'));

display S1sum, P25max, CurtMax, EUtMax;

abort$(S1sum=0) 'Excel read seems empty: check sheet/range/headers for Scenario1';

$gdxin

* unify all sheets into a single 3D parameter YearData(y,scen,col)
PARAMETER YearData(y,scen,col);
YearData(y,'Scenario1',col) = YD_S1(y,col);
YearData(y,'Scenario2',col) = YD_S2(y,col);
YearData(y,'Scenario3',col) = YD_S3(y,col);
YearData(y,'Scenario4',col) = YD_S4(y,col);
YearData(y,'Scenario5',col) = YD_S5(y,col);
YearData(y,'Scenario6',col) = YD_S6(y,col);
YearData(y,'Scenario7',col) = YD_S7(y,col);


* 1) Declares & price scenarios
PARAMETERS
   CurtE_GWh(y)     "curtailed energy [GWh]"
   P25_MW(y)        "P25 power [MW]"
   EUtilP25_MWh(y)  "Energy utilised based on P25 [MWh]"
   e_perMW_P25(y)   "MWh per MW from P25"
   P25_runmax(y)    "Running max of P25 up to year y";

SET pScen / Opt, Base, Pess /;

PARAMETER price_NH3(y,pScen) "€/t NH3 selling price";
TABLE priceNH3data(y,pScen)
         Pess    Base   Opt
y2026     700     900    1200
y2027     711     920    1224
y2028     722     940    1249
y2029     733     960    1274
y2030     744     980    1300
y2031     755    1000    1326
y2032     766    1020    1352
y2033     777    1050    1379
y2034     789    1080    1407
y2035     800    1100    1435
y2036     812    1120    1463
y2037     824    1140    1492
y2038     836    1160    1521
y2039     848    1180    1550
y2040     860    1200    1580
y2041     873    1220    1610
y2042     886    1240    1640
y2043     899    1260    1671
y2044     912    1280    1702
y2045     925    1300    1748 ;
price_NH3(y,pScen) = priceNH3data(y,pScen);

PARAMETER price_sel(y);

SCALARS
   hours_per_year /8760/
   kWh_per_MWh    /1000/
   kg_per_t       /1000/
   stoich_NH3     /5.6666667/ ;


* 2) Techno-economics
PARAMETERS
   elec_kWh_per_kgH2        "Electrolyzer SEC [kWh/kg H2]"
   capex_EL_per_kW(y)       "EL CAPEX [EUR/kW]"
   fOPEX_EL_frac            "EL fixed OPEX [%CAPEX/y]"
   vOPEX_EL_per_kgH2        "EL variable OPEX [EUR/kg H2]"
   r                        "discount rate"
   avail_EL                 "EL availability (0-1)"
   useP25cap                "0=no P25 cap, 1=P25 cap on energy"

   capex_HB_per_tpd_EUR(y)  "HB CAPEX [EUR per tNH3/day]"
   fOPEX_HB_frac            "HB fixed OPEX [%CAPEX/y]"
   vOPEX_HB_per_t           "HB variable OPEX [EUR/t NH3]"
   e_HB_MWh_per_tNH3        "HB electricity [MWh/t NH3]"
   avail_HB                 "HB availability (0-1)"

   capex_ASU_per_tpdN2_EUR(y) "ASU CAPEX [EUR per tN2/day]"
   fOPEX_ASU_frac            "ASU fixed OPEX [%CAPEX/y]"
   vOPEX_ASU_per_t           "ASU variable OPEX [EUR/t NH3]"
   e_ASU_MWh_per_tNH3        "ASU electricity [MWh/t NH3]"
   avail_ASU                 "ASU availability (0-1)"

   capex_H2buf_per_kg(y)     "H2 buffer CAPEX [EUR/kg H2 cap]"
   fOPEX_H2buf_frac          "Fixed OPEX H2 Buffer [%CAPEX/y]"
   e_H2buf_MWh_per_kgcap_y   "Electricity per kg H2 capacity [MWh/(kg·y)]"
   life_H2buf                "H2 buffer life [y]"
   h_H2buf_hours             "H2 buffer hours at EL nominal power"

   capex_NH3stor_per_t(y)    "NH3 storage CAPEX [EUR/t cap]"
   fOPEX_NH3stor_frac        "Fixed OPEX NH3 storage [%CAPEX/y]"
   e_NH3stor_MWh_per_tcap_y  "Refrigeration electricity [MWh/(t·y)]"
   life_NH3stor              "NH3 storage life [y]"
   d_NH3stor_days            "NH3 storage days of avg daily production"

   life_EL                   "EL life [y]"
   capex_HB_life             "HB life [y]"
   capex_ASU_life            "ASU life [y]"

   stack_rep_period_y        "years between EL stack repl."
   stack_rep_cost_frac       "stack repl. cost as fraction of EL CAPEX"

   c_elec_EUR_per_MWh        "Electricity price [EUR/MWh]" ;

* Defaults
elec_kWh_per_kgH2 = 55 ;
capex_EL_per_kW(y) = 700 ;          capex_EL_per_kW(y2030p) = 300;
fOPEX_EL_frac     = 0.03 ;
vOPEX_EL_per_kgH2 = 0.0 ;
r                 = 0.07 ;
avail_EL          = 0.96 ;
useP25cap         = 1 ;

capex_HB_per_tpd_EUR(y)      = 480000 ;   capex_HB_per_tpd_EUR(y2030p) = 300000 ;
fOPEX_HB_frac                = 0.03 ;
vOPEX_HB_per_t               = 0 ;
e_HB_MWh_per_tNH3            = 0.8 ;
avail_HB                     = 0.96 ;

capex_ASU_per_tpdN2_EUR(y)   = 80000 ;    capex_ASU_per_tpdN2_EUR(y2030p) = 60000 ;
fOPEX_ASU_frac               = 0.03 ;
vOPEX_ASU_per_t              = 0 ;
e_ASU_MWh_per_tNH3           = 0.41 ;
avail_ASU                    = 0.96 ;

capex_H2buf_per_kg(y)        = 300 ;      capex_H2buf_per_kg(y2030p) = 210 ;
fOPEX_H2buf_frac             = 0.03 ;
e_H2buf_MWh_per_kgcap_y      = 0.00005 ;
life_H2buf                   = 20 ;
h_H2buf_hours                = 12 ;

capex_NH3stor_per_t(y)       = 900 ;      capex_NH3stor_per_t(y2030p) = 810 ;
fOPEX_NH3stor_frac           = 0.03 ;
e_NH3stor_MWh_per_tcap_y     = 0 ;
life_NH3stor                 = 20 ;
d_NH3stor_days               = 7 ;

life_EL = 20 ; capex_HB_life = 20 ; capex_ASU_life = 20 ;
stack_rep_period_y = 2 ; stack_rep_cost_frac = 0.2 ;
c_elec_EUR_per_MWh = 0 ;

* 3) DF
PARAMETERS DF(y) "discount factor" ;
DF(y)       = 1 / ((1 + r)**(ORD(y)-1)) ;


* 4) Decision variables
POSITIVE VARIABLES
   dECap_MW(y)     "new EL capacity added [MW]"
   ECap_MW(y)      "total EL capacity [MW]"
   EUsed_MWh(y)    "energy used [MWh]"
   H2_kg(y)        "H2 production [kg]"
   NH3_t(y)        "NH3 production [t]"
   dCHB_tpd(y)     "new HB capacity added [tNH3/day]"
   CHB_tpd(y)      "total HB capacity [tNH3/day]"
   dCASU_tpdN2(y)  "new ASU capacity added [tN2/day]"
   CASU_tpdN2(y)   "total ASU capacity [tN2/day]" ;
   

VARIABLE ProfitNPV ;

* 5) Constraints

EQUATIONS
   e_cumcap(y)
   e_energy_curt(y)
   e_energy_capEL(y)
   e_energy_P25_intensity(y)
   e_cap_follow_P25(y)
   e_h2(y)
   e_nh3(y)
   e_hb_cum(y), e_asu_cum(y)
   e_hb_cap_max(y), e_asu_cap_max(y)
   e_hb_cap_min(y), e_asu_cap_min(y)
   e_obj ;

* Cumulative EL
e_cumcap(y)..       ECap_MW(y) =E= SUM(yy$(ORD(yy)<=ORD(y)), dECap_MW(yy));

* Energy limits
e_cap_follow_P25(y).. ECap_MW(y) =L= P25_runmax(y);
e_energy_curt(y)..     EUsed_MWh(y) =L= CurtE_GWh(y) * 1000 ;
e_energy_capEL(y)..    EUsed_MWh(y) =L= ECap_MW(y) * hours_per_year
                                                    * avail_EL ;
e_energy_P25_intensity(y)..  EUsed_MWh(y) =L= e_perMW_P25(y) * ECap_MW(y);

* Conversions
e_h2(y)..   H2_kg(y) =E= (EUsed_MWh(y) * kWh_per_MWh) / elec_kWh_per_kgH2 ;
e_nh3(y)..  NH3_t(y) =E= (H2_kg(y) * stoich_NH3) / kg_per_t ;

* HB / ASU accumulation
e_hb_cum(y)..  CHB_tpd(y)    =E= SUM(yy$(ORD(yy)<=ORD(y)), dCHB_tpd(yy));
e_asu_cum(y).. CASU_tpdN2(y) =E= SUM(yy$(ORD(yy)<=ORD(y)), dCASU_tpdN2(yy));

* Capacity factors
SCALAR CF_HB_max /0.90/ , CF_HB_min /0.35/ ;
e_hb_cap_max(y)..   NH3_t(y) =L= CHB_tpd(y) * 365 * CF_HB_max * avail_HB ;
e_hb_cap_min(y)..   NH3_t(y) =G= CHB_tpd(y) * 365 * CF_HB_min ;

PARAMETER N2perNH3 /0.823529/ ;
SCALAR CF_ASU_max /0.95/ , CF_ASU_min /0.40/ ;
e_asu_cap_max(y)..  N2perNH3 * NH3_t(y) =L= CASU_tpdN2(y) * 365 * CF_ASU_max * avail_ASU ;
e_asu_cap_min(y)..  N2perNH3 * NH3_t(y) =G= CASU_tpdN2(y) * 365 * CF_ASU_min ;

* Objective
e_obj..
ProfitNPV =E=
  SUM(y, DF(y) * (
        price_sel(y) * NH3_t(y)
      - ( vOPEX_EL_per_kgH2 * H2_kg(y)
        +   vOPEX_HB_per_t  * NH3_t(y)
        +   vOPEX_ASU_per_t * NH3_t(y)
        +   c_elec_EUR_per_MWh * ( EUsed_MWh(y)
                                  + e_HB_MWh_per_tNH3*NH3_t(y)
                                  + e_ASU_MWh_per_tNH3*NH3_t(y) ) )
      - (
        fOPEX_EL_frac    * capex_EL_per_kW(y)        * (ECap_MW(y)*1000)
    + fOPEX_HB_frac    * capex_HB_per_tpd_EUR(y)   *  CHB_tpd(y)
    + fOPEX_ASU_frac   * capex_ASU_per_tpdN2_EUR(y)*  CASU_tpdN2(y)
    + fOPEX_H2buf_frac * capex_H2buf_per_kg(y)     * ( h_H2buf_hours * (ECap_MW(y)*1000) / elec_kWh_per_kgH2 )
    + fOPEX_NH3stor_frac * capex_NH3stor_per_t(y)  * ( d_NH3stor_days * (NH3_t(y)/365) ))
      -  ( capex_EL_per_kW(y)         * (dECap_MW(y)*1000)
    + capex_HB_per_tpd_EUR(y)    *  dCHB_tpd(y)
    + capex_ASU_per_tpdN2_EUR(y) *  dCASU_tpdN2(y)
    + capex_H2buf_per_kg(y)      * ( h_H2buf_hours * (dECap_MW(y)*1000) / elec_kWh_per_kgH2 )
    + capex_NH3stor_per_t(y)     * ( d_NH3stor_days * (NH3_t(y)/365) ) )         
       - SUM(yy$(ORD(yy)=ORD(y)-stack_rep_period_y),
        stack_rep_cost_frac * capex_EL_per_kW(yy) * (dECap_MW(yy)*1000))
      ))  ;

MODEL EL_Sizing_Annual /ALL/ ;

* 6) Reporting
FILE fOpt  /results_Opt.csv/ ,
     fBase /results_Base.csv/ ,
     fPess /results_Pess.csv/ ;

PARAMETER
   Ann_EL(y), Ann_Stacks(y), Ann_HB(y), Ann_ASU(y), Ann_H2buf(y), Ann_NH3stor(y)
 , vElec_y(y), vProc_y(y), fOPEX_y(y), AnnCAPEX_y(y)
 , Revenue_y(y), Net_y(y), DiscNet_y(y), LCOA_y(y), CF_EL(y), E_total_MWh(y),  H2buf_cap_kg(y)   ;

PARAMETER Report(y,scen,pScen,*) 'results per year for each (curtailment, price) scenario' ;
PARAMETER ProfitNPV_s(scen,pScen) 'NPV per (curtailment, price) scenario';


* 7) Nested loops: curtailment scenario (scen) × price scenario (pScen)

LOOP(scen,

* pick curtailment/P25 for this scenario
  CurtE_GWh(y)     = YearData(y,scen,'Total Curtailed Energy [GWh]');
  P25_MW(y)        = YearData(y,scen,'P25[MW]');
  EUtilP25_MWh(y)  = 1000 * YearData(y,scen,'Eutilized(Percentile25) [GWh]');
  e_perMW_P25(y)   = EUtilP25_MWh(y) / MAX(1e-6, P25_MW(y));
  P25_runmax(y)    = SMAX(yy$(ORD(yy)<=ORD(y)), P25_MW(yy));

  LOOP(pScen,

* set active ammonia price vector
    price_sel(y) = price_NH3(y,pScen);

    SOLVE EL_Sizing_Annual USING LP MAXIMIZING ProfitNPV ;

* yearly accounting 
    Ann_EL(y)      = capex_EL_per_kW(y)        * (dECap_MW.l(y)*1000) ;
    Ann_Stacks(y)  = SUM(yy$(ORD(yy)=ORD(y)-stack_rep_period_y),
    stack_rep_cost_frac * capex_EL_per_kW(yy) * (dECap_MW.l(yy)*1000));
    Ann_HB(y)      = capex_HB_per_tpd_EUR(y)   * dCHB_tpd.l(y) ;
    Ann_ASU(y)     = capex_ASU_per_tpdN2_EUR(y)* dCASU_tpdN2.l(y) ;
    Ann_H2buf(y)   = capex_H2buf_per_kg(y)     * ( h_H2buf_hours * (dECap_MW.l(y)*1000) / elec_kWh_per_kgH2 ) ;
    Ann_NH3stor(y) = capex_NH3stor_per_t(y)    * ( d_NH3stor_days * (NH3_t.l(y)/365) ) ;

    vElec_y(y) = c_elec_EUR_per_MWh * ( EUsed_MWh.l(y)
                   + e_HB_MWh_per_tNH3*NH3_t.l(y) + e_ASU_MWh_per_tNH3*NH3_t.l(y) ) ;

    vProc_y(y) = vOPEX_EL_per_kgH2 * H2_kg.l(y)
               + vOPEX_HB_per_t    * NH3_t.l(y)
               + vOPEX_ASU_per_t   * NH3_t.l(y) ;

    fOPEX_y(y) = fOPEX_EL_frac  * capex_EL_per_kW(y)           * (ECap_MW.l(y)*1000)
               + fOPEX_HB_frac  * capex_HB_per_tpd_EUR(y)      * CHB_tpd.l(y)
               + fOPEX_ASU_frac * capex_ASU_per_tpdN2_EUR(y)   * CASU_tpdN2.l(y)
               + fOPEX_H2buf_frac   * capex_H2buf_per_kg(y)    * ( h_H2buf_hours * (ECap_MW.l(y)*1000) / elec_kWh_per_kgH2 )
               + fOPEX_NH3stor_frac * capex_NH3stor_per_t(y)   * ( d_NH3stor_days * (NH3_t.l(y)/365) ) ;

    AnnCAPEX_y(y) = Ann_EL(y)+Ann_Stacks(y)+Ann_HB(y)+Ann_ASU(y)+Ann_H2buf(y)+Ann_NH3stor(y) ;

    Revenue_y(y) = price_sel(y) * NH3_t.l(y) ;
    Net_y(y)     = Revenue_y(y) - (vElec_y(y)+vProc_y(y)+fOPEX_y(y)+AnnCAPEX_y(y)) ;
    DiscNet_y(y) = DF(y) * Net_y(y) ;
    LCOA_y(y)    = ( vElec_y(y)+vProc_y(y)+fOPEX_y(y)+AnnCAPEX_y(y) ) / MAX(1e-9, NH3_t.l(y)) ;
    CF_EL(y)     = EUsed_MWh.l(y) / MAX(1e-6, ECap_MW.l(y)*hours_per_year) ;
    
    H2buf_cap_kg(y) = h_H2buf_hours * (ECap_MW.l(y)*1000) / elec_kWh_per_kgH2;
    
    E_total_MWh(y) = EUsed_MWh.l(y)
               + e_HB_MWh_per_tNH3  * NH3_t.l(y)
               + e_ASU_MWh_per_tNH3 * NH3_t.l(y)
               + e_H2buf_MWh_per_kgcap_y * H2buf_cap_kg(y) ;
               

    ProfitNPV_s(scen,pScen) = ProfitNPV.l ;

    Report(y,scen,pScen,'ECap_MW')      = ECap_MW.l(y) ;
    Report(y,scen,pScen,'AddCap_MW')    = dECap_MW.l(y) ;
    Report(y,scen,pScen,'CHB_tpd')      = CHB_tpd.l(y) ;
    Report(y,scen,pScen,'AddCHB_tpd')   = dCHB_tpd.l(y) ;
    Report(y,scen,pScen,'CASU_tpdN2')   = CASU_tpdN2.l(y) ;
    Report(y,scen,pScen,'AddASU_tpdN2') = dCASU_tpdN2.l(y) ;

    Report(y,scen,pScen,'EUsed_MWh')    = EUsed_MWh.l(y) ;
    Report(y,scen,pScen,'H2_t')         = H2_kg.l(y)/1000 ;
    Report(y,scen,pScen,'NH3_t')        = NH3_t.l(y) ;
    Report(y,scen,pScen,'Price_EURt')   = price_sel(y) ;

    Report(y,scen,pScen,'Revenue_EUR')  = Revenue_y(y) ;
    Report(y,scen,pScen,'vElec_EUR')    = vElec_y(y) ;
    Report(y,scen,pScen,'vProc_EUR')    = vProc_y(y) ;
    Report(y,scen,pScen,'fOPEX_EUR')    = fOPEX_y(y) ;
    Report(y,scen,pScen,'AnnCAPEX_EUR') = AnnCAPEX_y(y) ;
    Report(y,scen,pScen,'NetCash_EUR')  = Net_y(y) ;
    Report(y,scen,pScen,'DiscFactor')   = DF(y) ;
    Report(y,scen,pScen,'DiscNet_EUR')  = DiscNet_y(y) ;
    Report(y,scen,pScen,'LCOA_EURt')    = LCOA_y(y) ;
    Report(y,scen,pScen,'CF_EL')        = CF_EL(y) ;
    
    
    Report(y,scen,pScen,'Ann_EL')       = Ann_EL(y) ;
    Report(y,scen,pScen,'Ann_Stacks')   = Ann_Stacks(y) ;
    Report(y,scen,pScen,'Ann_HB')       = Ann_HB(y) ;
    Report(y,scen,pScen,'Ann_ASU')      = Ann_ASU(y) ;
    Report(y,scen,pScen,'Ann_H2buf')    = Ann_H2buf(y) ;
    Report(y,scen,pScen,'Ann_NH3stor')  = Ann_NH3stor(y) ;
    
    Report(y,scen,pScen,'Ann_EL_Disc')      = DF(y) * Ann_EL(y);
    Report(y,scen,pScen,'Ann_Stacks_Disc')  = DF(y) * Ann_Stacks(y);
    Report(y,scen,pScen,'Ann_HB_Disc')      = DF(y) * Ann_HB(y);
    Report(y,scen,pScen,'Ann_ASU_Disc')     = DF(y) * Ann_ASU(y);
    Report(y,scen,pScen,'Ann_H2buf_Disc')   = DF(y) * Ann_H2buf(y);
    Report(y,scen,pScen,'Ann_NH3stor_Disc') = DF(y) * Ann_NH3stor(y);

    Report(y,scen,pScen,'E_total_MWh')   = E_total_MWh(y);
  );
* end LOOP pScen
);
* end LOOP scen

DISPLAY Report ;
DISPLAY ProfitNPV_s ;



$setglobal XOUT Results.xlsx

* Create Excel
execute 'gdxxrw o=%XOUT% clear=all';

* Store data to GDX
execute_unload 'out.gdx', Report, ProfitNPV_s;

execute 'gdxxrw i=out.gdx o=%XOUT% par=Report rng=All!A1 rdim=3 cdim=1 squeeze=Yes';

* NPV πίνακας (scen × pScen)
execute 'gdxxrw i=out.gdx o=%XOUT% par=ProfitNPV_s rng=NPV!A1 rdim=1 cdim=1 squeeze=Yes';
