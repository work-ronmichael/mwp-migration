DECLARE 
    tablecount NUMBER;
    cursor error_tables IS SELECT table_name FROM user_tables WHERE table_name LIKE 'ERR$%';

BEGIN

    --DROP ALL ERROR LOGS
    for x in (SELECT table_name FROM user_tables WHERE table_name LIKE 'ERR$%')
    loop
        EXECUTE IMMEDIATE 'drop table ' || x.table_name;
    end loop;

    -- CLEAN ALL TABLES
    for x in (SELECT table_name FROM user_tables)
    loop
        EXECUTE IMMEDIATE  'DELETE FROM ' || x.table_name;
    end loop;

    -- MIGRATE CODES START HERE

    -- MWP_DYNAMIC_MENU START
    DBMS_ERRLOG.create_error_log ('MWP_CMSMENU');
    INSERT
    INTO MWP_CMSMENU
    (
        MENUPARENT,
        MENULABEL,
        MENUORDER,
        ISPUBLISHED,
        TEMP_ID,
        TEMP_CONTENT_ID,
        TEMP_LEVEL
    )
    SELECT 
    0 as PARENT_ID,
    FIRST_LEVEL_LABEL,
    FIRST_LEVEL_SORT_ORDER,
    FIRST_LEVEL_STATUS,
    FIRST_LEVEL_ID,
    CONTENT_ID,
    1 as TEMP_LEVEL
    FROM PORTAL.TBL_MENU_FIRST_LEVEL_NEW
    LOG ERRORS INTO ERR$_MWP_CMSMENU ('INSERT') REJECT LIMIT UNLIMITED;

    UPDATE MWP_CMSMENU
    SET MENUPARENT = MENUID
    WHERE MENUPARENT = 0;

    INSERT
    INTO MWP_CMSMENU
    (
        MENUPARENT,
        MENULABEL,
        MENUORDER,
        ISPUBLISHED,
        TEMP_ID,
        TEMP_CONTENT_ID,
        TEMP_LEVEL
    )
    SELECT 
    n_data.MENUID as PARENT_ID,
    SECOND_LEVEL_LABEL,
    SECOND_LEVEL_SORT_ORDER,
    SECOND_LEVEL_STATUS,
    SECOND_LEVEL_ID,
    CONTENT_ID,
    2 as TEMP_LEVEL
    FROM PORTAL.TBL_MENU_SECOND_LEVEL_NEW o_data
    LEFT JOIN MWP.MWP_CMSMENU n_data ON o_data.FIRST_LEVEL_ID = n_data.TEMP_ID
    LOG ERRORS INTO ERR$_MWP_CMSMENU ('INSERT') REJECT LIMIT UNLIMITED;


    INSERT
    INTO MWP_CMSMENU
    (
        MENUPARENT,
        MENULABEL,
        MENUORDER,
        ISPUBLISHED,
        TEMP_ID,
        TEMP_CONTENT_ID,
        TEMP_LEVEL
    )
    SELECT 
        curr.MENUID as PARENT_ID,
        MENU_LABEL,
        MENU_SORT_ORDER,
        MENU_STATUS,
        MENU_ID,
        CONTENT_ID,
        3 as TEMP_LEVEL
    FROM PORTAL.TBL_MENU_NEW prev
    LEFT JOIN MWP.MWP_CMSMENU curr ON prev.SECOND_LEVEL_ID = curr.TEMP_ID
    WHERE prev.MENU_PARENT = 0
    LOG ERRORS INTO ERR$_MWP_CMSMENU ('INSERT') REJECT LIMIT UNLIMITED;

    INSERT
    INTO MWP_CMSMENU
    (
        MENUPARENT,
        MENULABEL,
        MENUORDER,
        ISPUBLISHED,
        TEMP_ID,
        TEMP_CONTENT_ID,
        TEMP_LEVEL
    )
        
    SELECT 
        curr.MENUID as PARENT_ID,
        MENU_LABEL,
        MENU_SORT_ORDER,
        MENU_STATUS,
        MENU_ID,
        CONTENT_ID,
        4 as TEMP_LEVEL
    FROM PORTAL.TBL_MENU_NEW prev
    LEFT JOIN MWP.MWP_CMSMENU curr ON prev.MENU_PARENT = curr.TEMP_ID AND curr.TEMP_LEVEL = 3
    WHERE prev.MENU_PARENT <> 0
    LOG ERRORS INTO ERR$_MWP_CMSMENU ('INSERT') REJECT LIMIT UNLIMITED;
    -- MWP_DYNAMIC_MENU END



    -- MIGRATE CODES ENDS HERE
    COMMIT;
    -- DROP ALL EMPTY ERROR TABLES
    for empty_table in error_tables
    loop
		EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM '|| empty_table.table_name into tablecount;
		IF tablecount = 0 THEN
		  EXECUTE IMMEDIATE 'drop table ' || empty_table.table_name;
		END IF;
	end loop;
END;







    