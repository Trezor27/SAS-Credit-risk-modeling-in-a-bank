/* Adapted from Credit_Risk_Modeling.sas (lines 1-39): the account/card/client
   recoding steps. Original reads from `libname Kredyt '/home/u63619495/Kredyt'`
   (the Berka Czech-bank dataset tables); here the same three tables are
   supplied as small inline DATA steps with the same column shapes so the
   author's recode logic runs unmodified. */

data account;
  input account_id 1-2 district_id 4-5 frequency $ 7-25 date 27-32;
  datalines;
1  18 POPLATEK MESICNE    930101
2  1  POPLATEK TYDNE      930101
3  5  POPLATEK PO OBRATU  930101
4  12 POPLATEK MESICNE    930102
5  15 POPLATEK MESICNE    930103
;
run;

data account;
  set account (rename=(date = account_creation_date));
  if frequency = "POPLATEK MESICNE" then frequency = "miesieczna";
  else if frequency = "POPLATEK TYDNE" then frequency = "tygodniowa";
  else if frequency = "POPLATEK PO OBRATU" then frequency = "po_transakcji";
  account_peroid = put(account_creation_date, 6.) - 12054;
run;

data card;
  input disp_id type $ issued;
  datalines;
1 gold 960221
2 classic 970419
3 junior 950830
4 classic 960715
5 gold 981102
;
run;

data card;
  set card (rename=(type = card_type));
  issued_date = input(put(issued, 6.), yymmdd6.);
  card_ownership_duration = issued_date - '07NOV1993'd;
  format card_ownership_duration 8.;
run;

data client;
  format plec $9.;
  informat plec $9.;
  input client_id district_id birth_number;
  birth_year = input(substr(put(birth_number, 6.), 1, 2), 2.) + 1900;
  birth_day = input(substr(put(birth_number, 6.), 5, 2), 2.);
  rr = int(birth_number / 10000);
  mmdd = birth_number - (rr * 10000);
  mm = int(mmdd / 100);
  dd = mmdd - (mm * 100);
  if mm > 50 then do;
    plec = "kobieta";
    birth_month = input(substr(put(birth_number-5000, 6.), 3, 2), 2.);
  end;
  if mm <= 50 then do;
    plec = "mezczyzna";
    birth_month = input(substr(put(birth_number, 6.), 3, 2), 2.);
  end;
  drop mm dd rr mmdd;
  birth_date = mdy(birth_month, birth_day, birth_year);
  client_birth_date = put(birth_date, YYMMDD10.);
  drop birth_date birth_year birth_day birth_month;
  datalines;
1 18 706213
2 1 456028
3 5 855128
4 12 590812
5 15 725617
;
run;

proc print data=account; run;
proc print data=card; run;
proc print data=client; run;
