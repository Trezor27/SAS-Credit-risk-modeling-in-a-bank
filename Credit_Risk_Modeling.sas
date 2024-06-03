libname Kredyt '/home/u63619495/Kredyt';
data account; 
  set Kredyt.account (rename=(date = account_creation_date));
  if frequency = "POPLATEK MESICNE" then frequency = "miesieczna";
  else if frequency = "POPLATEK TYDNE" then frequency = "tygodniowa";
  else if frequency = "POPLATEK PO OBRATU" then frequency = "po_transakcji";
  account_peroid = put(account_creation_date, 6.) - 12054;
run;

data card;
  set Kredyt.card (rename=(type = card_type));
  issued_date = input(put(issued, 6.), yymmdd6.);
  card_ownership_duration = issued_date - '07NOV1993'd;
  format card_ownership_duration 8.;
run;

data client;
  format plec $9.;
  informat plec $9.;
  set Kredyt.client;  
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
run;

data disp;
  set Kredyt.disp;
run;
data district;
  set Kredyt.district;
run;

data loan;
  set Kredyt.loan(rename=(amount=loan_amount duration=loan_duration date = loan_date));
  drop amount;
  if status in ('A', 'C') then default = 0;
  if status in ('B', 'D') then default = 1;
run;
data order;
  format operation k_symbol $24.;
  informat operation k_symbol $24.;
  set Kredyt.order;
  if k_symbol = 'POJISTNE' then k_symbol = 'skladka_ubezpieczenia';
  else if k_symbol = 'SIPO' then k_symbol = 'rachunki_domowe';
  else if k_symbol = 'LEASING' then k_symbol = 'leasing';
  else if k_symbol = 'UVER' then k_symbol = 'rata_kredytu';
run;
data trans;
  format operation k_symbol $30.;
  informat operation k_symbol $30.;
  format type $9.;
  informat type $9.;
  set Kredyt.trans;
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
proc sql;
create table aacc as 
select * from aac as a left join 
card as c 
on a.disp_id = c.disp_id;
quit;
data aaccs;
  set aacc;
  client_birth_date_num = input(client_birth_date, yymmdd10.);
  staz = (loan_date - account_creation_date) /365.25;
  wiek = (loan_date - client_birth_date_num)/365.25;
run;
proc sort data= aaccs;
by account_id;
run;
proc sort data= trans;
by account_id;
run;
data aaccsttt;
merge aaccs (in=a) 
trans (in=b);
by account_id;
if a=1 and b=1;
drop account bank k_symbol amount operation type trans_id;
run;
proc sort data = aaccsttt;
by descending loan_id descending date;
run;
/* saldo na dany dzień zaciągnięcia kredytu*/
data aaccstt0;
set aaccsttt (rename=(balance = saldo_przy_kredycie)); 
if loan_date > date then output;
run;
data aaccstt0;
set aaccstt0;
by descending loan_id descending date;
if first.loan_id then output;
run;
/* ----------------------------- */
proc sort data= trans;
by account_id;
run;
proc sort data= aaccstt0;
by account_id;
run;
data aaccsttt;
merge aaccstt0 (in=a) 
trans (in=b);
by account_id;
if a=1 and b=1;
drop account bank k_symbol amount operation type trans_id;
run;
proc sort data = aaccsttt;
by descending loan_id descending date;
run;
/* saldo na miesiac przed zaciagnieciem kredytu*/
data aaccstt1;
set aaccsttt (rename=(balance = saldo_1msc_przed_kredytem)); 
if (loan_date -30) > date then output;
run;
data aaccstt1;
set aaccstt1;
by descending loan_id descending date;
if first.loan_id then output;
run;
/* ----------------------------- */
proc sort data= trans;
by account_id;
run;
proc sort data= aaccstt1;
by account_id;
run;
data aaccsttt;
merge aaccstt1 (in=a) 
trans (in=b);
by account_id;
if a=1 and b=1;
drop account bank k_symbol amount operation type trans_id;
run;
proc sort data = aaccsttt;
by descending loan_id descending date;
run;
/* saldo na dwa miesiace przed zaciagnieciem kredytu*/
data aaccstt2;
set aaccsttt (rename=(balance = saldo_2msc_przed_kredytem)); 
if (loan_date -60) > date then output;
run;
data aaccstt2;
set aaccstt2;
by descending loan_id descending date;
if first.loan_id then output;
run;
/* ----------------------------- */
proc sort data= trans;
by account_id;
run;
proc sort data= aaccstt2;
by account_id;
run;
data aaccsttt;
merge aaccstt2 (in=a) 
trans (in=b);
by account_id;
if a=1 and b=1;
drop account bank k_symbol amount operation type trans_id;
run;
proc sort data = aaccsttt;
by descending loan_id descending date;
run;
/* saldo na trzy miesiace przed zaciagnieciem kredytu*/
data aaccstt3;
set aaccsttt (rename=(balance = saldo_3msc_przed_kredytem)); 
if (loan_date -90) > date then output;
run;
data aaccstt3;
set aaccstt3;
by descending loan_id descending date;
if first.loan_id then output;
run;
/* ----------------------------- */
 

data aaccsttt;
set aaccstt3;
if saldo_przy_kredycie < 0 then dlug_na_koncie = "tak";
else if saldo_przy_kredycie > 0 then dlug_na_koncie = "nie";
run;
 
proc sql;
/* Suma kwot przelewów i liczba przelewów dla każdego konta */
create table transfers as
select account_id, sum(amount) as overall_sum_of_transfers, count(*) as number_of_transfers from 
order group by account_id order by account_id;
quit;
 
data transfer1;
set transfers;
avg_transfer = overall_sum_of_transfers / number_of_transfers;
drop number_of_transfers;
run;
 
 
proc sql; /* Srednia kwot przelewow dla kazdego konta i kategorii */
create table transfer2 as
select account_id, 
         coalesce(sum(case when k_symbol = 'skladka_ubezpieczenia' then amount else 0 end) / count(case when k_symbol = 'skladka_ubezpieczenia' then 1 end), 0) as avg_skladka_ubezpieczenia,
         coalesce(sum(case when k_symbol = 'rachunki_domowe' then amount else 0 end) / count(case when k_symbol = 'rachunki_domowe' then 1 end), 0) as avg_rachunki_domowe,
         coalesce(sum(case when k_symbol = 'leasing' then amount else 0 end) / count(case when k_symbol = 'leasing' then 1 end), 0) as avg_leasing,
         coalesce(sum(case when k_symbol = 'rata_kredytu' then amount else 0 end) / count(case when k_symbol = 'rata_kredytu' then 1 end), 0) as avg_rata_kredytu
from order 
group by account_id 
order by account_id;
quit;

 
proc sql;
create table transfers as 
select * from transfer1 as a left join 
transfer2 as c 
on a.account_id = c.account_id;
quit;
 
 
proc sql; /*dodane kwoty przelewów do głównej tabeli*/
create table aaccstttt as 
select * from aaccsttt as a left join 
transfers as c 
on a.account_id = c.account_id;
quit;

/*most k_symbol (characterisation of tansaction) and which one it is*/
proc sql;  
   create table ksymbolee as
   select account_id, k_symbol, count(*) as transaction_count
   from Kredyt.order
   group by account_id, k_symbol
   order by transaction_count desc;
quit;
proc sort data = ksymbolee;
by account_id;
run;
data ksymbolee1;
set ksymbolee;
by account_id;
if first.account_id;
drop transaction_count;
run;
data ksymbolee2;
set ksymbolee1 (rename=(k_symbol = najczestsza_kategoria));
run;
proc sql;
create table aaccsttttk as 
select * from aaccstttt as a left join 
ksymbolee2 as c 
on a.account_id = c.account_id;
quit;
/* ------------------------------------------------------------------ */

/*most transaction to bank and which one it is*/
proc sql;  
   create table banks2 as
   select account_id, bank_to, count(*) as transaction_count
   from Kredyt.order
   group by account_id, bank_to
   order by transaction_count desc;
quit;
proc sort data = banks2;
by account_id;
run;
data banks3;
set banks2;
by account_id;
if first.account_id;
drop transaction_count;
run;
data bank4;
set banks3 (rename=(bank_to = most_bank_transfers_to));
run;
proc sql;
create table aaccsttttkb as 
select * from aaccsttttk as a left join 
bank4 as c 
on a.account_id = c.account_id;
quit;
/* ---------------------------------- */
data aaccsttttkbc;
set aaccsttttkb (rename=(A11 = sr_wyplata_region A15 = cirmes95 
A16 = cirmes96 A12 = bezrobocie95 A13 = bezrobocie96 A4 = mieszkancy_regionu
A14 = no_of_enterpreneurs));
if card_ownership_duration = "." then do;
  card_ownership = "nie";
end;
else do;
  card_ownership = "tak";
end;
if card_ownership_duration = "." then do;
  card_ownership_duration = 0;
end;
run;

proc sql; /* Srednia kwot przelewow dla każdego konta i kategorii (w tabeli trans) i przychody, wyplaty*/
create table trans_by_k_symbol as
select account_id, 
  coalesce(sum(case when k_symbol = 'oplata ubezpieczenia' then amount else 0 end) / count(case when k_symbol = 'oplata ubezpieczenia' then 1 end), 0) as avg_ubezpieczenie_p,
  coalesce(sum(case when k_symbol = 'Platnosc za wyciag' then amount else 0 end) / count(case when k_symbol = 'Platnosc za wyciag' then 1 end), 0) as avg_wyciag_p,
  coalesce(sum(case when k_symbol = 'Naliczone odsetki' then amount else 0 end) / count(case when k_symbol = 'Naliczone odsetki' then 1 end), 0) as avg_odsetki_p,
  coalesce(sum(case when k_symbol = 'Oprocentowanie karne' then amount else 0 end) / count(case when k_symbol = 'Oprocentowanie karne' then 1 end), 0) as avg_oprocnetowanie_karne_p,
  coalesce(sum(case when k_symbol = 'Gospodarstwo domowe' then amount else 0 end) / count(case when k_symbol = 'Gospodarstwo domowe' then 1 end), 0) as avg_wyd_dom_p,
  coalesce(sum(case when k_symbol = 'Emerytura' then amount else 0 end) / count(case when k_symbol = 'Emerytura' then 1 end), 0) as avg_emerytura_p,
  coalesce(sum(case when k_symbol = 'Splata kredytu' then amount else 0 end) / count(case when k_symbol = 'Splata kredytu' then 1 end), 0) as avg_splata_kredytu_p,
  coalesce(sum(case when type = 'przychod' then 1 end), 0) as liczba_przychodow,
  coalesce(sum(case when type = 'wyplata' then 1 end), 0) as liczba_wyplat,
  coalesce((sum(case when type = 'wyplata' then 1 end) / sum(case when type = 'przychod' then 1 end)), 0) as wyplaty_do_przychodow
from trans 
group by account_id 
order by account_id;
quit;

proc sql;
create table final as 
select * from aaccsttttkbc as a left join 
trans_by_k_symbol as c 
on a.account_id = c.account_id;
quit;

data Kredyt.final;
set final;
drop A1 A2 A3 A5 A6 A7 A8 A9 A10 loan_id account_id loan_date
account_creation_date disp_id client_id date birth_number issued issued_date
client_birth_date_num card_id client_birth_date district_id status;
run;



