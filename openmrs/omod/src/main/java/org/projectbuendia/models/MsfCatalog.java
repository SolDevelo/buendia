package org.projectbuendia.models;

public interface MsfCatalog extends Catalog {
    Route UNSPECIFIED = new Route("", "", "");
    Route PO = new Route("PO", "oral [fr:orale]", "PO");
    Route IV = new Route("IV", "intravenous [fr:intraveineuse]", "IV");
    Route SC = new Route("SC", "subcutaneous [fr:sous-cutanée", "SC");
    Route IM = new Route("IM", "intramuscular [fr:intramusculaire]", "IM");
    Route IO = new Route("IO", "intraosseous [fr:intraosseux]", "IO");
    Route OC = new Route("OC", "ocular [fr:oculaire]", "OC");

    // ==== BEGIN GENERATED OUTPUT ====
    // Produced by executing: build_catalog catalog-drc-pilot.csv app/src/main/java/org/projectbuendia/models/MsfCatalog.java ../openmrs/omod/src/main/java/org/projectbuendia/models/MsfCatalog.java

    Category ORAL = new Category("DORA", "oral", false, PO).withDrugs(
        new Drug("DORAACIV", "ACICLOVIR [fr:ACICLOVIR]").withFormats(
            new Format("DORAACIV2T", "200 mg, tab. [fr:200 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAACSA", "ACETYLSALICYLIC acid (aspirin) [fr:Acide ACETYLSALICYLIQUE (aspirine)]").withFormats(
            new Format("DORAACSA3T", "300 mg, tab. [fr:300 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAALBE", "ALBENDAZOLE [fr:ALBENDAZOLE]").withFormats(
            new Format("DORAALBE4T", "400 mg, tab. [fr:400 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAALUM", "ALUMINIUM hydroxide / MAGNESIUM hydroxide [fr:ALUMINIUM hydroxyde / MAGNESIUM hydroxyde]").withFormats(
            new Format("DORAALUM44TC", "400 mg / 400 mg, chew. tab. [fr:400 mg / 400 mg, cp. à mâcher]", Unit.TABLET)
        ),
        new Drug("DORAAMOC", "AMOXICILLIN / CLAVULANIC acid [fr:AMOXICILLINE / acide CLAVULANIQUE]").withFormats(
            new Format("DORAAMOC22TD", "200 mg / 28.5 mg, disp. tab. [fr:200 mg / 28.5 mg, comp. disp.]", Unit.TABLET),
            new Format("DORAAMOC4S5", "400 mg / 57 mg / 5 ml, powd. oral susp. 70 ml [fr:400 mg / 57 mg / 5 ml, poudre susp. orale 70 ml]", Unit.ML),
            new Format("DORAAMOC56T", "500 mg / 62.5 mg, tab. [fr:500 mg / ac. 62.5 mg, comp.]", Unit.TABLET),
            new Format("DORAAMOC81T", "875 mg / 125 mg, tab. [fr:875 mg / ac. 125 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAAMOX", "AMOXICILLIN [fr:AMOXICILLINE]").withFormats(
            new Format("DORAAMOX1S1", "125 mg / 5 ml, powder oral susp., 100 ml, bot. [fr:125 mg / 5 ml, poudre susp. orale, 100 ml, fl]", Unit.ML),
            new Format("DORAAMOX2T", "250 mg, tab. [fr:250 mg, comp.]", Unit.TABLET),
            new Format("DORAAMOX2TDB", "250 mg, disp. and breakable tab. [fr:250 mg, comp. disp et sécable]", Unit.TABLET),
            new Format("DORAAMOX5T", "500 mg, tab. [fr:500 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAARLU", "AL (ARTEMETHER / LUMEFANTRINE) [fr:AL (ARTEMETHER / LUMEFANTRINE)]").withFormats(
            new Format("DORAARLU3T1", "20/120 mg, blister of 18 tab., 25-34 kg [fr:20/120 mg, blister de 18 comp., 25-34 kg]", Unit.TABLET)
        ),
        new Drug("DORAASAQ", "AS / AQ (ARTESUNATE / AMODIAQUINE) [fr:AS / AQ (ARTESUNATE / AMODIAQUINE)]").withFormats(
            new Format("DORAASAQ1T1", "25 mg / eq. 67.5 mg base, blister of 3 tab, 4.5-8 kg [fr:25 mg / éq. 67.5 mg base, blister de 3 comp, 4.5-8 kg]", Unit.TABLET),
            new Format("DORAASAQ2T1", "50 mg / eq. 135 mg base, blister of 3 tab, 9-17 kg [fr:50 mg / éq. 135 mg base, blister de 3 comp., 9-17 kg]", Unit.TABLET),
            new Format("DORAASAQ3T1", "100 mg / eq. 270 mg base, blister of 3 tab, 18-35 kg [fr:100 mg / éq. 270 mg base, blister de 3 comp., 18-35kg]", Unit.TABLET),
            new Format("DORAASAQ4T1", "100 mg / eq. 270 mg base, blister of 6 tab., >36 kg [fr:100 mg / éq. 270 mg base, blister de 6 comp., >36 kg]", Unit.TABLET)
        ),
        new Drug("DORAASCA", "ASCORBIC acid (vitamin C) [fr:Acide ASCORBIQUE (vitamine C)]").withFormats(
            new Format("DORAASCA2T", "250 mg, tab. [fr:250 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAATOP", "ATOVAQUONE / PROGUANIL HCl [fr:ATOVAQUONE / PROGUANIL HCl]").withFormats(
            new Format("DORAATOP1T1", "62.5 mg / 25 mg, tab., 11-40kg [fr:62.5 mg / 25 mg, comp, blister, 11-40kg]", Unit.TABLET),
            new Format("DORAATOP2T1", "250 mg / 100 mg, tab., >40 kg [fr:250 mg / 100 mg, comp, blister, >40 kg]", Unit.TABLET)
        ),
        new Drug("DORAAZIT", "AZITHROMYCIN [fr:AZITHROMYCINE]").withFormats(
            new Format("DORAAZIT2T", "250 mg, tab. [fr:250 mg, comp.]", Unit.TABLET),
            new Format("DORAAZIT5T", "500 mg, tab [fr:500 mg, comp]", Unit.TABLET),
            new Format("DORAAZIT3S1", "200 mg / 5 ml, powder oral susp., 15 ml, bot. [fr:200 mg / 5 ml, poudre susp. orale, 15 ml, fl.]", Unit.ML)
        ),
        new Drug("DORABECL", "BECLOMETASONE dipropionate [fr:BECLOMETASONE dipropionate]").withFormats(
            new Format("DORABECL1SF", "0.10 mg / puff, 200 puffs, aerosol [fr:0.10 mg / bouffée, 200 b., aérosol]", Unit.PUFF),
            new Format("DORABECL2SF", "0.25 mg / puff, 200 puffs, aerosol [fr:0.25 mg / bouffée, 200 b., aérosol]", Unit.PUFF),
            new Format("DORABECL5SF", "0.05 mg / puff, 200 puffs, aerosol [fr:0.05 mg / bouffée, 200 b., aérosol]", Unit.PUFF)
        ),
        new Drug("DORABISO", "BISOPROLOL fumarate [fr:BISOPROLOL fumarate]").withFormats(
            new Format("DORABISO1TB4", "10 mg, break. tab. in 1/4 [fr:10 mg, comp. quadrisécable]", Unit.TABLET),
            new Format("DORABISO2TB", "2.5 mg, break. tab. [fr:2.5 mg, comp. séc.]", Unit.TABLET)
        ),
        new Drug("DORACABG", "CABERGOLINE [fr:CABERGOLINE]").withFormats(
            new Format("DORACABG5TB", "0.5 mg, break. tab. [fr:0.5 mg, comp. séc.]", Unit.TABLET)
        ),
        new Drug("DORACALC", "CALCIUM carbonate [fr:CALCIUM carbonate]").withFormats(
            new Format("DORACALC5TC", "eq. 500 mg Ca, chewable tab. [fr:éq. 500 mg Ca, comp. à mâcher]", Unit.TABLET)
        ),
        new Drug("DORACEFI", "CEFIXIME [fr:CEFIXIME]").withFormats(
            new Format("DORACEFI2S", "100 mg / 5 ml, powder for oral susp., 60 ml, bot. [fr:100 mg / 5 ml, poudre pour susp. orale, 60 ml, fl.]", Unit.ML),
            new Format("DORACEFI2T", "200 mg, tab. [fr:200 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORACEFX", "CEFALEXIN [fr:CEFALEXINE]").withFormats(
            new Format("DORACEFX1S", "125 mg / 5 ml, granules oral susp., 100 ml, bot. [fr:125 mg / 5 ml, granules susp. orale, 100 ml, fl.]", Unit.ML)
        ),
        new Drug("DORACHLM", "CHLORPROMAZINE hydrochloride [fr:CHLORPROMAZINE chlorhydrate]").withFormats(
            new Format("DORACHLM2T", "eq. 25 mg base, tab. [fr:éq. 25 mg base, comp.]", Unit.TABLET)
        ),
        new Drug("DORACIPR", "CIPROFLOXACIN [fr:CIPROFLOXACINE]").withFormats(
            new Format("DORACIPR1S", "250 mg / 5 ml, gran. + solvent oral susp [fr:250 mg / 5 ml, gran. + solvant susp. orale]", Unit.ML),
            new Format("DORACIPR2T", "hydrochloride, eq. 250 mg base, tab. [fr:chlorhydrate, éq. 250 mg base, comp.]", Unit.TABLET),
            new Format("DORACIPR5T", "hydrochloride, eq. 500 mg base, tab. [fr:chlorhydrate, éq. 500 mg base, comp.]", Unit.TABLET)
        ),
        new Drug("DORACLOX", "CLOXACILLIN sodium [fr:CLOXACILLINE sodique]").withFormats(
            new Format("DORACLOX2C", "eq. 250 mg base, caps. [fr:éq. 250 mg base, gél.]", Unit.CAPSULE),
            new Format("DORACLOX5C", "eq. 500 mg base, caps. [fr:éq. 500 mg base, gél.]", Unit.CAPSULE)
        ),
        new Drug("DORACOTR", "COTRIMOXAZOLE [fr:COTRIMOXAZOLE]").withFormats(
            new Format("DORACOTR4T", "400 mg / 80 mg, tab. [fr:400 mg / 80 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORADIAZ", "DIAZEPAM [fr:DIAZEPAM]").withFormats(
            new Format("DORADIAZ5T", "5 mg, tab. [fr:5 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORADOLU", "DOLUTEGRAVIR sodium (DTG) [fr:DOLUTEGRAVIR sodium (DTG)]").withFormats(
            new Format("DORADOLU5T", "eq. 50 mg base, tab. [fr:éq. 50 mg base, comp.]", Unit.TABLET)
        ),
        new Drug("DORADOXY", "DOXYCYCLINE salt [fr:DOXYCYCLINE sel]").withFormats(
            new Format("DORADOXY1T", "eq. 100 mg base, tab. [fr:éq. 100 mg base, comp.]", Unit.TABLET)
        ),
        new Drug("DORAENAL", "ENALAPRIL maleate [fr:ENALAPRIL maléate]").withFormats(
            new Format("DORAENAL2T", "20 mg, tab. [fr:20 mg, comp.]", Unit.TABLET),
            new Format("DORAENAL5T", "5 mg, tab. [fr:5 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAETHL", "ETHINYLESTRADIOL / LEVONORGESTREL [fr:ETHINYLESTRADIOL / LEVONORGESTREL]").withFormats(
            new Format("DORAETHL31T", "0.03 mg / 0.15 mg, blister 28tab [fr:0.03 mg / 0.15 mg, plaq. 28 comp.]", Unit.MG)
        ),
        new Drug("DORAFERF", "FERROUS salt / FOLIC acid (FEFOL) [fr:sel de FER / acide FOLIQUE (FEFOL)]").withFormats(
            new Format("DORAFERF14T", "eq. 60 mg iron / 0.4 mg, tab [fr:éq. 60 mg fer / 0.4 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAFLUC", "FLUCONAZOLE [fr:FLUCONAZOLE]").withFormats(
            new Format("DORAFLUC1S", "50 mg / 5 ml, powder oral susp., bot. [fr:50 mg / 5 ml, poudre susp. orale, fl.]", Unit.ML),
            new Format("DORAFLUC2C", "200 mg, caps. [fr:200 mg, gél.]", Unit.CAPSULE),
            new Format("DORAFLUC5C", "50 mg, caps. [fr:50 mg, gél.]", Unit.CAPSULE)
        ),
        new Drug("DORAFOLA", "FOLIC acid [fr:Acide FOLIQUE]").withFormats(
            new Format("DORAFOLA5T", "5 mg, tab. [fr:5 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAFURO", "FUROSEMIDE [fr:FUROSEMIDE]").withFormats(
            new Format("DORAFURO2T", "20 mg, tab. [fr:20 mg, comp.]", Unit.TABLET),
            new Format("DORAFURO4T", "40 mg, tab. [fr:40 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAGLYT", "GLYCERYL TRINITRATE [fr:GLYCERYLE TRINITRATE]").withFormats(
            new Format("DORAGLYT5T", "0.5 mg, sublingual tab. [fr:0.5 mg, comp. sublingual]", Unit.TABLET)
        ),
        new Drug("DORAHALP", "HALOPERIDOL [fr:HALOPERIDOL]").withFormats(
            new Format("DORAHALP3D", "2 mg / ml / 20 drops, 30 ml, bot. [fr:2 mg / ml / 20 gouttes, 30 ml, fl.]", Unit.ML),
            new Format("DORAHALP5T", "5 mg, tab. [fr:5 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAHYOS", "HYOSCINE BUTYLBROMIDE (scopolamine butylbromide) [fr:BUTYLBROMURE HYOSCINE (butylbromure scopolamine)]").withFormats(
            new Format("DORAHYOS1T", "10 mg, tab [fr:10 mg, cp]", Unit.TABLET)
        ),
        new Drug("DORAIBUP", "IBUPROFEN [fr:IBUPROFENE]").withFormats(
            new Format("DORAIBUP2T", "200 mg, tab. [fr:200 mg, comp.]", Unit.TABLET),
            new Format("DORAIBUP4T", "400 mg, tab. [fr:400 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAIPRA", "IPRATROPIUM bromide [fr:IPRATROPIUM bromure]").withFormats(
            new Format("DORAIPRA5N", "0.250 mg / ml, 2 ml, sol. for nebuliser [fr:0.250 mg / ml, 2 ml, sol. pour nébuliseur]", Unit.ML)
        ),
        new Drug("DORAISOB", "ISOSORBIDE DINITRATE [fr:ISOSORBIDE DINITRATE]").withFormats(
            new Format("DORAISOB5T", "5 mg, sublingual tab. [fr:5 mg, comp. sublingual]", Unit.TABLET)
        ),
        new Drug("DORAIVER", "IVERMECTIN (scabies + other indic. ) [fr:IVERMECTINE (gale + autres indic. )]").withFormats(
            new Format("DORAIVER3TS", "3 mg, tab. [fr:3 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORALACT", "LACTULOSE [fr:LACTULOSE]").withFormats(
            new Format("DORALACT1S", "min. 3.1 g / 5 ml, oral sol., bot. [fr:min. 3.1 g / 5 ml, sol. orale, fl.]", Unit.ML)
        ),
        new Drug("DORALEVN", "LEVONORGESTREL [fr:LEVONORGESTREL]").withFormats(
            new Format("DORALEVN1T", "1.5 mg, tab. [fr:1.5 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORALOPE", "LOPERAMIDE hydrochloride [fr:LOPERAMIDE chlorhydrate]").withFormats(
            new Format("DORALOPE2T", "2 mg, tab. [fr:2 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORALORA", "LORATADINE [fr:LORATADINE]").withFormats(
            new Format("DORALORA1T", "10 mg, tab. [fr:10 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMAGN", "MAGNESIUM oxide [fr:Oxyde de MAGNESIUM]").withFormats(
            new Format("DORAMAGN3T", "eq. to 300 mg Mg, tab. [fr:éq. à 300 mg Mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMEFL", "MEFLOQUINE hydrochloride [fr:MEFLOQUINE chlorhydrate]").withFormats(
            new Format("DORAMEFL2T", "eq. 250 mg base, tab. [fr:éq. 250 mg base, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMETF", "METFORMIN hydrochloride [fr:METFORMINE chlorhydrate]").withFormats(
            new Format("DORAMETF5T", "500 mg, tab. [fr:500 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMETN", "METRONIDAZOLE [fr:METRONIDAZOLE]").withFormats(
            new Format("DORAMETN2S", "benzoate, eq. 200 mg / 5 ml base, oral susp., 100 ml [fr:benzoate, éq. 200 mg / 5 ml base, susp. orale, 100 ml]", Unit.ML),
            new Format("DORAMETN2T", "250 mg, tab. [fr:250 mg, comp.]", Unit.TABLET),
            new Format("DORAMETN5T", "500 mg, tab. [fr:500 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMETO", "METOCLOPRAMIDE hydrochloride anhydrous [fr:METOCLOPRAMIDE chlorhydrate anhydre]").withFormats(
            new Format("DORAMETO1T", "10 mg, tab. [fr:10 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMETY", "METHYLDOPA [fr:METHYLDOPA]").withFormats(
            new Format("DORAMETY2T", "250 mg, tab. [fr:250 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMICO", "MICONAZOLE [fr:MICONAZOLE]").withFormats(
            new Format("DORAMICO2J4", "2%, oral gel, 40 g, tube [fr:2%, gel oral, 40 g, tube]", Unit.ML)
        ),
        new Drug("DORAMIFP", "MIFEPRISTONE [fr:MIFEPRISTONE]").withFormats(
            new Format("DORAMIFP2T", "200 mg, tab. [fr:200 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMISP", "MISOPROSTOL [fr:MISOPROSTOL]").withFormats(
            new Format("DORAMISP2T", "200 µg, tab. [fr:200 µg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAMORP", "MORPHINE sulfate [fr:MORPHINE sulfate]").withFormats(
            new Format("DORAMORP1S", "10 mg / 5 ml, oral sol., 100 ml, bot. [fr:10 mg / 5 ml, sol. orale, 100 ml, fl.]", Unit.ML),
            new Format("DORAMORP1T", "10 mg, immediate release breakable tab. [fr:10 mg, comp. sécable libération immédiate]", Unit.TABLET),
            new Format("DORAMORP1TS", "10 mg, prolonged-release tab. [fr:10 mg, comp. libération prolongée]", Unit.TABLET)
        ),
        new Drug("DORANEVI", "NEVIRAPINE (NVP) [fr:NEVIRAPINE (NVP)]").withFormats(
            new Format("DORANEVI1S1", "50 mg / 5 ml, oral susp., 100 ml, bot. [fr:50 mg / 5 ml, susp. orale, 100 ml, fl.]", Unit.ML)
        ),
        new Drug("DORANIFE", "NIFEDIPINE [fr:NIFEDIPINE]").withFormats(
            new Format("DORANIFE1TI", "10 mg, immediate release tab. [fr:10 mg, comp. lib. immédiate]", Unit.TABLET)
        ),
        new Drug("DORANYST", "NYSTATIN [fr:NYSTATINE]").withFormats(
            new Format("DORANYST1S", "100.000 IU / ml, oral susp. [fr:100.000 UI / ml, susp. orale]", Unit.MG)
        ),
        new Drug("DORAOMEP", "OMEPRAZOLE [fr:OMEPRAZOLE]").withFormats(
            new Format("DORAOMEP2CG", "20 mg, gastro-resistant caps. [fr:20 mg, gél. gastrorésistante]", Unit.CAPSULE)
        ),
        new Drug("DORAONDA", "ONDANSETRON hydrochloride [fr:ONDANSETRON chlorhydrate]").withFormats(
            new Format("DORAONDA4T", "eq. 4 mg base, tab. [fr:éq. 4 mg base, comp.]", Unit.TABLET),
            new Format("DORAONDA8T", "eq. 8 mg base, tab. [fr:éq. 8 mg base, comp]", Unit.TABLET)
        ),
        new Drug("DORAORMA", "RESOMAL [fr:RESOMAL]").withFormats(
            new Format("DORAORMA2S8", "rehydration acute complic. malnut., sach. 84 g / 2 l [fr:réhydratation malnut. aiguë compliq, sach. 84 g / 2 l]", Unit.ML)
        ),
        new Drug("DORAORSA", "ORAL REHYDRATION SALTS (ORS) low osmol. [fr:SELS REHYDRATATION ORALE (SRO) basse osmol.]").withFormats(
            new Format("DORAORSA2S", "sachet 20.5 g / 1 l [fr:sachet 20.5 g / 1 l]", Unit.ML)
        ),
        new Drug("DORAPARA", "PARACETAMOL (acetaminophen) [fr:PARACETAMOL (acétaminophène)]").withFormats(
            new Format("DORAPARA1S2", "120 mg / 5 ml, oral susp., 100 ml bot. [fr:120 mg / 5 ml, susp. orale, 100 ml fl.]", Unit.ML),
            new Format("DORAPARA1T", "100 mg, tab. [fr:100 mg, comp.]", Unit.TABLET),
            new Format("DORAPARA5T", "500 mg, tab. [fr:500 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAPHYT", "PHYTOMENADIONE (vitamin K1) [fr:PHYTOMENADIONE (vitamine K1)]").withFormats(
            new Format("DORAPHYT1A1", "10 mg / ml, 1 ml, amp. [fr:10 mg / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DORAPOTC", "POTASSIUM chloride [fr:POTASSIUM chlorure]").withFormats(
            new Format("DORAPOTC6TP", "600 mg (8mEq), prolonged-release tab. [fr:600 mg (8mEq), comp. libération prolongée]", Unit.TABLET),
            new Format("DORAPOTC1S", "100 mg / ml (1.33mEq / ml), oral sol., 500 ml, bot. [fr:100 mg / ml (1.33mEq / ml), sol. orale, 500 ml, fl.]", Unit.ML)
        ),
        new Drug("DORAPRAZ", "PRAZIQUANTEL [fr:PRAZIQUANTEL]").withFormats(
            new Format("DORAPRAZ6TB", "600 mg, break. tab. [fr:600 mg, comp. séc.]", Unit.TABLET)
        ),
        new Drug("DORAPRED", "PREDNISOLONE [fr:PREDNISOLONE]").withFormats(
            new Format("DORAPRED5T", "5 mg, tab. [fr:5 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORAPROM", "PROMETHAZINE hydrochloride [fr:PROMETHAZINE chlorhydrate]").withFormats(
            new Format("DORAPROM2T", "eq. 25 mg base, tab. [fr:éq. 25 mg base, comp.]", Unit.TABLET)
        ),
        new Drug("DORARETI", "RETINOL (vitamin A) stabil. [fr:RETINOL (vitamine A) stabilisé]").withFormats(
            new Format("DORARETI2C", "200.000 IU, soft gelat. caps. [fr:200.000 UI, caps. molle]", Unit.CAPSULE)
        ),
        new Drug("DORASALB", "SALBUTAMOL [fr:SALBUTAMOL]").withFormats(
            new Format("DORASALB1N", "solution for nebulizer, 2 mg / ml, 2.5 ml monodose [fr:solution pour nébuliseur, 2 mg / ml, 2.5 ml unidose]", Unit.ML),
            new Format("DORASALB2SF", "sulfate, eq. 0.1 mg base / puff, 200 puffs, aerosol [fr:sulfate, éq. 0.1 mg base / bouffée, 200 bouff. aérosol]", Unit.PUFF)
        ),
        new Drug("DORATELA", "TDF / 3TC [fr:TDF / 3TC]").withFormats(
            new Format("DORATELA1T", "300 mg / 300 mg, tab. [fr:300 mg / 300 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORATELD", "TDF / 3TC / DTG [fr:TDF / 3TC / DTG]").withFormats(
            new Format("DORATELD1T", "300 mg / 300 mg / 50 mg, tab. [fr:300 mg / 300 mg / 50 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORATHIA", "THIAMINE hydrochloride (vitamin B1) [fr:THIAMINE chlorhydrate (vitamine B1)]").withFormats(
            new Format("DORATHIA5T", "50 mg, tab. [fr:50 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORATINI", "TINIDAZOLE [fr:TINIDAZOLE]").withFormats(
            new Format("DORATINI5T", "500 mg, tab. [fr:500 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORATRAM", "TRAMADOL hydrochloride [fr:TRAMADOL chlorhydrate]").withFormats(
            new Format("DORATRAM1S", "100 mg / ml / 40 drops, 10 ml, bot. [fr:100 mg / ml / 40 gouttes, 10 ml, fl.]", Unit.ML),
            new Format("DORATRAM5C", "50 mg, caps. [fr:50 mg, gél.]", Unit.CAPSULE)
        ),
        new Drug("DORAYINS", "ZINC sulfate [fr:ZINC sulfate]").withFormats(
            new Format("DORAYINS2T", "eq. to 20 mg zinc mineral, dispersible tab. [fr:éq. à 20 mg de zinc minéral, comp. dispers.]", Unit.TABLET)
        ),
        new Drug("NFOSRUSF", "READY TO USE SUPPLEMENTARY FOOD [fr:ALIMENT SUPPL. PRET A L'EMPLOI]").withFormats(
            new Format("NFOSRUSFPEP10", "peanut paste, 100 g [fr:pâte d'arachide, 100 g]", Unit.SACHET)
        ),
        new Drug("NFOSRUTF", "RUTF [fr:RUTF]").withFormats(
            new Format("NFOSRUTFCEB51", "(BP100), cereal biscuit, 510 g (= 9 barres) [fr:(BP100), biscuit céréales, 510 g (= 9 barres)]", Unit.SACHET),
            new Format("NFOSRUTFPEP92", "peanut paste, 92 g [fr:pâte d'arachide, 92 g]", Unit.SACHET)
        ),
        new Drug("NFOSTHMI", "THERAPEUTIC MILK [fr:LAIT THERAPEUTIQUE]").withFormats(
            new Format("NFOSTHMIF1O40", "F100, powder, 400 g [fr:F100, poudre, 400 g]", Unit.SACHET),
            new Format("NFOSTHMIF7O40", "F75, powder, 400 g [fr:F75, poudre, 400 g]", Unit.SACHET)
        ),
        new Drug("DORAASPY", "AS [fr:AS]").withFormats(
            new Format("DORAASPY2G", "20 mg / PYRONARIDINE 60 mg, granules, sachet [fr:20 mg / PYRONARIDINE 60 mg, granulés, sachet]", Unit.MG),
            new Format("DORAASPY6T", "60 mg / PYRONARIDINE 180 mg, tab. [fr:60 mg / PYRONARIDINE 180 mg, comp.]", Unit.TABLET)
        ),
        new Drug("DORADARR", "DRV eq. 400 mg base / r 50 mg [fr:DRV éq. 400 mg base / r 50 mg]").withFormats(
            new Format("DORADARR4T", "tab. [fr:comp.]", Unit.TABLET)
        ),
        new Drug("DORALEVE", "LEVETIRACETAM [fr:LEVETIRACETAM]").withFormats(
            new Format("DORALEVE2T", "250 mg, tab. [fr:250 mg, comp.]", Unit.TABLET)
        )
    );

    Category INJECTABLE = new Category("DINJ", "injectable", false, IV, SC, IM, IO).withDrugs(
        new Drug("DINJATRO", "ATROPINE sulfate [fr:ATROPINE sulfate]").withFormats(
            new Format("DINJATRO1A", "1 mg / ml, 1 ml, amp. [fr:1 mg / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJCAFC", "CAFFEINE CITRATE [fr:CITRATE DE CAFEINE]").withFormats(
            new Format("DINJCAFC1A", "10 mg / ml, eq. 5 mg caffeine base, 1 ml, amp. [fr:10 mg / ml, éq. 5 mg caféine base, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJCALG", "CALCIUM GLUCONATE [fr:CALCIUM GLUCONATE]").withFormats(
            new Format("DINJCALG1A", "100 mg / ml, 10 ml, amp. [fr:100 mg / ml, 10 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJCEFT", "CEFTRIAXONE sodium [fr:CEFTRIAXONE sodique]").withFormats(
            new Format("DINJCEFT1V", "eq. 1 g base, powder, vial [fr:éq. 1 g base, poudre, fl.]", Unit.MG)
        ),
        new Drug("DINJCIPR", "CIPROFLOXACIN salt [fr:sel de CIPROFLOXACINE]").withFormats(
            new Format("DINJCIPR2FBF", "eq. 2 mg / ml base, 100 ml, flex. bag PVC free [fr:éq. 2 mg / ml base, 100 ml, poche sple ssPVC]", Unit.ML)
        ),
        new Drug("DINJCLOX", "CLOXACILLIN sodium [fr:CLOXACILLINE sodique]").withFormats(
            new Format("DINJCLOX5VV", "eq. 500 mg base, powder, vial IV [fr:éq. 500 mg base, poudre, fl. IV]", Unit.MG)
        ),
        new Drug("DINJDEXA", "DEXAMETHASONE phosphate [fr:DEXAMETHASONE phosphate]").withFormats(
            new Format("DINJDEXA4A", "4 mg / ml, 1 ml, amp. [fr:4 mg / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJDIAZ", "DIAZEPAM [fr:DIAZEPAM]").withFormats(
            new Format("DINJDIAZ1A", "5 mg / ml, 2 ml, amp. [fr:5 mg / ml, 2 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJDOPA", "DOPAMINE hydrochloride [fr:DOPAMINE chlorhydrate]").withFormats(
            new Format("DINJDOPA2A", "40 mg / ml, 5 ml, amp. [fr:40 mg / ml, 5 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJEPIN", "EPINEPHRINE (adrenaline) tartrate [fr:EPINEPHRINE (adrenaline) tartrate]").withFormats(
            new Format("DINJEPIN1AM", "eq. 1 mg / ml base, 1 ml amp IM [fr:éq. 1 mg / ml base, 1 ml amp IM]", Unit.ML),
            new Format("DINJEPIN1AV", "eq. 1 mg / ml base, 1 ml amp IV [fr:éq. 1 mg / ml base, 1 ml amp IV]", Unit.ML)
        ),
        new Drug("DINJFLUC", "FLUCONAZOLE [fr:FLUCONAZOLE]").withFormats(
            new Format("DINJFLUC2FBF", "2 mg / ml, 100 ml, flexible bag PVC free [fr:2 mg / ml, 100 ml, poche souple sans PVC]", Unit.ML)
        ),
        new Drug("DINJFLUM", "FLUMAZENIL [fr:FLUMAZENIL]").withFormats(
            new Format("DINJFLUM1A", "0.1 mg / ml, 10 ml, amp. [fr:0.1 mg / 1 ml, 10 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJFURO", "FUROSEMIDE [fr:FUROSEMIDE]").withFormats(
            new Format("DINJFURO2A", "10 mg / ml, 2 ml, amp. [fr:10 mg / ml, 2 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJGENT", "GENTAMICIN sulfate [fr:GENTAMICINE sulfate]").withFormats(
            new Format("DINJGENT8A", "eq. 40 mg / ml base, 2 ml, amp. [fr:eq. 40 mg / ml base, 2 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJGLUC", "GLUCOSE hypertonic [fr:GLUCOSE hypertonique]").withFormats(
            new Format("DINJGLUC1A1", "10%, 10 ml, amp [fr:10%, 10 ml, amp]", Unit.ML),
            new Format("DINJGLUC5V5", "50%, 50 ml, vial [fr:50%, 50 ml, fl.]", Unit.ML)
        ),
        new Drug("DINJHALP", "HALOPERIDOL [fr:HALOPERIDOL]").withFormats(
            new Format("DINJHALP5A", "5 mg / ml, 1 ml, amp. [fr:5 mg / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJHYDR", "HYDROCORTISONE sodium succinate [fr:HYDROCORTISONE succinate sodique]").withFormats(
            new Format("DINJHYDR1V", "eq. 100 mg base, powder, vial [fr:eq. 100 mg base, poudre, fl]", Unit.MG)
        ),
        new Drug("DINJHYOS", "HYOSCINE BUTYLBROMIDE (scopolamine butylbrom) [fr:BUTYLBROMURE HYOSCINE (butylbrom. scopolamine)]").withFormats(
            new Format("DINJHYOS2A", "20 mg / 1 ml, amp [fr:20 mg / 1 ml, amp]", Unit.ML)
        ),
        new Drug("DINJINSH", "INSULIN HUMAN [fr:INSULINE HUMAINE]").withFormats(
            new Format("DINJINSHB1VN", "BIPHASIC 30-70 IU / ml, 10 ml, vial N [fr:BIPHASIQUE 30-70 UI / ml, 10 ml, fl. N]", Unit.ML),
            new Format("DINJINSHI1VN", "ISOPHANE (NPH) 100 UI / ml, 10 ml, vial N [fr:ISOPHANE (NPH) 100 UI / ml, 10 ml, fl. N]", Unit.ML),
            new Format("DINJINSHR1VN", "RAPID 100 IU / ml, 10 ml, vial N [fr:RAPIDE 100 UI / ml, 10 ml, fl. N]", Unit.ML)
        ),
        new Drug("DINJKETA", "KETAMINE hydrochloride [fr:KETAMINE chlorhydrate]").withFormats(
            new Format("DINJKETA2A", "eq. 50 mg / ml base, 5 ml, amp. [fr:éq. 50 mg / ml base, 5 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJLABE", "LABETALOL hydrochloride [fr:LABETALOL chlorhydrate]").withFormats(
            new Format("DINJLABE1A", "5 mg / ml, 20 ml amp. [fr:5 mg / ml, 20 ml amp.]", Unit.ML)
        ),
        new Drug("DINJLEVE", "LEVETIRACETAM [fr:LEVETIRACETAM]").withFormats(
            new Format("DINJLEVE5V", "100 mg / ml, 5 ml, vial [fr:100 mg / ml, 5 ml, fl.]", Unit.ML)
        ),
        new Drug("DINJLEVN", "LEVONORGESTREL implant [fr:LEVONORGESTREL implant]").withFormats(
            new Format("DINJLEVN15I", "2 x 75 mg (Jadelle) + trocar [fr:2 x 75 mg (Jadelle) + trocart]", Unit.MG)
        ),
        new Drug("DINJLIDO", "LIDOCAINE hydrochloride [fr:LIDOCAINE chlorhydrate]").withFormats(
            new Format("DINJLIDO1A1", "1%, preservative-free, 10 ml, amp [fr:1%, sans conservateur, 10 ml, amp]", Unit.ML)
        ),
        new Drug("DINJMAGS", "MAGNESIUM sulfate [fr:MAGNESIUM sulfate]").withFormats(
            new Format("DINJMAGS5A", "0.5 g / ml, 10 ml, amp. [fr:0.5 g / ml, 10 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJMEDR", "MEDROXYPROGESTERONE acetate [fr:MEDROXYPROGESTERONE acétate]").withFormats(
            new Format("DINJMEDR1V", "150 mg, 1 ml, vial [fr:150 mg, 1 ml, fl.]", Unit.ML)
        ),
        new Drug("DINJMERG", "METHYLERGOMETRINE maleate [fr:METHYLERGOMETRINE maleate]").withFormats(
            new Format("DINJMERG2A", "0.2 mg / ml, 1 ml, amp. [fr:0.2 mg / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJMETN", "METRONIDAZOLE [fr:METRONIDAZOLE]").withFormats(
            new Format("DINJMETN5FBF", "5 mg / ml, 100 ml, flex. bag PVC free [fr:5 mg / ml, 100 ml, poche souple sans PVC]", Unit.ML)
        ),
        new Drug("DINJMETO", "METOCLOPRAMIDE hydrochloride [fr:METOCLOPRAMIDE chlorhydrate]").withFormats(
            new Format("DINJMETO1A", "5 mg / ml, 2 ml, amp. [fr:5 mg / ml, 2 ml, amp]", Unit.ML)
        ),
        new Drug("DINJMIDA", "MIDAZOLAM [fr:MIDAZOLAM]").withFormats(
            new Format("DINJMIDA5A", "1 mg / ml, 5 ml, amp [fr:1 mg / ml, 5 ml, amp]", Unit.ML)
        ),
        new Drug("DINJMORP", "MORPHINE hydrochloride [fr:MORPHINE chlorhydrate]").withFormats(
            new Format("DINJMORP1A", "10 mg / ml, 1 ml, amp. [fr:10 mg / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJNALO", "NALOXONE hydrochloride [fr:NALOXONE chlorhydrate]").withFormats(
            new Format("DINJNALO4A", "0.4 mg / ml, 1 ml, amp. [fr:0.4 mg / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJNEPI", "NOREPINEPHRINE (noradrenaline) tartrate [fr:NOREPINEPHRINE (noradrénaline) tartrate]").withFormats(
            new Format("DINJNEPI4AV", "eq. 1 mg / ml base, 4 ml [fr:éq. 1 mg / ml base, 4 ml]", Unit.ML)
        ),
        new Drug("DINJNICA", "NICARDIPINE hydrochloride [fr:NICARDIPINE chlorhydrate]").withFormats(
            new Format("DINJNICA1A", "1 mg / ml, 10 ml, amp. [fr:1 mg / ml, 10 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJOMEP", "OMEPRAZOLE sodium [fr:OMEPRAZOLE sodique]").withFormats(
            new Format("DINJOMEP4V", "eq. 40 mg base, powder, vial, fr infusion [fr:éq. 40 mg base, poudre, fl. pr perfusion]", Unit.MG)
        ),
        new Drug("DINJONDA", "ONDANSETRON hydrochloride [fr:ONDANSETRON chlorhydrate]").withFormats(
            new Format("DINJONDA4A", "eq. 2 mg / ml base, 2 ml, amp. [fr:éq. 2 mg / ml base, 2 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJOXYT", "OXYTOCIN [fr:OXYTOCINE]").withFormats(
            new Format("DINJOXYT1A", "10 IU / ml, 1 ml, amp. [fr:10 UI / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJPARA", "PARACETAMOL (acetaminophen) [fr:PARACETAMOL (acétaminophène)]").withFormats(
            new Format("DINJPARA1B", "10 mg / ml, 100 ml, bot. [fr:10 mg / ml, 100 ml, fl.]", Unit.ML),
            new Format("DINJPARA1FBF", "10 mg / ml, 100 ml, flex. bag PVC free [fr:10 mg / ml, 100 ml, poche s. ss PVC]", Unit.ML),
            new Format("DINJPARA5B", "10 mg / ml, 50 ml, bot. [fr:10 mg / ml, 50 ml, fl.]", Unit.ML),
            new Format("DINJPARA5FBF", "10 mg / ml, 50 ml, flex. bag PVC free [fr:10 mg / ml, 50 ml, poche s. ss PVC]", Unit.ML)
        ),
        new Drug("DINJPHEN", "PHENOBARBITAL sodium [fr:PHENOBARBITAL sodique]").withFormats(
            new Format("DINJPHEN2A1", "200 mg / ml, 1 ml, amp. [fr:200 mg / ml, 1 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJPHEY", "PHENYTOIN sodium [fr:PHENYTOINE sodique]").withFormats(
            new Format("DINJPHEY2A", "50 mg / ml, 5 ml, amp. [fr:50 mg / ml, 5 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJPHYT", "PHYTOMENADIONE (vitamin K1) [fr:PHYTOMENADIONE (vitamine K1)]").withFormats(
            new Format("DINJPHYT2AN", "10 mg / ml (2 mg / 0.2 ml), 0.2 ml amp. [fr:10 mg / ml (2 mg / 0.2 ml), 0.2 ml amp.]", Unit.ML)
        ),
        new Drug("DINJPROM", "PROMETHAZINE hydrochloride [fr:PROMETHAZINE chlorhydrate]").withFormats(
            new Format("DINJPROM5A", "eq. 25 mg / ml base, 2 ml, amp. [fr:éq. 25 mg / ml base, 2 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJSODB", "SODIUM BICARBONATE [fr:SODIUM BICARBONATE]").withFormats(
            new Format("DINJSODB8A1", "8.4%, 1 mEq / ml, 10 ml, amp. [fr:8.4%, 1 mEq / ml, 10 ml, amp.]", Unit.ML),
            new Format("DINJSODB8A2", "8.4%, 1 mEq / ml, 20 ml, amp. [fr:8.4%, 1 mEq / ml, 20 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJSODC", "SODIUM chloride [fr:SODIUM chlorure]").withFormats(
            new Format("DINJSODC9A5", "0.9%, 5 ml, plastic amp. [fr:0.9%, 5 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJTHIA", "THIAMINE (vitamin B1) [fr:THIAMINE (vitamine B1)]").withFormats(
            new Format("DINJTHIA1A", "50 mg / ml, 2 ml, amp. [fr:50 mg / ml, 2 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJTRAM", "TRAMADOL hydrochloride [fr:TRAMADOL chlorhydrate]").withFormats(
            new Format("DINJTRAM1A", "50 mg / ml, 2 ml, amp. [fr:50 mg / ml, 2 ml, amp.]", Unit.ML)
        ),
        new Drug("DINJTRAN", "TRANEXAMIC ACID [fr:ACIDE TRANEXAMIQUE]").withFormats(
            new Format("DINJTRAN5A", "100 mg / ml, 5 ml amp. [fr:100 mg / ml, 5 ml amp.]", Unit.ML)
        ),
        new Drug("DINJVALP", "VALPROATE SODIUM [fr:VALPROATE DE SODIUM]").withFormats(
            new Format("DINJVALP4A", "100 mg / ml, 4 ml amp. [fr:100 mg / ml, 4 ml amp.]", Unit.ML)
        ),
        new Drug("DINJPOTC", "POTASSIUM chloride [fr:POTASSIUM chlorure]").withFormats(
            new Format("DINJPOTC2A", "2mmol / ml (15% ), 10 ml, amp. [fr:2mmol / ml (15% ), 10 ml, amp.]", Unit.ML)
        )
    );

    Category PERFUSION = new Category("DINF", "perfusion", true).withDrugs(
        new Drug("DINFDERI", "DEXTROSE (GLUCOSE) / RINGER LACTATE [fr:GLUCOSE / RINGER LACTATE]").withFormats(
            new Format("DINFDERI5FBF5", "GLUCOSE 5% + RL, 500 ml, flex. bag, PVC free [fr:GLUCOSE 5% + RL, 500 ml, poche souple, sans PVC]", Unit.ML)
        ),
        new Drug("DINFDEXT", "DEXTROSE (GLUCOSE) [fr:GLUCOSE]").withFormats(
            new Format("DINFDEXT1FBF5", "10%, 500 ml, flex. bag, PVC free [fr:10%, 500 ml, poche souple, sans PVC]", Unit.ML),
            new Format("DINFDEXT5FBF1", "5%, 1 l, flex. bag, PVC free [fr:5%, 1 l, poche souple, sans PVC]", Unit.ML),
            new Format("DINFDEXT5FBF5", "5%, 500 ml, flex. bag, PVC free [fr:5%, 500 ml, poche souple, sans PVC]", Unit.ML)
        ),
        new Drug("DINFSODC", "SODIUM chloride (NaCl) [fr:SODIUM chlorure (NaCl)]").withFormats(
            new Format("DINFSODC9FBF0", "0.9%, 100 ml, flex. bag, PVC free [fr:0.9%, 100 ml, poche souple, sans PVC]", Unit.ML),
            new Format("DINFSODC9FBF1", "0.9%, 1 l, flex. bag, PVC free [fr:0.9%, 1 l, poche souple, sans PVC]", Unit.ML),
            new Format("DINFSODC9SRF5", "0.9%, 500 ml, semi-rigid bot., PVC free [fr:0.9%, 500 ml, fl. semi-rigide, sans PVC]", Unit.ML)
        )
    );

    Category EXTERNAL = new Category("DEXT", "external", false, UNSPECIFIED, OC).withDrugs(
        new Drug("DEXODEXN", "DEXAMETHASONE / NEOMYCIN [fr:DEXAMETHASONE / NEOMYCINE]").withFormats(
            new Format("DEXODEXN5D5", "5 mg / 17500 IU, eye drops, 5 ml, bot [fr:5 mg / 17500 UI, collyre, 5 ml, fl.]", Unit.ML)
        ),
        new Drug("DEXOSODC", "SODIUM CHLORIDE [fr:SERUM PHYSIOLOGIQUE]").withFormats(
            new Format("DEXOSODC9D5", "0.9%, eye drops, sterile, 5 ml [fr:chlorure de sodium 0.9%, stérile, 5 ml]", Unit.ML)
        ),
        new Drug("DEXOTETR", "TETRACYCLINE hydrochloride [fr:TETRACYCLINE chlorhydrate]").withFormats(
            new Format("DEXOTETR1O5", "1%, eye ointment, ster, 5 g, tube [fr:1%, pommade opht., stér, 5 g, tube]", null)
        ),
        new Drug("DEXTBENS", "BENZOIC ACID / SALICYLIC ACID [fr:ACIDE BENZOIQUE / ACIDE SALICYLIQUE]").withFormats(
            new Format("DEXTBENS6O4", "6% / 3%, ointment, 40 g, tube [fr:6% / 3%, pom., 40 g, tube]", Unit.ML)
        ),
        new Drug("DEXTBENZ", "BENZYL BENZOATE [fr:BENZOATE DE BENZYLE]").withFormats(
            new Format("DEXTBENZ2L1", "25%, lotion, 1 l, bot. [fr:25%, lotion, 1 l, fl.]", Unit.ML)
        ),
        new Drug("DEXTCHLH", "CHLORHEXIDINE digluconate [fr:CHLORHEXIDINE digluconate]").withFormats(
            new Format("DEXTCHLH2S", "0.2%, mouthwash, sol., 300 ml, bot. [fr:0.2%, bain de bouche, sol., 300 ml, fl]", Unit.ML),
            new Format("DEXTCHLH7G2", "7.1%, gel, 20 g tube [fr:7.1%, gel, 20 g tube]", Unit.ML)
        ),
        new Drug("DEXTCLOT", "CLOTRIMAZOLE [fr:CLOTRIMAZOLE]").withFormats(
            new Format("DEXTCLOT5T", "500 mg, vaginal tab. + applicator [fr:500 mg, comp. vaginal + applicateur]", Unit.TABLET)
        ),
        new Drug("DEXTFUSI", "FUSIDIC ACID [fr:ACIDE FUSIDIQUE]").withFormats(
            new Format("DEXTFUSI2C3", "2%, cream, 30 g, tube [fr:2%, crème, 30 g, tube]", Unit.ML)
        ),
        new Drug("DEXTMICO", "MICONAZOLE nitrate [fr:MICONAZOLE nitrate]").withFormats(
            new Format("DEXTMICO2C3", "2%, cream, 30 g, tube [fr:2%, crème, 30 g, tube]", Unit.ML)
        ),
        new Drug("DEXTSULZ", "SULFADIAZINE SILVER [fr:SULFADIAZINE ARGENTIQUE]").withFormats(
            new Format("DEXTSULZ1C5", "1%, cream, sterile, 50 g, tube [fr:1%, crème, stérile, 50 g, tube]", Unit.ML)
        ),
        new Drug("DEXTYINO", "ZINC OXIDE [fr:OXYDE DE ZINC]").withFormats(
            new Format("DEXTYINO1O1", "10%, ointment, 100 g, tube [fr:10%, pommade, 100 g, tube]", Unit.ML)
        ),
        new Drug("SMSUCOND", "CONDOM [fr:PRESERVATIF]").withFormats(
            new Format("SMSUCOND1", "lubricated + RESERVOIR, s. u. [fr:MASCULIN, lubrifié + RESERVOIR, u. u.]", Unit.UNSPECIFIED),
            new Format("SMSUCONDF1", "FEMALE, lubricated, 170 mm, s. u. [fr:FEMININ, lubrifié, 170 mm, u. u.]", Unit.UNSPECIFIED)
        ),
        new Drug("SMSUVASE", "VASELINE [fr:VASELINE]").withFormats(
            new Format("SMSUVASE1O", "ointment, 100 g, tube [fr:pommade, 100 g, tube]", Unit.G)
        ),
        new Drug("DEXOOTET", "OXYTETRACYCLINE hydrochloride [fr:OXYTETRACYCLINE chlorhydrate]").withFormats(
            new Format("DEXOOTET5O5", "0.5%, eye ointment, ster., 4-5 g, tube [fr:0.5%, pde opht., stér., 4-5 g, tube]", Unit.ML)
        )
    );

    Category VACCINE = new Category("DVAC", "vaccines/immunoglobulins", false).withDrugs(

    );

    CatalogIndex INDEX = new CatalogIndex(ORAL, INJECTABLE, PERFUSION, EXTERNAL, VACCINE)
        .withRoutes(UNSPECIFIED, PO, IV, SC, IM, IO, OC)
        .withDosageUnits(Unit.TABLET, Unit.CAPSULE, Unit.G, Unit.MG, Unit.MCG, Unit.L, Unit.ML, Unit.IU, Unit.DROP, Unit.PUFF, Unit.AMPOULE, Unit.SACHET, Unit.OVULE, Unit.SUPP);

    // ==== END GENERATED OUTPUT ====
}
