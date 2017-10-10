DECLARE 
    tablecount NUMBER;
    cursor error_tables IS SELECT table_name FROM user_tables WHERE table_name LIKE 'ERR$%';
    CURSOR long_to_char_faq_cat IS select * from xmltable
    (
        '/ROWSET/ROW'
        passing dbms_xmlgen.getXMLType
        (
            'SELECT
            FAQ_CATEGORY_ID,
            FAQ_DESCRIPTION
            FROM PORTAL.TBL_FAQ_CATEGORY'
        )
        columns
        FAQ_CATEGORY_ID NUMBER(2, 0),
        FAQ_DESCRIPTION  NVARCHAR2(255)
    );
	rc long_to_char_faq_cat%ROWTYPE;

    CURSOR long_to_char_event_cat IS select * from xmltable
    (
        '/ROWSET/ROW'
        passing dbms_xmlgen.getXMLType
        (
            'SELECT 
                CAL_CATEGORY_ID,
                CAL_CATEGORY_DESCRIPTION
            FROM PORTAL.TBL_CALENDAR_CATEGORY'
        )
        columns
        CAL_CATEGORY_ID NUMBER(2, 0),
        CAL_CATEGORY_DESCRIPTION  NVARCHAR2(100)
    );
    eventcar long_to_char_event_cat%ROWTYPE;

  CURSOR threadrep IS SELECT 
      curr.THREADID as NEW_THREADID,
      USER_NAME,
      prev.REPLY_MESSAGE,
      REPLY_TIMESTAMP,
      REPLY_ID as TEMP_ID
  FROM PORTAL.TBL_FORUM_REPLY prev
  LEFT JOIN MWP_THREADABLE  curr ON prev.THREAD_ID = curr.TEMP_ID AND curr.TEMP_ORIGIN IS NULL;
  threadreprc threadrep%ROWTYPE;
  
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

    -- PLEASE UPDATE THE MWP_CMSMENU_UK1 TO LOOK FOR DUPLICATE MENULABEL + MENUPARENT INSTEAD OF MENUALBEL ONLY
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
        new_data.MENUID,
        old_data.menu_label,
        old_data.menu_sort_order,
        old_data.menu_status,
        old_data.menu_id,
        old_data.content_id,
        3
    FROM
    portal.tbl_menu_new old_data
    LEFT JOIN mwp_cmsmenu new_data ON old_data.second_level_id = new_data.TEMP_ID AND TEMP_LEVEL = 2
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
        new_data.MENUID,
        old_data.menu_label,
        old_data.menu_sort_order,
        old_data.menu_status,
        old_data.menu_id,
        old_data.content_id,
        4
    FROM
    portal.tbl_menu_new old_data
    LEFT JOIN mwp_cmsmenu new_data ON old_data.MENU_PARENT = new_data.TEMP_ID AND TEMP_LEVEL = 3
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
    DBMS_ERRLOG.create_error_log ('MWP_VIDEO');
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
        TEMP_FILE
    )
    SELECT 
    curr.VIDEOID,
    WEBCAST_FOLDER || '/' || WEBCAST_HTMLFILE as TEMP_PATH
    FROM PORTAL.TBL_WEBCAST prev
    LEFT JOIN MWP.MWP_VIDEO curr on prev.WEBCAST_ID = curr.TEMP_ID;
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
        curr.DLCONTENTID,
        DOWNLOADS_PDF
    FROM PORTAL.TBL_DOWNLOADS prev
    LEFT JOIN MWP.MWP_DLCONTENT curr on curr.TEMP_ID = prev.DOWNLOADS_ID
    WHERE curr.DLCONTENTID IS NOT NULL;
    -- MWP_DLCONTENTFILE END

    -- MWP_CMSBANNER START
    DBMS_ERRLOG.create_error_log ('MWP_CMSBANNER');

    INSERT
    INTO MWP_CMSBANNER
    (
        BANNERSTARTTIME,
        BANNERENDTIME,
        BANNERTITLE,
        BANNERTYPE,
        TEMP_ID
    )
    SELECT 
        TEMPLATE_STARTTIMESTAMP,
        TEMPLATE_ENDTIMESTAMP,
        TEMPLATE_TITLE,
        TEMPLATE_TYPE,
        TEMPLATE_ID as TEMP_ID
    FROM PORTAL.TBL_TEMPLATE_MANAGEMENT
    LOG ERRORS INTO ERR$_MWP_CMSBANNER('INSERT') REJECT LIMIT UNLIMITED;
    -- MWP_CMSBANNER END


    -- MWP_CMSBANNERCONTENT START
    INSERT
    INTO MWP_CMSBANNERCONTENT
    (
        BANNERID,
        TEMP_FILE
    )

    SELECT 
        curr.BANNERID,
        TEMPLATE_FOLDER || '/' || TEMPLATE_IMAGENAME as TEMP_FILE
    FROM PORTAL.TBL_TEMPLATE_MANAGEMENT prev
    LEFT JOIN MWP.MWP_CMSBANNER curr ON prev.TEMPLATE_ID = curr.TEMP_ID;
    -- MWP_CMSBANNERCONTENT END

    -- MWP_FAQCATEGORY START
    DBMS_ERRLOG.create_error_log ('MWP_FAQCATEGORY');
    INSERT
    INTO MWP_FAQCATEGORY
    (
        FAQ_CATEGORY_NAME,
        FAQ_ISPUBLISHED,
        TEMP_ID
    )
    SELECT 
        FAQ_CATEGORY_NAME,
        FAQ_CATEGORY_STATUS,
        FAQ_CATEGORY_ID
    FROM PORTAL.TBL_FAQ_CATEGORY
    LOG ERRORS INTO ERR$_MWP_FAQCATEGORY('INSERT') REJECT LIMIT UNLIMITED;

    OPEN long_to_char_faq_cat;
	LOOP
        FETCH long_to_char_faq_cat INTO rc;
        EXIT WHEN long_to_char_faq_cat%NOTFOUND;
        UPDATE MWP_FAQCATEGORY
        SET FAQ_DESCRIPTION = rc.FAQ_DESCRIPTION
        WHERE TEMP_ID = rc.FAQ_CATEGORY_ID;
    END LOOP;
    -- MWP_FAQCATEGORY END

    -- MWP_FAQ START
    INSERT
    INTO MWP_FAQ
    (
        FAQ_CATEGORY_ID,
        FAQ_QUESTION,
        FAQ_ANSWER,
        FAQ_ISPUBLISHED,
        TEMP_ID
    )
    SELECT
        curr.FAQ_CATEGORY_ID,
        FAQ_QUESTION,
        FAQ_ANSWER_CLOB,
        FAQ_STATUS,
        FAQ_ID
    FROM PORTAL.TBL_FAQS prev
    LEFT JOIN MWP.MWP_FAQCATEGORY curr ON prev.FAQ_CATEGORY_ID = curr.TEMP_ID
    WHERE curr.FAQ_CATEGORY_ID IS NOT NULL;
    -- MWP_FAQ END

    -- MWP_MCGALLERYALBUM START
    DBMS_ERRLOG.create_error_log ('MWP_MCGALLERYALBUM');
    INSERT
    INTO MWP_MCGALLERYALBUM
    (
        ALBUMNAME,
        ALBUMEVENTDATE,
        ISPUBLISHED,
        TEMP_ID
    )
    SELECT 
        GALLERY_ALBUM_NAME,
        GALLERY_ALBUM_EVENT_DATE,
        GALLERY_ALBUM_STATUS,
        GALLERY_ALBUM_ID
    FROM PORTAL.TBL_PHOTO_GALLERY_ALBUM
    LOG ERRORS INTO ERR$_MWP_MCGALLERYALBUM('INSERT') REJECT LIMIT UNLIMITED;
    -- MWP_MCGALLERYALBUM END

    -- MWP_MCGALLERYIMAGE START
    INSERT
    INTO MWP_MCGALLERYIMAGE
    (
        ALBUMID,
        CAPTION,
        ISPUBLISHED,
        TEMP_ID,
        TEMP_FILE
    )
    SELECT
        curr.ALBUMID as ALBUMID,
        GALLERY_IMAGE_CAPTION,
        GALLERY_IMAGE_STATUS,
        GALLERY_IMAGE_ID,
        GALLERY_IMAGE_FILE
    FROM PORTAL.TBL_PHOTO_GALLERY_IMAGE prev
    LEFT JOIN MWP.MWP_MCGALLERYALBUM curr ON prev.GALLERY_IMAGE_ALBUM = curr.TEMP_ID;
    -- MWP_MCGALLERYIMAGE END

    -- MWP_MCPHOTORELEASE START
    INSERT
    INTO MWP_MCPHOTORELEASE
    (
        PHOTOSUBJECT,
        TIMESTAMP,
        ISPUBLISHED,
        TEMP_ID
    )
    SELECT 
        BLOG_SUBJECT,
        BLOG_TIMESTAMP,
        BLOG_STATUS,
        BLOG_ID
    FROM PORTAL.TBL_BLOG
    WHERE BLOG_CATEGORY_ID = 1; --1 = PHOTO RELEASE

    UPDATE
    (
        SELECT 
            curr.PHOTOCAPTION,
            prev.BLOG_MESSAGE_CLOB
        FROM MWP_MCPHOTORELEASE curr
        LEFT JOIN PORTAL.TBL_BLOG prev ON curr.TEMP_ID = prev.BLOG_ID
    )
    SET PHOTOCAPTION = BLOG_MESSAGE_CLOB;
    -- MWP_MCPHOTORELEASE END
    
    -- MWP_MCPHOTORELEASEIMG START
    INSERT
    INTO MWP_MCPHOTORELEASEIMG
    (
        PHOTOID,
        TEMP_PATH
    )
    SELECT 
        PHOTOID,
        PIC_LARGE
    FROM MWP_MCPHOTORELEASE curr
    LEFT JOIN PORTAL.TBL_BLOG_PIC prev ON curr.TEMP_ID = prev.BLOG_ID;
    -- MWP_MCPHOTORELEASEIMG END

    -- MWP_MCSPEECHES START
    INSERT
    INTO MWP_MCSPEECHES
    (
        SPEECHTITLE,
        SPEECHTIMESTAMP,
        ISPUBLISHED,
        TEMP_ID
    )
    SELECT 
        BLOG_SUBJECT,
        BLOG_TIMESTAMP,
        BLOG_STATUS,
        BLOG_ID
    FROM PORTAL.TBL_BLOG 
    WHERE PORTAL.TBL_BLOG.BLOG_CATEGORY_ID = 3;  --3 = SPEECHES

    UPDATE
    (
        SELECT
            curr.SPEECHCONTENT,
            prev.BLOG_MESSAGE_CLOB
        FROM MWP_MCSPEECHES curr
        LEFT JOIN PORTAL.TBL_BLOG prev ON curr.TEMP_ID = prev.BLOG_ID
    )
    SET SPEECHCONTENT = BLOG_MESSAGE_CLOB;
    -- MWP_MCSPEECHES END






    -- MWP_THREADABLE START
    -- CATEGORY START
    INSERT
    INTO MWP_THREADCATEGORY
    (
        THREADCATEGORYNAME,
        THREADCATEGORYISBUILTIN,
        TEMP_ID 
    )
    SELECT
        FORUM_CATEGORY_NAME,
        1,
        FORUM_CATEGORY_ID
    FROM PORTAL.TBL_FORUM_CATEGORY 
    WHERE FORUM_CATEGORY_ID > 0;
    -- CATEGORY END
        -- GENERAL DISCUSSONS START
        
        INSERT
        INTO MWP_THREADABLE
        (
            THREADCATEGORYID,
            THREADTITLE,
            THREADTIMESTAMP,
            THREADABLEAUTHOR,
            THREADISPUBLISHED,
            TEMP_ID
        )
        SELECT 
            curr.THREADCATEGORYID as NEW_CATEGORY_ID,
            THREAD_SUBJECT,
            THREAD_TIMESTAMP,
            USER_NAME,
            THREAD_STATUS,
            THREAD_ID
        FROM PORTAL.TBL_FORUM_THREAD par
        LEFT JOIN PORTAL.TBL_FORUM_CATEGORY chi ON par.THREAD_CATEGORY = chi.FORUM_CATEGORY_ID
        LEFT JOIN MWP_THREADCATEGORY curr ON curr.THREADCATEGORYNAME = 'General Discussion'
        WHERE chi.FORUM_CATEGORY_NAME = 'General Discussions';

        UPDATE 
        (
            SELECT 
                curr.THREADCONTENT,
                prev.THREAD_MESSAGE_CLOB
            FROM MWP_THREADABLE curr
            LEFT JOIN PORTAL.TBL_FORUM_THREAD prev on curr.TEMP_ID = prev.THREAD_ID
            WHERE curr.THREADCATEGORYID = 26
        )
        SET THREADCONTENT = THREAD_MESSAGE_CLOB;
        -- GENERAL DISCUSSONS END


        -- NEWS DISCUSSONS START
        INSERT
        INTO MWP_THREADABLE
        (
            THREADCATEGORYID,
            THREADTITLE,
            THREADTIMESTAMP,
            THREADABLEAUTHOR,
            THREADISPUBLISHED,
            TEMP_ID
        )
        SELECT 
            curr.THREADCATEGORYID as NEW_CATEGORY_ID,
            THREAD_SUBJECT,
            THREAD_TIMESTAMP,
            USER_NAME,
            THREAD_STATUS,
            THREAD_ID
        FROM PORTAL.TBL_FORUM_THREAD par
        LEFT JOIN PORTAL.TBL_FORUM_CATEGORY chi ON par.THREAD_CATEGORY = chi.FORUM_CATEGORY_ID
        LEFT JOIN MWP_THREADCATEGORY curr ON curr.THREADCATEGORYNAME = 'News Discussion'
        WHERE chi.FORUM_CATEGORY_NAME = 'News Discussions';

        UPDATE 
        (
            SELECT 
                curr.THREADCONTENT,
                prev.THREAD_MESSAGE_CLOB
            FROM MWP_THREADABLE curr
            LEFT JOIN PORTAL.TBL_FORUM_THREAD prev on curr.TEMP_ID = prev.THREAD_ID
            WHERE curr.THREADCATEGORYID = 27
        )
        SET THREADCONTENT = THREAD_MESSAGE_CLOB;
        -- NEWS DISCUSSONS END


        -- NEWS ONLY START
        INSERT
        INTO MWP_THREADABLE
        (
            THREADCATEGORYID,
            THREADTITLE,
            THREADTIMESTAMP,
            THREADABLEAUTHOR,
            THREADISPUBLISHED,
            TEMP_ID,
            TEMP_ORIGIN
        )
        
        SELECT 
            27 as THREADCATEGORYID,
            NEWS_TITLE,
            NEWS_TIMESTAMP,
            USER_NAME,
            NEWS_STATUS,
            NEWS_ID as TEMP_ID,
            'NEWS' as TEMP_ORIGIN
        FROM PORTAL.TBL_NEWS 
        WHERE THREAD_ID = 0;
        -- NEWS ONLY END

        -- EVENTS DISCUSSONS START
        INSERT
        INTO MWP_THREADABLE
        (
            THREADCATEGORYID,
            THREADTITLE,
            THREADTIMESTAMP,
            THREADABLEAUTHOR,
            THREADISPUBLISHED,
            TEMP_ID
        )

        SELECT 
            curr.THREADCATEGORYID as NEW_CATEGORY_ID,
            THREAD_SUBJECT,
            THREAD_TIMESTAMP,
            USER_NAME,
            THREAD_STATUS,
            THREAD_ID
        FROM PORTAL.TBL_FORUM_THREAD par
        LEFT JOIN PORTAL.TBL_FORUM_CATEGORY chi ON par.THREAD_CATEGORY = chi.FORUM_CATEGORY_ID
        LEFT JOIN MWP_THREADCATEGORY curr ON curr.THREADCATEGORYNAME = 'Event Discussion'
        WHERE chi.FORUM_CATEGORY_NAME = 'Events Discussions';

        UPDATE 
        (
            SELECT 
                curr.THREADCONTENT,
                prev.THREAD_MESSAGE_CLOB
            FROM MWP_THREADABLE curr
            LEFT JOIN PORTAL.TBL_FORUM_THREAD prev on curr.TEMP_ID = prev.THREAD_ID
            WHERE curr.THREADCATEGORYID = 3
        )
        SET THREADCONTENT = THREAD_MESSAGE_CLOB;
        -- EVENTS DISCUSSONS END

        -- EVENTS ONLY START
        INSERT
        INTO MWP_THREADABLE
        (
            THREADCATEGORYID,
            THREADTITLE,
            THREADTIMESTAMP,
            THREADABLEAUTHOR,
            THREADISPUBLISHED,
            TEMP_ID,
            TEMP_ORIGIN
        )

        SELECT 
            28 as THREADCATEGORYID,
            CAL_SUBJECT,
            CAL_STARTDATE,
            USER_NAME,
            CAL_EVENT_STATUS,
            CAL_NUM AS TEMP_ID,
            'EVENTS' AS TEMP_ORIGIN
        FROM PORTAL.TBL_CALENDAR_EVENT 
        WHERE THREAD_ID = 0;
        -- EVENTS ONLY END


        -- SERVICES START
        INSERT
        INTO MWP_THREADABLE
        (
            THREADCATEGORYID,
            THREADTITLE,
            THREADTIMESTAMP,
            THREADABLEAUTHOR,
            THREADISPUBLISHED,
            TEMP_ID
        )

        SELECT 
            curr.THREADCATEGORYID as NEW_CATEGORY_ID,
            THREAD_SUBJECT,
            THREAD_TIMESTAMP,
            USER_NAME,
            THREAD_STATUS,
            THREAD_ID
        FROM PORTAL.TBL_FORUM_THREAD par
        LEFT JOIN PORTAL.TBL_FORUM_CATEGORY chi ON par.THREAD_CATEGORY = chi.FORUM_CATEGORY_ID
        LEFT JOIN MWP_THREADCATEGORY curr ON curr.THREADCATEGORYNAME = 'Services'
        WHERE chi.FORUM_CATEGORY_NAME = 'Services';


        UPDATE 
        (
            SELECT 
                curr.THREADCONTENT,
                prev.THREAD_MESSAGE_CLOB
            FROM MWP_THREADABLE curr
            LEFT JOIN PORTAL.TBL_FORUM_THREAD prev on curr.TEMP_ID = prev.THREAD_ID
            WHERE curr.THREADCATEGORYID = 29
        )
        SET THREADCONTENT = THREAD_MESSAGE_CLOB;

        -- SERVICES END


        --- COMMENTS AND SUGGESTIONS START
        INSERT
        INTO MWP_THREADABLE
        (
            THREADCATEGORYID,
            THREADTITLE,
            THREADTIMESTAMP,
            THREADABLEAUTHOR,
            THREADISPUBLISHED,
            TEMP_ID
        )

        SELECT 
            30,
            THREAD_SUBJECT,
            THREAD_TIMESTAMP,
            USER_NAME,
            THREAD_STATUS,
            THREAD_ID
        FROM PORTAL.TBL_FORUM_THREAD par
        LEFT JOIN PORTAL.TBL_FORUM_CATEGORY chi ON par.THREAD_CATEGORY = chi.FORUM_CATEGORY_ID
        WHERE chi.FORUM_CATEGORY_NAME = 'Comments and Suggestions';


        UPDATE 
        (
            SELECT 
                curr.THREADCONTENT,
                prev.THREAD_MESSAGE_CLOB
            FROM MWP_THREADABLE curr
            LEFT JOIN PORTAL.TBL_FORUM_THREAD prev on curr.TEMP_ID = prev.THREAD_ID
            WHERE curr.THREADCATEGORYID = 30
        )
        SET THREADCONTENT = THREAD_MESSAGE_CLOB;
        --- COMMENTS AND SUGGESTIONS END
    -- MWP_THREADABLE END

    
    -- MWP_THREADABLEEVENTCAT START
    INSERT
    INTO MWP_THREADABLEEVENTCAT
    (
        EVENTCATEGORYNAME,
        TEMP_ID
    )
    SELECT
        CAL_CATEGORY_NAME,
        CAL_CATEGORY_ID
    FROM PORTAL.TBL_CALENDAR_CATEGORY ;

    OPEN long_to_char_event_cat;
    LOOP
        FETCH long_to_char_event_cat INTO eventcar;
        EXIT WHEN long_to_char_event_cat%NOTFOUND;

        UPDATE MWP_THREADABLEEVENTCAT
        SET EVENTCATEGORYDESC = eventcar.CAL_CATEGORY_DESCRIPTION
        WHERE TEMP_ID = eventcar.CAL_CATEGORY_ID;
    END LOOP;
    -- MWP_THREADABLEEVENTCAT END

    -- MWP_THREADABLEEVENT START
    DBMS_ERRLOG.create_error_log ('MWP_THREADABLEEVENT');

    INSERT
    INTO MWP_THREADABLEEVENT
        (
        THREADID,
        EVENTCATEGORYID,
        EVENTSTARTTIME,
        EVENTENDTIME,
        EVENTURL,
        EVENTPOSTSTARTTIME,
        EVENTPOSTENDTIME,
        TEMP_ID
        )
    SELECT 
        curr.THREADID as NEW_THREAD_ID,
        cat.EVENTCATEGORYID as NEW_CATEGORY_ID,
        CAL_EVENTSTART,
        CAL_EVENTEND,
        CAL_URL,
        CAL_STARTDATE,
        CAL_ENDDATE,
        CAL_NUM as TEMP_ID
    FROM PORTAL.TBL_CALENDAR_EVENT prev
    LEFT JOIN MWP.MWP_THREADABLE curr ON prev.THREAD_ID = curr.TEMP_ID  AND curr.THREADCATEGORYID = 28
    LEFT JOIN MWP.MWP_THREADABLEEVENTCAT cat ON prev.CAL_CATEGORY_ID = cat.TEMP_ID
    WHERE THREAD_ID <> 0
    LOG ERRORS INTO ERR$_MWP_THREADABLEEVENT ('INSERT') REJECT LIMIT UNLIMITED;


    INSERT
    INTO MWP_THREADABLEEVENT
    (
        THREADID,
        EVENTCATEGORYID,
        EVENTSTARTTIME,
        EVENTENDTIME,
        EVENTURL,
        EVENTPOSTSTARTTIME,
        EVENTPOSTENDTIME,
        TEMP_ID
    )
    SELECT 
        THREADID as NEW_THREAD_ID,
        currcat.EVENTCATEGORYID,
        prev.CAL_EVENTSTART,
        prev.CAL_EVENTEND,
        prev.CAL_URL,
        prev.CAL_STARTDATE,
        prev.CAL_ENDDATE,
        prev.CAL_NUM
    FROM MWP_THREADABLE curr
    LEFT JOIN PORTAL.TBL_CALENDAR_EVENT prev ON curr.TEMP_ID = prev.CAL_NUM
    LEFT JOIN MWP_THREADABLEEVENTCAT currcat ON prev.CAL_CATEGORY_ID = currcat.TEMP_ID
    WHERE TEMP_ORIGIN = 'EVENTS'
    LOG ERRORS INTO ERR$_MWP_THREADABLEEVENT ('INSERT') REJECT LIMIT UNLIMITED;

    -- MWP_THREADABLEEVENT END

    -- MWP_THREADABLENEWS START
    INSERT
    INTO MWP_THREADABLENEWS
    (
        THREADID,
        TEMP_ID,
        TEMP_PATH
    )

    SELECT 
        curr.THREADID as NEW_THREAD_ID,
        prev.NEWS_ID as OLD_ID,
        pic.NEWS_PICTURE
    FROM PORTAL.TBL_NEWS prev
    LEFT JOIN MWP.MWP_THREADABLE curr ON prev.THREAD_ID = curr.TEMP_ID
    LEFT JOIN PORTAL.TBL_NEWS_PICTURE pic ON prev.NEWS_ID = pic.NEWS_ID
    WHERE prev.THREAD_ID <> 0;

    INSERT
    INTO MWP_THREADABLENEWS
    (
        THREADID,
        TEMP_ID,
        TEMP_PATH
    )
    SELECT 
        THREADID,
        TEMP_ID AS OLD_ID,
        pic.NEWS_PICTURE
    FROM MWP_THREADABLE curr
    LEFT JOIN PORTAL.TBL_NEWS_PICTURE pic ON pic.NEWS_ID = curr.TEMP_ID
    WHERE TEMP_ORIGIN = 'NEWS';

    UPDATE 
    (
        SELECT 
            prev.NEWS_BODY_CLOB,
            curr.NEWSEXCERP
            
        FROM MWP_THREADABLENEWS curr
        LEFT JOIN PORTAL.TBL_NEWS prev ON prev.NEWS_ID = curr.TEMP_ID
    )
    SET NEWSEXCERP = NEWS_BODY_CLOB;
    -- MWP_THREADABLENEWS END

    -- MWP_THREADABLEREPLY START
    OPEN threadrep;
    LOOP
    FETCH threadrep INTO threadreprc;
    EXIT WHEN threadrep%NOTFOUND;
    INSERT
    INTO MWP_THREADABLEREPLY
    (
        THREADID,
        REPLYAUTHOR,
        REPLYTIMESTAMP,
        TEMP_REPLYCONTENT, --MOVED THE LONG DATA TYPE TO LONG TYPE COLUMN THEN AFTER THE INSERT CHANGED THE TYPE OF THIS TABLE TO CLOB
        TEMP_ID
    )
    VALUES
    (
        threadreprc.NEW_THREADID,
        threadreprc.USER_NAME,
        threadreprc.REPLY_TIMESTAMP,
        threadreprc.REPLY_MESSAGE,
        threadreprc.TEMP_ID
    );
    end loop;
    -- MWP_THREADABLEREPLY END

    -- MWP_THREADCATEGORY

    -- MIGRATE CODES ENDS HERE

    -- MWP_IWANTTO START
    INSERT
    INTO MWP_IWANTTO
    (
        IWANTTOTITLE,
        IWANTTOORDER,
        TEMP_ID
    )

    SELECT 
        ONLINE_FORMS_TITLE,
        ONLINE_FORMS_SORT_ORDER,
        ONLINE_FORMS_ID as TEMP_ID
    FROM PORTAL.TBL_ONLINE_FORMS ;
    -- MWP_IWANTTO END


    -- MWP_IWANTTODTL START
        -- REQUIREMENT START
            INSERT
            INTO MWP_IWANTTODTL
            (
                IWANTTOID,
                DTLTYPE,
                DTLCONTENT
            )

            SELECT 
                curr.IWANTTOID as NEW_ID,
                'REQUIREMENT',
                clob_to_blob(ONLINE_FORMS_REQUIREMENTS)
            FROM PORTAL.TBL_ONLINE_FORMS prev
            LEFT JOIN MWP.MWP_IWANTTO curr ON prev.ONLINE_FORMS_ID = curr.TEMP_ID;
        -- REQUIREMENT END
        -- PROCEDURES START
            INSERT
            INTO MWP_IWANTTODTL
            (
                IWANTTOID,
                DTLTYPE,
                DTLCONTENT
            )

            SELECT 
                curr.IWANTTOID as NEW_ID,
                'PROCEDURE',
                clob_to_blob(ONLINE_FORMS_PROCEDURES)
            FROM PORTAL.TBL_ONLINE_FORMS prev
            LEFT JOIN MWP.MWP_IWANTTO curr ON prev.ONLINE_FORMS_ID = curr.TEMP_ID;
        -- PROCEDURES END
        -- APPLICATIONFORMS START
        INSERT
        INTO MWP_IWANTTODTL
        (
            IWANTTOID,
            DTLTYPE,
            TEMP_FILE
        )
        
        SELECT 
            curr.IWANTTOID as NEW_ID,
            'APPLICATIONFORM',
            ONLINE_FORMS_FILE
        FROM PORTAL.TBL_ONLINE_FORMS prev
        LEFT JOIN MWP.MWP_IWANTTO curr ON prev.ONLINE_FORMS_ID = curr.TEMP_ID;
        -- APPLICATIONFORMS END
    -- MWP_IWANTTODTL END
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







    