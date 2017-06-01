DECLARE 
tablecount NUMBER;
table_name = 
DBMS_ERRLOG.create_error_log ('MWP_NEWS');
BEGIN








EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM  MWP_NEWSinto tablecount;
IF tablecount = 0 THEN
  EXECUTE IMMEDIATE 'drop table ' || empty_table.table_name;
END IF;
END;












