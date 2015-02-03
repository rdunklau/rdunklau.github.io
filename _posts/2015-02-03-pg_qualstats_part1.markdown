---
layout: post
title:  "pg_qualstats - 1st part"
date:   2015-02-02 17:03:29
categories:
  postgresql
  powa
  pg_qualstats
---

[pg_qualstats][pg_qualstats] is a new extension allowing you to collect statistics about what predicates are effectively executed on your PostgreSQL instance, sponsored by [Dalibo][dalibo] This post is part of a series explaining pg_qualstats, and its integration with [PoWA][powa], the **PostgreSQL Workload Analyzer**.


## Overview

The goal of this extension is to allow the DBA to answer to some specific
questions, whose answers are quite hard to come by:

* what is the set of queries using this column ?
* what are the values this where clause is most often using ?
* do I have some significant skew in the distribution of the number of returned rows if use some value instead of one another ?
* which columns are often used together in a `WHERE` clause ?

Traditionnaly, if you want to answers those questions, you have to:

* parse the logs, and hope that the application is not using the
  [`search_path`](http://www.postgresql.org/docs/current/static/ddl-schemas.html#DDL-SCHEMAS-PATH) extensively. If it does, you may have trouble identifiying a set of queries using the same table, and the same columns. In fact, it will probably get really hard to do even if the whole database schema is stored in `public`.
* have an intimate knowledge of the database schema, and the various
  applications that use it. You may acquire this knowledge if you work in close
  collaboration with the developers, but it will sadly be incomplete and quickly
  obsoloted.

## Installation

You will need PostgreSQL 9.4 for this, and its header files. The installation
process is similar to the one of [pg_stat_statements](http://www.postgresql.org/docs/current/static/pgstatstatements.html).

Using `pg_stat_statements` is not required, but useful if you want to link the
predicates back to the queries they appeared into.

To install [pg_qualstats][pg_qualstats], just grab it from pgxn:


{% highlight bash %}
wget http://pgxn.org/dist/pg_qualstats/
cd pg_qualstats
make && sudo make install
{% endhighlight %}

Or using the pgxnclient:

{% highlight bash %}
sudo pgxnclient install pg_qualstats
{% endhighlight %}

Then, you'll have to configure Postgresql, by putting `pg_qualstats` into your
`shared_preload_libraries` parameter:

<figure>
<figcaption>postgresql.conf</figcaption>
{% highlight ini %}
shared_preload_libraries = 'pg_stat_statements,pg_qualstats'
{% endhighlight %}
</figure>

Then, don't forget to restart your PostgreSQL server, and you should be able to
create both extensions:

{% highlight sql %}
psql (9.4.0)
Type "help" for help.

ro=# CREATE EXTENSION pg_stat_statements;
CREATE EXTENSION
ro=# CREATE EXTENSION pg_qualstats ;
CREATE EXTENSION
{% endhighlight %}

And that's it, you should be good to go !

## Starting slowly...

pg_qualstats provides several functions and views, the basic one being named...
`pg_qualstats`, obvisously :)

But lets try it, by creating a table and running a single query on it:

{% highlight sql %}
ro=# CREATE TABLE t1 AS (SELECT i FROM generate_series(1, 1000) as i);
SELECT 1000
ro=# CREATE TABLE t1 AS (SELECT i FROM generate_series(1, 1000) as i);^C
ro=# select * from t1 where i = 1;
 i 
---
 1
(1 ligne)
ro=# select * from pg_qualstats;
-[ RECORD 1 ]-----+-----------
userid            | 16384
dbid              | 17757
lrelid            | 848199
lattnum           | 1
opno              | 96
rrelid            | ∅
rattnum           | ∅
qualid            | ∅
uniquequalid      | ∅
qualnodeid        | 3411282766
uniquequalnodeid  | 2846790230
count             | 1000
nbfiltered        | 999
constant_position | 27
queryid           | 1578034309
constvalue        | 1::integer
eval_type         | f
{% endhighlight %}

So, what does it tell us ?

* **`userid`** contains the executing **user OID**, here the OID for `ro`
* **`dbid`** contains the **database OID**, here the OID for database `ro`
* **`lreflid`** contains the **OID of the relation** on the left side of the
  expression. This can be joined against `pg_class` to get the table name
* **`lattnum`** is the **attribute number**, to be joined against `pg_attribute`
* **`opno`** is the **operator oid**, to be joined against `pg_operator`.
* **`eval_type`** is the context in which this predicate was executed. **`f`**
  means it as executed as a filter, during a scan. **`i`** would have indicated
  that it was executed as an index clause, during an index scan
* **`count`** is the number of time this predicate was executed. Since it was
  executed as part of a `seqscan`, it has to be executed one time per row.
* **`nbfiltered`** is the number of row that didn't make it past this predicate.
  That is, we executed this predicate 1000 time and discarded 999 rows, giving
  us a **`filter_ratio`**, or selectivity, of 1‰.
* **`constvalue`** is the actual value of the constant on the right-hand-side of
  the predicate, here **1**.

The `pg_qualstats_pretty` view can give you a more human-friendly way of
visualising this, and aggregates by predicate:

{% highlight sql %}
ro=# select * from pg_qualstats_pretty ;
-[ RECORD 1 ]+-------------
left_schema  | public
left_table   | t1
left_column  | i
operator     | pg_catalog.=
right_schema | ∅
right_table  | ∅
right_column | ∅
count        | 1000
nbfiltered   | 999
{% endhighlight %}

But let's try to run some more queries on this sample table:

{% highlight sql %}
ro=# select * from t1 where i = 1;
ro=# select * from pg_qualstats ;
-[ RECORD 1 ]-----+-----------
userid            | 16384
dbid              | 17757
lrelid            | 848199
lattnum           | 1
opno              | 96
rrelid            | ∅
rattnum           | ∅
qualid            | ∅
uniquequalid      | ∅
qualnodeid        | 3411282766
uniquequalnodeid  | 2846790230
count             | 1000
nbfiltered        | 999
constant_position | 27
queryid           | 1578034309
constvalue        | 1::integer
eval_type         | f
-[ RECORD 2 ]-----+-----------
userid            | 16384
dbid              | 17757
lrelid            | 848199
lattnum           | 1
opno              | 96
rrelid            | ∅
rattnum           | ∅
qualid            | ∅
uniquequalid      | ∅
qualnodeid        | 3411282766
uniquequalnodeid  | 954012517
count             | 1000
nbfiltered        | 999
constant_position | 27
queryid           | 1578034309
constvalue        | 2::integer
eval_type         | f
{% endhighlight %}

So, after querying this table with another constant value, this gives us a new
row for this new value.

But how do we tie them together ?

* **`qualnodeid`** is an identifier for one normalized particular part of the
  predicate, that is, excluding any constant. Here, both our conditions are
  using the same attribute, and the same operator, hence the same qualnodeid.
  This qualnodeid uniquely identifies the **`t1.i = ?`** predicate.
* **`uniquequalnodeid`** is an identifier for one particular part of the
  predicate, taking constants into account. The **2846790230** value uniquely
  identifies the **`t1.i = 1`** clause.

## Using AND'ed clauses

Albeit pg_qualstats doesn't support **OR'ed** clause yet, there is support for
**AND'ed** clauses.

Let's see:

{% highlight sql %}
ro=# select * from t1 where i > 10 and i = 1;
 i 
---
(0 rows)
ro=# select * from pg_qualstats;
-[ RECORD 1 ]-----+------------
userid            | 16384
dbid              | 17757
lrelid            | 848199
lattnum           | 1
opno              | 521
rrelid            | ∅
rattnum           | ∅
qualid            | 1548643620
uniquequalid      | 1684386194
qualnodeid        | 584158233
uniquequalnodeid  | 2042184354
count             | 1000
nbfiltered        | 20
constant_position | 27
queryid           | 3640911477
constvalue        | 10::integer
eval_type         | f
-[ RECORD 2 ]-----+------------
userid            | 16384
dbid              | 17757
lrelid            | 848199
lattnum           | 1
opno              | 521
rrelid            | ∅
rattnum           | ∅
qualid            | 1548643620
uniquequalid      | 1684386194
qualnodeid        | 584158233
uniquequalnodeid  | 1357724498
count             | 1000
nbfiltered        | 20
constant_position | 38
queryid           | 3640911477
constvalue        | 20::integer
eval_type         | f
{% endhighlight %}

The interesting colums here are:

* **`qualid`**, which identifies the whole predicate. That is, the value of
  **1548643620** uniquely identifies the whole `t1.i > ? AND t1.i = ?` clause
* **`uniquequalid`** serves the same purpose as uniquequalnodeid, that is it
  identifies the specific `t1.id > 10 AND t1.id = 1` clause.

This can be used to aggregate by whole clauses, and will allow you to answer
specific question as:

* which queries are using this predicate ?
{% highlight sql %}
ro=# select query, sum(q1.count) / calls AS exec_by_query
FROM pg_qualstats q1
JOIN pg_stat_statements USING (queryid)
where q1.lrelid = 't1'::regclass AND q1.lattnum = 1
AND q1.opno = '=(int,int)'::regoperator
GROUP BY query, calls
;
                  query                  |     exec_by_query     
-----------------------------------------+-----------------------
 select * from t1 where i > ? and i = ?; | 1000.0000000000000000
 select * from t1 where i = ?;           | 1000.0000000000000000
{% endhighlight %}

* What value is the most queried ?
{% highlight sql %}
ro=# select constvalue,
       count,
       count / sum(count) OVER () as percent
FROM (
  SELECT constvalue,
        sum(count) as count
  FROM pg_qualstats q1
  WHERE q1.lrelid = 't1'::regclass
        AND q1.lattnum = 1
        AND q1.opno = '=(int,int)'::regoperator
  GROUP BY constvalue
) totals
ORDER BY count DESC;
 constvalue | count |        percent         
------------+-------+------------------------
 1::integer |  8000 | 0.63636363636363636364
 2::integer |  2000 | 0.18181818181818181818
 3::integer |  1000 | 0.09090909090909090909
{% endhighlight %}

That's all for today !

In a following blog post, we'll see how to use [PoWA][powa] to make the most sense of this extension.


[dalibo]: http://dalibo.github.io
[powa]: http://dalibo.github.io/powa
[pg_qualstats]: https://github.com/dalibo/pg_qualstats
