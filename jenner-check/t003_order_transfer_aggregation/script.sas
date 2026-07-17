/* Adapted from Credit_Risk_Modeling.sas (the `order` recode at lines 54-62,
   and the transfer/k_symbol aggregation block at lines 230-297). Original
   reads Kredyt.order from `libname Kredyt '/home/u63619495/Kredyt'`; here it
   is supplied as a small inline DATA step with the same columns
   (account_id, k_symbol, amount, operation) so the author's own k_symbol PL
   recoding, the per-account transfer sum/count/average PROC SQL, the
   COALESCE/CASE conditional-average-by-category PROC SQL, and the
   "most frequent k_symbol per account" mode-finding (GROUP BY + ORDER BY
   count DESC + BY-group first.) all run unmodified. */

data order;
  format operation k_symbol $24.;
  informat operation k_symbol $24.;
  input account_id operation & $24. k_symbol $ amount;
  if k_symbol = 'POJISTNE' then k_symbol = 'skladka_ubezpieczenia';
  else if k_symbol = 'SIPO' then k_symbol = 'rachunki_domowe';
  else if k_symbol = 'LEASING' then k_symbol = 'leasing';
  else if k_symbol = 'UVER' then k_symbol = 'rata_kredytu';
  datalines;
1 SIPO  POJISTNE 500
1 SIPO  SIPO 900
1 SIPO  SIPO 850
1 LEASING  LEASING 300
2 SIPO  UVER 1200
2 SIPO  SIPO 400
2 SIPO  SIPO 420
2 SIPO  SIPO 410
3 SIPO  POJISTNE 600
3 SIPO  POJISTNE 610
3 SIPO  LEASING 250
;
run;

proc sql;
/* Suma kwot przelewow i liczba przelewow dla kazdego konta */
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

/*most k_symbol (characterisation of transaction) and which one it is*/
proc sql;
   create table ksymbolee as
   select account_id, k_symbol, count(*) as transaction_count
   from order
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

proc print data=transfers; run;
proc print data=ksymbolee2; run;
