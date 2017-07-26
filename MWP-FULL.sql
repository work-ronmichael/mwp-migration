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

    -- MWP_CMSCONTENT START
    INSERT
    INTO MWP_CMSCONTENT
    (
        MENUID,
        CONTENTTYPE,
        TEMP_ID
    )

    SELECT 
        curr.MENUID,
        CONTENT_TYPE,
        CONTENT_ID
    FROM PORTAL.TBL_MENU_CONTENT_NEW prev
    LEFT JOIN MWP.MWP_CMSMENU curr ON prev.CONTENT_ID = curr.TEMP_CONTENT_ID
    WHERE curr.MENUID IS NOT NULL;

    -- **THIS SCRIPT HAS A DEPENDENCY ON clob_to_blob FUNCTION PLEASE REFER TO FUNCTIONS.sql
    UPDATE MWP_CMSCONTENT
    SET CONTENTDETAIL = 
    (
        SELECT 
            clob_to_blob(CONTENT_DETAILS)
        FROM PORTAL.TBL_MENU_CONTENT_NEW 
        WHERE MWP_CMSCONTENT.TEMP_ID = PORTAL.TBL_MENU_CONTENT_NEW.CONTENT_ID
    );
    -- MWP_CMSCONTENT END

    -- MWP_VIDEO START
    INSERT
    INTO MWP_VIDEO
    (
        VIDEOTITLE,
        VIDEODESCRIPTION,
        VIDEOTIMESTAMP,
        ISPUBLISHED,
        TEMP_ID
    )
    SELECT
    WEBCAST_TITLE,
    WEBCAST_DESC,
    WEBCAST_TIMESTAMP,
    WEBCAST_STATUS,
    WEBCAST_ID  
    FROM PORTAL.TBL_WEBCAST
    LOG ERRORS INTO ERR$_MWP_VIDEO ('INSERT') REJECT LIMIT UNLIMITED;

    INSERT
    INTO MWP_VIDEOFILE
    (
        VIDEOID,
        TEMP_PATH
    )
    SELECT 
    curr.VIDEOID,
    WEBCAST_FOLDER || '/' || WEBCAST_HTMLFILE as TEMP_PATH
    FROM PORTAL.TBL_WEBCAST prev
    LEFT JOIN MWP.MWP_VIDEO curr on prev.WEBCAST_ID = curr.TEMP_ID
    LOG ERRORS INTO ERR$_MWP_VIDEO ('INSERT') REJECT LIMIT UNLIMITED;
    -- MWP_VIDEO END


    -- MWP_DLCATEGORY START
    DBMS_ERRLOG.create_error_log ('MWP_DLCATEGORY');
    INSERT
    INTO MWP_DLCATEGORY
    (
        DLPARENTID,
        DLCATEGORYNAME,
        DLSORTORDER,
        ISPUBLISHED,
        TEMP_ID,
        TEMP_TYPE
    )
    SELECT
    0 as PARENT_ID,
    DOWNLOADS_TYPE_NAME,
    0 as DLSORTORDER,
    DOWNLOADS_TYPE_STATUS,
    DOWNLOADS_TYPE_ID as TEMP_ID,
    'TYPE' as TEMP_TYPE
    FROM PORTAL.TBL_DOWNLOADS_TYPE
    LOG ERRORS INTO ERR$_MWP_DLCATEGORY ('INSERT') REJECT LIMIT UNLIMITED;

    UPDATE MWP_DLCATEGORY
    SET DLPARENTID = DLCATEGORYID
    WHERE DLPARENTID = 0;

    INSERT
    INTO MWP_DLCATEGORY
    (
        DLPARENTID,
        DLCATEGORYNAME,
        DLSORTORDER,
        ISPUBLISHED,
        TEMP_ID,
        TEMP_TYPE
    )
    SELECT 
    curr.DLCATEGORYID as PARENT_ID,
    DOWNLOADS_CATEGORY_NAME,
    0 as DLSORTORDER,
    DOWNLOADS_CATEGORY_STATUS,
    DOWNLOADS_CATEGORY_ID as TEMP_ID,
    'CATEGORY' as TEMP_TYPE
    FROM PORTAL.TBL_DOWNLOADS_CATEGORY prev
    LEFT JOIN MWP.MWP_DLCATEGORY curr ON prev.DOWNLOADS_CATEGORY_TYPE = curr.TEMP_ID AND curr.TEMP_TYPE = 'TYPE'
    LOG ERRORS INTO ERR$_MWP_DLCATEGORY ('INSERT') REJECT LIMIT UNLIMITED;

    INSERT
    INTO MWP_DLCATEGORY
    (
        DLPARENTID,
        DLCATEGORYNAME,
        DLSORTORDER,
        ISPUBLISHED,
        TEMP_ID,
        TEMP_TYPE
    )
    SELECT 
    curr.DLCATEGORYID,
    DOWNLOADS_SUBCATEGORY_NAME,
    0 as DLSORTORDER,
    DOWNLOADS_SUBCATEGORY_STATUS,
    DOWNLOADS_SUBCATEGORY_ID as TEMP_ID,
    'SUB' as TEMP_TYPE
    FROM PORTAL.TBL_DOWNLOADS_SUBCATEGORY prev
    LEFT JOIN MWP.MWP_DLCATEGORY curr ON prev.DOWNLOADS_CATEGORY_ID = curr.TEMP_ID AND curr.TEMP_TYPE = 'CATEGORY'
    LOG ERRORS INTO ERR$_MWP_DLCATEGORY ('INSERT') REJECT LIMIT UNLIMITED;
    -- MWP_DLCATEGORY END
    
    -- MWP_DLCONTENT START 
    DBMS_ERRLOG.create_error_log ('MWP_DLCONTENT');

    INSERT
    INTO MWP_DLCONTENT
    (
        DLCATEGORYID,
        DLCONTENTTITLE,
        DLCONTENTDESCRIPTION,
        ISPUBLISHED,
        DLSORTORDER,
        TEMP_ID,
        TEMP_ORIGIN
    )
    SELECT
        curr.DLCATEGORYID,
        DOWNLOADS_TITLE,
        DOWNLOADS_DESC,
        DOWNLOADS_STATUS,
        DOWNLOADS_SORT_ORDER,
        DOWNLOADS_ID as TEMP_ID,
        'CATEGORY' as TEMP_ORIGIN
    FROM PORTAL.TBL_DOWNLOADS prev
    LEFT JOIN MWP.MWP_DLCATEGORY curr ON prev.DOWNLOADS_CATEGORY = curr.TEMP_ID AND curr.TEMP_TYPE = 'CATEGORY'
    WHERE DOWNLOADS_CATEGORY IS NOT NULL
    LOG ERRORS INTO ERR$_MWP_DLCONTENT ('INSERT') REJECT LIMIT UNLIMITED;

    INSERT
    INTO MWP_DLCONTENT
    (
        DLCATEGORYID,
        DLCONTENTTITLE,
        DLCONTENTDESCRIPTION,
        ISPUBLISHED,
        DLSORTORDER,
        TEMP_ID,
        TEMP_ORIGIN
    )
    SELECT
        curr.DLCATEGORYID,
        DOWNLOADS_TITLE,
        DOWNLOADS_DESC,
        DOWNLOADS_STATUS,
        DOWNLOADS_SORT_ORDER,
        DOWNLOADS_ID as TEMP_ID,
        'SUB' as TEMP_ORIGIN
    FROM PORTAL.TBL_DOWNLOADS prev
    LEFT JOIN MWP.MWP_DLCATEGORY curr ON prev.DOWNLOADS_SUBCATEGORY = curr.TEMP_ID AND curr.TEMP_TYPE = 'SUB'
    WHERE DOWNLOADS_SUBCATEGORY IS NOT NULL
    LOG ERRORS INTO ERR$_MWP_DLCONTENT ('INSERT') REJECT LIMIT UNLIMITED;
    -- MWP_DLCONTENT END 

    -- MWP_DLCONTENTFILE START
    INSERT
    INTO MWP_DLCONTENTFILE
    (
        DLCONTENTID,
        TEMP_FILE
    )
    SELECT 
        curr.DLCATEGORYID,
        DOWNLOADS_PDF
    FROM PORTAL.TBL_DOWNLOADS prev
    LEFT JOIN MWP.MWP_DLCONTENT curr on curr.TEMP_ID = prev.DOWNLOADS_ID
    WHERE curr.DLCATEGORYID IS NOT NULL;
    -- MWP_DLCONTENTFILE END






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







    