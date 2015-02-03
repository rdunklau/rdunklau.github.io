---
layout: page
title: About me
permalink: /about/
---


I'm Ronan Dunklau, a DBA at [Dalibo][dalibo], a French PostgreSQL support company.
I'm mostly providing PostgreSQL support, but also consulting, training, and
more.

I'm also an occasional PostgreSQL contributor, primarily around the SQL-MED
standard support. Here are the patch I (co-)authored:

* Use python's Decimal for [numerics in pl/python](http://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=7919398bac8bacd75ec5d763ce8b15ffaaa3e071)
* [Triggers on foreign
  tables](http://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=7cbe57c34dec4860243e6d0f81738cfbb6e5d069)
* [IMPORT FOREIGN
  SCHEMA](http://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=59efda3e50ca4de6a9d5aa4491464e22b6329b1e) sql command support.
* Better support for [composite types in
  pl/python](http://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=8b6010b8350a1756cd85595705971df81b5ffc07)



You may be interested in the following resources:

* [Dalibo's open-source projects][dalibo_projects]
* [Multicorn][multicorn], a PostgreSQL extension allowing you to write foreign
  data wrappers in Python
* [pg_qualstats][pg_qualstats], a PostgreSQL extension gathering statistics
  about where clause usage.


This blog only reflects my personal opinions, and do not represent my employer
views in any way.

[dalibo]: http://dalibo.com
[dalibo_projects]: http://dalibo.github.io:
[pg_qualstats]: https://github.com/dalibo/pg_qualstats
[multicorn]: https://github.com/kozea/multicorn
