---
layout: post
title:  "Import foreign schema support in Multicorn"
date:   2015-04-05 15:32:29
categories:
  postgresql
  multicorn
  python
---

Some of you may have noticed that support for the **IMPORT FOREIGN SCHEMA**
statement has landed in the PostgreSQL source tree last july. This new command
allows users to automatically map foreign tables to local ones.

## Use-Case

Previously, if you wanted to use the postgres_fdw Foreign Data Wrapper
to access data stored in a remote database you had to:

* Create the extension
* Create a server
* Create a user mapping
* For each remote table:
  * Create a **FOREIGN TABLE** which structures matches the remote one

This last step is tedious, and error prone: you have to match the column names,
in the right order, with the right type.

The **IMPORT FOREIGN SCHEMA** statements allows you to automatically create a
foreign table object for each object available remotely.

## Multicorn implementation

The API has been implemented in Multicorn for a few months, lingering in its own
branch.

I just merged it back to the master branch, and this feature will land in an
upcoming 1.2.0 release. In the meantime, test it !

# The API

Its simple, like always with Multicorn. FDW just have to override the
import_schema method:

{% highlight python %}
  @classmethod
  def import_schema(self, schema, srv_options, options, restriction_type,
                    restricts)
{% endhighlight %}

This method just has to build a list of [TableDefinition][TableDefinition] objects:

{% highlight python %}
return [
  TableDefinition("table_name", schema=None,
    columns=[
      ColumnDefinition(
        name="column_name",
        type_name="integer")])]
{% endhighlight %}

And thats it !

As for now, the only FDW shipped with Multicorn that does implement this API is
the [sqlalchemyfdw][sqlalchemyfdw].

# SQLAlchemyFDW test run

So, with this API in mind, I conducted a small test: trying to import an Oracle
schema as well as a MS-SQLServer schema:

{% highlight sql %}
CREATE EXTENSION multicorn;

CREATE SERVER mssql_server FOREIGN DATA WRAPPER multicorn
OPTIONS (
  wrapper 'multicorn.sqlalchemyfdw.SqlAlchemyFdw',
  drivername 'mssql+pymssql',
  host 'myhost',
  port '1433',
  database 'testmulticorn');

CREATE USER MAPPING FOR ronan SERVER mssql_server OPTIONS (username 'user', password 'password');

CREATE SCHEMA mssql;

IMPORT FOREIGN SCHEMA dbo FROM SERVER mssql_server INTO mssql ;

CREATE SERVER sqlite_server FOREIGN DATA WRAPPER multicorn
OPTIONS (
  wrapper 'multicorn.sqlalchemyfdw.SqlAlchemyFdw',
  drivername 'sqlite',
  database '/home/ronan/mydb.sqlite3');

CREATE SCHEMA sqlite;

IMPORT FOREIGN SCHEMA main FROM SERVER sqlite_server INTO sqlite ;

DELETE FROM mssql.t1;
DELETE FROM sqlite.t1;

INSERT INTO sqlite.t1 (id, label) VALUES (1, DEFAULT);
SELECT * FROM sqlite.t1;

CREATE SERVER oracle_server FOREIGN DATA WRAPPER multicorn
OPTIONS (
  wrapper 'multicorn.sqlalchemyfdw.SqlAlchemyFdw',
  drivername 'oracle',
  host 'another_host',
  database 'testmulticorn');


CREATE USER MAPPING FOR ronan SERVER oracle_server OPTIONS (username 'user', password 'password');

CREATE SCHEMA oracle;

IMPORT FOREIGN SCHEMA ronan FROM SERVER oracle_server INTO oracle ;
{% endhighlight %}

And thats it ! Its sufficient to query tables from sqllite, oracle and MS-SQL
from a single connection.

Once again, feel free to test it and to report any bugs you may find along the
way !


[TableDefinition]: http://multicorn.readthedocs.org/en/latest/api.html#multicorn.TableDefinition
[sqlalchemyfdw]: http://multicorn.readthedocs.org/en/latest/foreign-data-wrappers/sqlalchemyfdw.html#sqlalchemy-foreign-data-wrapper
