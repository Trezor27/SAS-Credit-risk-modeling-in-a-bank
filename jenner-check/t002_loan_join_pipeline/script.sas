/* Adapted from Credit_Risk_Modeling.sas (lines 1-139): the account/client
   recode steps feeding the PROC SQL join chain (aa -> aac -> aacc -> aaccs)
   and the "balance at loan date" lookback logic. The original reads all
   seven Berka tables from `libname Kredyt '/home/u63619495/Kredyt'`; here
   account, disp, district, client, loan and trans are supplied as small
   inline DATA steps with the same column shapes/keys so the author's own
   joins, renames and staz/wiek date-math run unmodified. */

data account;
  input account_id 1-2 district_id 4-5 frequency $ 7-25 date 27-32;
  datalines;
1  18 POPLATEK MESICNE    930101
2  1  POPLATEK TYDNE      930215
3  5  POPLATEK PO OBRATU  930310
;
run;

data account;
  set account (rename=(date = account_creation_date));
  if frequency = "POPLATEK MESICNE" then frequency = "miesieczna";
  else if frequency = "POPLATEK TYDNE" then frequency = "tygodniowa";
  else if frequency = "POPLATEK PO OBRATU" then frequency = "po_transakcji";
  account_peroid = put(account_creation_date, 6.) - 12054;
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
3 5 590812
;
run;

data disp;
  input disp_id account_id client_id type $;
  datalines;
1 1 1 OWNER
2 2 2 OWNER
3 3 3 OWNER
;
run;

data district;
  input A1 A4 A11 A12 A13 A14 A15 A16;
  datalines;
18 95000 8500 0.05 0.06 1200 1000 1100
1  120000 9200 0.03 0.04 2500 800 900
5  70000 7800 0.07 0.08 600 1500 1600
;
run;

data loan;
  input account_id loan_id amount duration date status $;
  drop amount;
  if status in ('A', 'C') then default = 0;
  if status in ('B', 'D') then default = 1;
  rename amount=loan_amount duration=loan_duration date=loan_date;
  datalines;
1 101 96000 24 930601 A
2 102 165960 36 930715 B
3 103 20016 12 930801 C
;
run;

data trans;
  format operation k_symbol $30.;
  informat operation k_symbol $30.;
  format type $9.;
  informat type $9.;
  input account_id trans_id date type $ operation & $30. k_symbol $ amount balance bank $ account;
  if operation = 'VYBER KARTOU' then operation = 'wyplata karta kredytowa';
  else if operation = 'VKLAD' then operation = 'kredyt gotowkowy';
  else if operation = 'PREVOD Z UCTU' then operation = 'przelew z innego banku';
  else if operation = 'VYBER' then operation = 'wyplata gotówki';
  else if operation = 'PREVOD NA UCET' then operation = 'przelew na inne konto';
  if k_symbol = 'POJISTNE' then k_symbol = 'oplata ubezpieczenia';
  else if k_symbol = 'SLUZBY' then k_symbol = 'Platnosc za wyciag';
  else if k_symbol = 'UROK' then k_symbol = 'Naliczone odsetki';
  else if k_symbol = 'SANKC. UROK' then k_symbol = 'Oprocentowanie karne';
  else if k_symbol = 'SIPO' then k_symbol = 'Gospodarstwo domowe';
  else if k_symbol = 'DUCHOD' then k_symbol = 'Emerytura';
  else if k_symbol = 'UVER' then k_symbol = 'Splata kredytu';
  if type = 'PRIJEM' then type = 'przychod';
  if type = 'VYBER' then type = 'wyplata';
  else if type = 'VYDAJ' then type = 'wyplata';
  datalines;
1 9001 930401 PRIJEM VKLAD  POJISTNE 1000 5000 AB 11111111
1 9002 930515 VYBER VYBER  SIPO 500 4500 AB 11111111
1 9003 930601 PRIJEM PREVOD Z UCTU  UVER 2000 6500 AB 11111111
2 9004 930601 PRIJEM VKLAD  POJISTNE 3000 9000 CD 22222222
2 9005 930701 VYBER VYBER KARTOU  SLUZBY 700 8300 CD 22222222
2 9006 930715 PRIJEM PREVOD Z UCTU  UVER 1500 9800 CD 22222222
3 9007 930701 PRIJEM VKLAD  POJISTNE 800 3800 EF 33333333
3 9008 930715 VYBER VYBER  SIPO 300 3500 EF 33333333
3 9009 930801 PRIJEM PREVOD Z UCTU  UVER 600 4100 EF 33333333
;
run;

proc sql;
create table aa as
select * from loan as l left join
(select * from account as a left join disp as d
on a.account_id = d.account_id where type = "OWNER")
as ac on l.account_id = ac.account_id;
alter table aa
drop type;
quit;
proc sql;
create table aac as
select * from aa as a left join
(select * from client as cl left join district as d
on cl.district_id = d.A1)
as c on a.client_id = c.client_id;
quit;
data aaccs;
  set aac;
  client_birth_date_num = input(client_birth_date, yymmdd10.);
  staz = (loan_date - account_creation_date) /365.25;
  wiek = (loan_date - client_birth_date_num)/365.25;
run;
proc sort data= aaccs;
by account_id;
run;

proc print data=aaccs; run;
