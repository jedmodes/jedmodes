%
% Syntax coloring for SQL
% 
% Create : 2004-02-23
% Update : 2004-12-08
% Author : Marko Mahnic
%
% Installation:
%   * put the file in a directory on jed_library_path
%   * to your .jedrc add:
%       autoload ("sql_mode", "sql");
%       autoload ("mssql_mode", "sql");
%       autoload ("mysql_mode", "sql");
%       autoload ("pgsql_mode", "sql");
%       autoload ("orsql_mode", "sql");
%       add_mode_for_extension ("sql", "sql");
%
%   * Use the mode-line to choose a particular SQL varaint:
%       -*- mode: pgsql; -*-
%   
% TODO: Analyse various SQL versions and modify keyword sets

require("keywords");

static define CreateSyntaxTable(sqlmode)
{
   create_syntax_table(sqlmode);
   define_syntax("--", "", '%', sqlmode);
   define_syntax("/*", "*/", '%', sqlmode);
   define_syntax('"', '"', sqlmode);
   define_syntax('\'', '\'', sqlmode);
   define_syntax ('\\', '#', sqlmode);  % preprocessor
   define_syntax ("([", ")]", '(', sqlmode);
   define_syntax ("0-9a-zA-Z_", 'w', sqlmode);  % words
   define_syntax ("-+0-9.", '0', sqlmode);      % Numbers
   define_syntax (",;.?", ',', sqlmode);
   define_syntax ("%$()[]-+/*=<>^#", '+', sqlmode);
   set_syntax_flags (sqlmode, 0x01 | 0x20); % case insensitive
}

static variable kwds_standard =
   "as by in is on or to add all and asc for not desc drop from into only " +
   "column commit create delete except having insert values offset rename select update " +
   "natural reindex database distinct rollback intersect " +
   "alter begin group index order table union using where like ";

static variable kwds_cursor =
   "declare cursor execute open next fetch";

static variable kwds_grouping =
   "max min sum count average";

static variable kwds_joins =
   "join full inner outer left right";

static variable kwds_other =
   "go use trim length";

define sql_mode ()
{
   variable sql = "sql92";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_standard);
      keywords->add_keywords(K, kwds_cursor);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_grouping);
      keywords->add_keywords(K, kwds_other);
      % keywords->sort_keywords(K);
      % keywords->define_keywords(K, sql, 1);

      % K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_joins);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

static variable kwds_mssql_constraints =
   "primary foreign key references null constraint check no action cascade unique default " +
   "clustered nonclustered";
   
static variable kwds_mssql_types =
   "binary bigint bit char datetime decimal float identity image int money nchar ntext nvarchar numeric " +
   "real smalldatetime smallint smallmoney sql_variant sysname text timestamp tinyint " +
   "varbinary varchar uniqueidentifier";

static variable kwds_mssql_tsql =
   "procedure set while begin end if while else";

% MS SQL server
define mssql_mode ()
{
   variable sql = "mssql";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_standard);
      keywords->add_keywords(K, kwds_cursor);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_grouping);
      keywords->add_keywords(K, kwds_other);
      keywords->add_keywords(K, kwds_mssql_types);
      keywords->add_keywords(K, kwds_mssql_constraints);
      keywords->add_keywords(K, kwds_mssql_tsql);
      % keywords->sort_keywords(K);
      % keywords->define_keywords(K, sql, 1);

      % K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_joins);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);

      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

% PostgreSql
define pgsql_mode ()
{
   sql_mode();
}

% MySql
define mysql_mode ()
{
   sql_mode();
}

% Oracle
define orsql_mode ()
{
   sql_mode();
}

