--///////////////////////////////////////////////////////////////////////////////////////
-- The MIT License:
-- ----------------
-- 
-- Copyright (c) 2016 Pieter Geerkens (email: pgeerkens@hotmail.com)
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this
-- software and associated documentation files (the "Software"), to deal in the Software
-- without restriction, including without limitation the rights to use, copy, modify, 
-- merge, publish, distribute, sublicense, and/or sell copies of the Software, and to 
-- permit persons to whom the Software is furnished to do so, subject to the following 
-- conditions:
--     The above copyright notice and this permission notice shall be 
--     included in all copies or substantial portions of the Software.
-- 
--     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--     EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
--     OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
--     NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
--     HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
--     WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
--     FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
--     OTHER DEALINGS IN THE SOFTWARE.
--///////////////////////////////////////////////////////////////////////////////////////

if object_id('tempdb..#tally') is not null drop table #tally;

create table #tally (
    N   int not null
);

declare @start      time = getdate(),
--        @limit      int  = 11000, -- sufficient for 30 year mortgage daily interest
        @limit      int  = 110000;

    -- Ben-Gan tally table (after Itzik Ben-Gan).
    with
     E1(N) as (select 0 from (values (1),(1),(1),(1),(1)
                                    ,(1),(1),(1),(1),(1) ) t1(N))
    ,E2(N) as (select 0 from E1 a cross join E1 b)
    ,E4(N) as (select 0 from E2 a cross join E2 b)
    ,E8(N) as (select 0 from E4 a cross join E2 b)

    insert #tally (N)
    select N = 0
    union all
    select top (@limit) N = row_number() over (order by (select null)) from E8;

alter table #tally
add constraint PK_Tally_N primary key clustered (N)
with fillfactor = 100;

select
   [count] = count(*)
  ,[elapsed time (ms)] = datediff(ms,@start,cast(getdate() as time))
from #tally;
go

if object_id('tempdb..#FiscalPeriod') is not null drop table #FiscalPeriod;
create table #FiscalPeriod (
    Id          int identity not null primary key clustered,
    Year        int not null,
    PeriodNo    int not null,
    BeginDate   date not null,
    PseudoDate  date not null

    ,constraint NK_Period_YearPeriodNo unique nonclustered (Year,PeriodNo)
    ,constraint NK_Period_BeginDate unique nonclustered (BeginDate)
    ,constraint NK_Period_PseudoDate unique nonclustered (PseudoDate)
);
insert #FiscalPeriod(Year,PeriodNo,BeginDate,PseudoDate)
values (2016, 1,'20160101','20160101')
      ,(2016, 2,'20160124','20160201')
      ,(2016, 3,'20160221','20160301')
      ,(2016, 4,'20160327','20160401')
      ,(2016, 5,'20160424','20160501')
      ,(2016, 6,'20160522','20160601')
      ,(2016, 7,'20160626','20160701')
      ,(2016, 8,'20160724','20160801')
      ,(2016, 9,'20160821','20160901')
      ,(2016,10,'20160925','20161001')
      ,(2016,11,'20161023','20161101')
      ,(2016,12,'20161120','20161201')
;
go

with
pds as (
  select 
     pd.Year, pd.BeginDate, pd.PeriodNo, pd.PseudoDate
    ,EndDate = isnull(dateadd(day,-1,
                              lead(BeginDate,1) over (order by BeginDate))
                     ,datefromparts(Year,12,31))
  from #FiscalPeriod pd
),
periods as (
  select
     pds.*
    ,DayCount = 1 + datediff(day,BeginDate,EndDate)
  from pds
)
select
     periods.PeriodNo, N=N+1
    ,Day        =               dateadd(day,N,periods.BeginDate)
    ,WeekNo     = datepart(week,dateadd(day,N,periods.BeginDate))
    ,DayName    = datename(weekday, dateadd(day,N,periods.BeginDate))
from periods
join #tally tally on tally.N < periods.DayCount
where periods.PeriodNo = 4
order by Day
go

declare @test varchar(max) ='
How much wood could a woodchuck chuck,
If a woodchuck could chuck wood?
As much wood as a woodchuck could chuck,
If a woodchuck could chuck wood.
';
declare @length int = len(@test);

select 
    sum(case when substring(@test, N, @length) like 'wood%' then 1 else 0 end) as [wood occurs]
   ,sum(case when substring(@test, N, @length) like 'could%' then 1 else 0 end) as [could occurs]
from #tally
;
go

if object_id('tempdb..#sales') is not null drop table #sales;
create table #sales (
     Id             int identity not null primary key clustered
    ,Date           date not null
    ,[Doc #]        varchar(8) not null
    ,[AR Dr]        decimal(18,2) not null default 0
    ,[Revenue Cr]   decimal(18,2) not null default 0
    ,[GST Owed Cr]  decimal(18,2) not null default 0
    ,[PST Owed Cr]  decimal(18,2) not null default 0
    ,[COGS Dr]      decimal(18,2) not null default 0
    ,[Dir Mat Cr]   decimal(18,2) not null default 0
    ,[Dir Lab Cr]   decimal(18,2) not null default 0
    ,[Dir Srv Cr]   decimal(18,2) not null default 0
    ,[Dir Bur Cr]   decimal(18,2) not null default 0

    constraint Sales_NK unique nonclustered ([Doc #])
);

insert #sales(Date,[Doc #]
     ,[AR Dr],[Revenue Cr],[GST Owed Cr],[PST Owed Cr]
     ,[COGS Dr],[Dir Mat Cr],[Dir Lab Cr],[Dir Srv Cr],[Dir Bur Cr]
     )
values
     ('2016-04-08','ABC001', 1130.00, 1000.00, 50.00, 80.00
     , 800.00, 300.00, 250.00, 100.00, 150.00),
     ('2016-04-08','ABC003', 2260.00, 2000.00, 100.00, 160.00
     , 1600.00, 600.00, 500.00, 200.00, 300.00);

select
     Id,
     Date,[Doc #]
    ,[     AR Dr]    = convert(char(10),cast([AR Dr] as money),1)
    ,[Revenue Cr]    = convert(char(10),cast([Revenue Cr] as money),1)
    ,[GST Owed Cr]   = convert(char(10),cast([GST Owed Cr] as money),1)
    ,[PST Owed Cr]   = convert(char(10),cast([PST Owed Cr] as money),1)
    ,[   COGS Dr]    = convert(char(10),cast([COGS Dr] as money),1)
    ,[Dir Mat Cr]    = convert(char(10),cast([Dir Mat Cr] as money),1)
    ,[Dir Lab Cr]    = convert(char(10),cast([Dir Lab Cr] as money),1)
    ,[Dir Srv Cr]    = convert(char(10),cast([Dir Srv Cr] as money),1)
    ,[Dir Bur Cr]    = convert(char(10),cast([Dir Bur Cr] as money),1)

from #sales;

if object_id('tempdb..#salesFolded') is not null drop table #salesFolded;
create table #salesFolded (
     SalesId  int           not null
    ,Acct     varchar(10)   not null
    ,Date     date          not null
    ,[Doc #]  varchar(8)    not null
    ,Dr       decimal(18,2) not null
    ,Cr       decimal(18,2) not null

    constraint SalesFolded_NK unique clustered (SalesId,Acct)
);

insert #salesFolded(SalesId,Acct,Date,[Doc #], Dr, Cr)
select
     Id
    ,Acct
    ,Date
    ,[Doc #]
    ,Dr
    ,Cr

from #sales
cross apply (values
     ('AR',           [AR Dr],            0)
    ,('Revenue',            0, [Revenue Cr])
    ,('GST Owed',           0,[GST Owed Cr])
    ,('PST Owed',           0,[PST Owed Cr])
    ,('COGS',       [COGS Dr],            0)
    ,('Dir Mat',            0, [Dir Mat Cr])
    ,('Dir Lab',            0, [Dir Lab Cr])
    ,('Dir Srv',            0, [Dir Srv Cr])
    ,('Dir Bur',            0, [Dir Bur Cr])
)data(Acct, Dr, Cr)

select 
     Date
    ,[Doc #]
    ,Acct
    ,Dr      = convert(char(11),cast(Dr as money),1)
    ,Cr      = convert(char(11),cast(Cr as money),1)
    ,Balance = convert(char(11),cast(Dr - Cr as money),1)
from #salesFolded;

with 
data as (
  select 
     Date
    ,[Doc #]
    ,[AR Dr]     = sum([AR Dr]    )
    ,[Rev Cr]    = sum([Rev Cr]   )
    ,[Tax Cr]    = sum([Tax Cr]   )
    ,[COGS Dr]   = sum([COGS Dr]  )
    ,[Inven Cr]  = sum([Inven Cr] )
  from #salesFolded salesFolded
  cross apply( values
     ('AR',      Dr-Cr,  0,   0,   0,   0)
    ,('Revenue',    0,Cr-Dr,  0,   0,   0)
    ,('GST Owed',   0,   0,Cr-Dr,  0,   0)
    ,('PST Owed',   0,   0,Cr-Dr,  0,   0)
    ,('COGS',       0,   0,   0,Dr-Cr,  0)
    ,('Dir Mat',    0,   0,   0,   0,Cr-Dr)
    ,('Dir Lab',    0,   0,   0,   0,Cr-Dr)
    ,('Dir Srv',    0,   0,   0,   0,Cr-Dr)
    ,('Dir Bur',    0,   0,   0,   0,Cr-Dr)
  )pvt(Acct,[AR Dr],[Rev Cr],[Tax Cr],[COGS Dr],[Inven Cr])
  where salesFolded.Acct = pvt.Acct
  group by
     Date,[Doc #]
)
select 
     Date
    ,[Doc #]
    ,[AR Dr]     = convert(char(11),cast([AR Dr] as money),1)
    ,[Rev Cr]    = convert(char(11),cast([Rev Cr] as money),1)
    ,[Tax Cr]    = convert(char(11),cast([Tax Cr] as money),1)
    ,[COGS Dr]   = convert(char(11),cast([COGS Dr] as money),1)
    ,[Inven Cr]  = convert(char(11),cast([Inven Cr] as money),1)
from data
go
