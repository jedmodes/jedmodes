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
%       autoload ("sql92_mode", "sql");
%       autoload ("sql99_mode", "sql");
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

% If the mode is not specified in modeline, use this mode 
% as default for .sql files
custom_variable ("sql_default_mode", "sql92");


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


static variable kwds_common =
   "some distinct desc int current_time group inner then grant not with when delete varchar " +
   "nchar join float timestamp in is cross as order by right to read real authorization " +
   "of or option on drop close end fetch values declare cascade into alter null primary " +
   "begin cursor except smallint case schema outer precision current_timestamp where " +
   "check current_date double union restrict else intersect rollback execute create foreign " +
   "update revoke having set references decimal commit from key column procedure full " +
   "char default between transaction any and asc exists bit escape all constraint user " +
   "add left table select for view numeric insert unique like ";

static variable kwds_sqlpgmy9992 =
   "time local rows level unknown natural privileges last type trim next at month relative " +
   "first no constraints dec isolation only language integer absolute character usage " +
   "substring second minute domain year using work write both day session prepare hour ";

static variable kwds_sql9992 =
   "uncommitted descriptor collation_schema connection_name leading initially subclass_origin " +
   "column_name c diagnostics end-exec whenever interval unnamed pascal length current " +
   "dynamic_function fortran character_set_name session_user names pli match size found " +
   "cascaded table_name national command_function character_set_catalog external go scroll " +
   "pad number count lower message_length exec connect position public indicator action " +
   "nullif constraint_catalog sum sqlstate cursor_name collation_name translation disconnect " +
   "returned_length committed datetime_interval_precision catalog_name collation char_length " +
   "section cobol system_user current_user open more deferred value returned_sqlstate " +
   "mumps space deferrable partial prior describe data date message_octet_length repeatable " +
   "class_origin character_length module schema_name cast returned_octet_length extract " +
   "zone assertion exception translate constraint_name global bit_length immediate serializable " +
   "sql timezone_hour corresponding max name datetime_interval_code upper timezone_minute " +
   "identity trailing character_set_schema deallocate octet_length continue constraint_schema " +
   "server_name min output goto avg preserve collation_catalog overlaps temporary insensitive " +
   "connection are allocate row_count message_text ada nullable collate varying catalog " +
   "coalesce get input scale condition_number convert ";

static variable kwds_sql92 =
   "sqlerror sqlcode ";

static variable kwds_sql99 =
   "asensitive terminate bitvar specific_name g k m than limit recursive modify inout " +
   "trigger granted symmetric cardinality variable nclob user_defined_type_catalog sequence " +
   "defined overriding without definer sqlexception each current_role breadth infix new " +
   "every large before hold method mod source binary existing instantiable out parameter " +
   "key_member simple old user_defined_type_schema deterministic boolean trigger_name " +
   "transactions_rolled_back routine cycle trigger_catalog result function checked options " +
   "scope off cube destroy blob none initialize localtimestamp dispatch postfix final " +
   "array called deref class ordinality savepoint dynamic assignment depth iterate sqlwarning " +
   "chain routine_catalog key_type similar parameter_mode grouping transactions_committed " +
   "destructor implementation admin transaction_active parameter_ordinal_position dictionary " +
   "operation general object less current_path ignore sublist contains lateral under " +
   "overlay constructor alias transforms self after call locator hierarchy start search " +
   "generated clob treat aggregate completion rollup security state specifictype transform " +
   "user_defined_type_name preorder return trigger_schema statement routine_schema prefix " +
   "returns routine_name asymmetric map row atomic style sensitive parameter_name ref " +
   "structure static free unnest parameters localtime specific parameter_specific_name " +
   "parameter_specific_catalog command_function_code system abs path equals invoker parameter_specific_schema " +
   "modifies dynamic_function_code instance role reads sets referencing host ";

static variable kwds_pgsql =
   "leading initially lock comment load interval limit inout trigger sequence without " +
   "definer copy each vacuum session_user names truncate index force new match before " +
   "hold cluster notnull binary handler national out simple ilike temp old characteristics " +
   "external valid boolean scroll lancompiler excluding cycle function reset off do share " +
   "backward version unencrypted storage position template unlisten none action nullif " +
   "localtimestamp array called committed cache inherits mode class validator explain " +
   "assignment verbose recheck placing move increment access notify including bigint " +
   "oids implicit show forward chain current_user similar deferred location pendant delimiter " +
   "setof maxvalue exclusive abort encoding statistics immutable procedural deferrable " +
   "partial prior toast createdb overlay after cast owner delimiters start stdin stable " +
   "extract zone assertion treat aggregate isnull security nocreateuser listen nocreatedb " +
   "freeze password trusted analyze analyse global checkpoint immediate serializable " +
   "statement returns operator row rename until trailing deallocate createuser conversion " +
   "volatile reindex sysid stdout instead database preserve overlaps minvalue restart " +
   "temporary offset insensitive localtime rule strict replace path defaults collate " +
   "varying encrypted invoker coalesce nothing input convert ";

static variable kwds_mssql =
   "percent load deny trigger current smalldatetime datetime session_user bulk distributed " +
   "truncate dummy index disk identity_insert tran raiseerror binary reconfigure national " +
   "nocheck compute over go text if offsets smallmoney function image off count exit " +
   "lower tinyint proc freetext exec use fillfactor public money nullif clustered sum " +
   "top holdlock sysname backup plan bigint break system_user textsize current_user open " +
   "ntext openquery statistics identitycol print rowguidcol math contains shutdown sql_variant " +
   "uniqueidentifier while errlvl opendatasource updatetext nvarchar replication tsequal " +
   "dump openxml return checkpoint file varbinary max identity browse deallocate kill " +
   "continue freetexttable readtext min goto containstable save database avg dbcc openrowset " +
   "rule abs waitfor collate varying rowcount setuser nonclustered coalesce lineno restore " +
   "convert ";

static variable kwds_mysql =
   "true fact sysdate vtrace format instr long serverdb months mbcs percent lock comment " +
   "load whenever standard endproc logwriter radians recursive modify inout param enable " +
   "hextoraw timezone trigger selupd autosave medium costwarning packed length current " +
   "explicit hex sinh pctused stop eur sequence beginload curdate dropin tablespace cosh " +
   "week log10 flush event lfill truncate append dimension index force new pos address " +
   "inproc to_number sqlmode archive remove next_day before hold now pages optimistic " +
   "error mod cluster binary diagnose device num byte tan utcdate suspend nvl maketime " +
   "minutes container nls_date_format initcap out get_objectname rawtohex degree temp " +
   "stat compute concat nls_date_language ltrim fversion identified get_schema monthname " +
   "lcase boolean db_above_limit migrate if info subtime ln cycle least config months_between " +
   "nolog function resume number floor validproc off count fixed do lower share version " +
   "sqrt ucase prev extended storage proc priv microseconds editproc connect pi obid " +
   "atan sapr3 usergroup usa high public indicator rfill db_below_limit none nls_sort " +
   "initrans buffer takeover caches uid optimize medianame nlssort last_day try sum init " +
   "label div cos cot noorder userid cache indexname ping alpha false mode pctfree subpages " +
   "block savepoint dynamic explain norewind varchar2 timediff pipe cancel variance nominvalue " +
   "atan2 dayofyear increment ascii ceiling longfile break tape implicit microsecond " +
   "sysdba show catch adddate to_char startpos open reuse datediff writer overwrite nocycle " +
   "vargraphic value synchronize maxvalue exclusive statistics rpad space digits tanh " +
   "acos describe clear object data date power degrees createin ignore dayofweek current_schema " +
   "lpad unlock ceil days quick years trace resource to_date shutdown synonym while defaultcode " +
   "nocache after call debug wait start decode maxtrans asin add_months dsetpass stamp " +
   "nosort alterin replication snapshot topic greatest utcdiff dbprocedure rowno mapchar " +
   "duplicates state sqlid translate sounds nextval rowid round makedate freepage estimate " +
   "rtrim return password currval analyze blocksize checkpoint reject nowait ansi stddev " +
   "soundex addtime raw auto noround ifnull nls_language file returns sin selectivity " +
   "curtime weekofyear max name row package upper low seconds sample rename log until " +
   "volume switch verify bwhierarchy parseid standby trunc vsize subdate cachelimit jis " +
   "continue backup_pages unicode psm log_above_limit min new_time static internal release " +
   "iso save database avg db2 minvalue dba disable unload chr restart oracle logfull " +
   "same costlimit monitor expand beginproc bufferpool bad unused timeout locate sign " +
   "replace abs java rownum zoned register graphic catalog endload remote subtrans minus " +
   "range dayofmonth page instance toidentifier exp list role dbproc get hours serial " +
   "dayname substr tabid parse restore normal nomaxvalue ";

define sql92_mode ()
{
   variable sql = "sql92";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_sqlpgmy9992);
      keywords->add_keywords(K, kwds_sql9992);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_sql92);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

define sql99_mode ()
{
   variable sql = "sql99";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_sqlpgmy9992);
      keywords->add_keywords(K, kwds_sql9992);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_sql99);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

% MS SQL mode
define mssql_mode ()
{
   variable sql = "mssql";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_mssql);
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
   variable sql = "pgsql";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_sqlpgmy9992);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_pgsql);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

% MySql
define mysql_mode ()
{
   variable sql = "mysql";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_sqlpgmy9992);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_mysql);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

% Oracle
define orsql_mode ()
{
   sql92_mode();
}

define sql_mode ()
{
   variable mode;
   mode = sprintf("%s_mode", sql_default_mode);
   if (is_defined(mode) > 0)
      eval(mode);
   else sql92_mode();
}

