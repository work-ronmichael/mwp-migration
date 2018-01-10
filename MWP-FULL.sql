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

	-- MWP_ERR_CMSCONTENT START
	INSERT
    INTO ERR_MWP_CMSCONTENT
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
    WHERE curr.MENUID IS NULL;
	
	UPDATE ERR_MWP_CMSCONTENT
    SET CONTENTDETAIL = 
    (
        SELECT 
            CONTENT_DETAILS
        FROM PORTAL.TBL_MENU_CONTENT_NEW 
        WHERE ERR_MWP_CMSCONTENT.TEMP_ID = PORTAL.TBL_MENU_CONTENT_NEW.CONTENT_ID
    );


    -- CASCADE THE UNPUBLISHED STATUS TO ITS TREE
    for x in (SELECT MENUID, MENUPARENT, MENULABEL, MENUORDER, ISPUBLISHED FROM mwp_cmsmenu START WITH menuid = menuparent CONNECT BY NOCYCLE PRIOR menuid = menuparent ORDER BY menuorder, menuparent)
    loop
    
        if x.ISPUBLISHED = 0 THEN
            for y in (SELECT MENUID, MENUPARENT, MENULABEL, MENUORDER, ISPUBLISHED FROM mwp_cmsmenu START WITH menuid = x.MENUID CONNECT BY NOCYCLE PRIOR menuid = menuparent ORDER BY menuorder, menuparent)
            loop
                UPDATE mwp_cmsmenu SET ISPUBLISHED = 0 WHERE MENUID = y.MENUID;
            end loop;
        END IF;
    end loop;


	-- MWP_ERR_CMSCONTENT END
	
	
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

    UPDATE MWP_CMSCONTENT
    SET CONTENTDETAIL = 
    (
        SELECT 
            CONTENT_DETAILS
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

	
	
	
	
	-- START INSERT ERR_MWP_VIDEOFILE 
	INSERT
    INTO ERR_MWP_VIDEOFILE
    (
        VIDEOID,
        TEMP_FILE
    )
    SELECT 
    curr.VIDEOID,
    WEBCAST_FOLDER || '/' || WEBCAST_HTMLFILE as TEMP_PATH
    FROM PORTAL.TBL_WEBCAST prev
    LEFT JOIN MWP.MWP_VIDEO curr on prev.WEBCAST_ID = curr.TEMP_ID
    WHERE VIDEOID IS NULL;
	-- END INSERT ERR_MWP_VIDEOFILE
	
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
	WHERE VIDEOID IS NOT NULL;
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
    INTO ERR_MWP_DLCONTENTFILE
    (
        DLCONTENTID,
        TEMP_FILE
    )
    SELECT 
        curr.DLCONTENTID,
        DOWNLOADS_PDF
    FROM PORTAL.TBL_DOWNLOADS prev
    LEFT JOIN MWP.MWP_DLCONTENT curr on curr.TEMP_ID = prev.DOWNLOADS_ID
    WHERE curr.DLCONTENTID IS NULL;
	
	-- SELECT THE MAX VERSION PRIOR TO INSERT
    INSERT INTO mwp.mwp_dlcontentfile (
		dlcontentid,
		temp_file,
		temp_version,
		temp_id
	)
	select 
		curr.DLCONTENTID,
		PDF_NAME as temp_file,
		VERSION_ID as temp_version,
		downloads_id as temp_id
	from (
		SELECT
			dl.downloads_id as downloads_id,
			dl.downloads_title as downloads_title,
			re.PDF_NAME as PDF_NAME,
			vs.VERSION_ID,
			max(vs.VERSION_ID) over (partition by dl.downloads_id) as latest_version
		FROM
			portal.tbl_downloads dl
		LEFT join portal.tbl_downloads_version vs ON dl.DOWNLOADS_ID = vs.DOWNLOADS_ID
		LEFT join portal.tbl_downloads_pdf re ON vs.VERSION_ID = re.VERSION_ID 
	) prev
	LEFT JOIN MWP.MWP_DLCONTENT curr on curr.TEMP_ID = prev.DOWNLOADS_ID
	WHERE VERSION_ID = latest_version 
	AND curr.DLCONTENTID IS NOT NULL
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
	INTO ERR_MWP_FAQ
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
	WHERE curr.FAQ_CATEGORY_ID IS NULL;
		
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
        GALLERY_ALBUM_DATE,
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

    -- GALLERY ALBUM ADD THUMBNAIL ON FEATURED
    for x in (SELECT
            new_img.ALBUMID as NEW_ALBUMID,
            new_img.imageid as NEW_IMAGE_ID
          FROM
              portal.tbl_photo_gallery_image old_img
          LEFT JOIN mwp_mcgalleryimage new_img ON old_img.GALLERY_IMAGE_ID = new_img.TEMP_ID
          WHERE gallery_image_status = 2)
    loop
    
            UPDATE MWP_MCGALLERYALBUM
            SET ALBUMTHUMBNAIL = x.NEW_IMAGE_ID, ISFEATURED = 1
            WHERE ALBUMID = x.NEW_ALBUMID;
    end loop;
    -- GALLERY ALBUM ADD THUMBNAIL ON FEATURED


    -- GALLERY ALBUM ADD THUMBNAIL NON FEATURED
    for x in (SELECT
                    album.ALBUMID,
                    img.img.IMAGEID
                FROM
                    mwp_mcgalleryalbum album
                LEFT JOIN mwp_mcgalleryimage img ON album.albumid = img.ALBUMID AND rownum = 1
                WHERE isfeatured = 0)
    loop
        UPDATE mwp_mcgalleryalbum SET ALBUMTHUMBNAIL = x.IMAGEID  WHERE albumid = x.ALBUMID;
    end loop;
    -- GALLERY ALBUM ADD THUMBNAIL NON FEATURED

    -- ADD GALLERY ALBUM
    UPDATE (

    SELECT
        TEMP_FOLDER,
        temp_id ||
        to_char(albumeventdate,  'yyyymmdd')
        AS NEW_TEMP_FOLDER
    FROM
        mwp_mcgalleryalbum
    )
    set TEMP_FOLDER = NEW_TEMP_FOLDER
    -- END GALLERY ALBUM

    
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

    -- REMOVE THE up folder from releaseimg
    for x in (SELECT photoid, REPLACE(temp_path, '../uploads/', '') as new_path FROM mwp_mcphotoreleaseimg WHERE temp_path like '../uploads%' )
    loop
        UPDATE mwp_mcphotoreleaseimg SET temp_path = x.new_path WHERE photoid = x.photoid;
    end loop;
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
        LEFT JOIN MWP_THREADCATEGORY curr ON curr.THREADCATEGORYNAME = 'General Discussions'
        WHERE chi.FORUM_CATEGORY_NAME = 'General Discussions';

        UPDATE 
		(
		   SELECT 
				curr.THREADCONTENT,
				prev.THREAD_MESSAGE_CLOB
			FROM MWP_THREADABLE curr
			LEFT JOIN PORTAL.TBL_FORUM_THREAD prev on curr.TEMP_ID = prev.THREAD_ID
			LEFT JOIN mwp_threadcategory cat on cat.threadcategoryid = curr.THREADCATEGORYID
			WHERE cat.THREADCATEGORYNAME = 'General Discussions'
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
			LEFT JOIN mwp_threadcategory cat on cat.threadcategoryid = curr.THREADCATEGORYID
			WHERE cat.THREADCATEGORYNAME = 'News Discussions'
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
            cat.threadcategoryid,
            NEWS_TITLE,
            NEWS_TIMESTAMP,
            USER_NAME,
            NEWS_STATUS,
            NEWS_ID as TEMP_ID,
            'NEWS_NO_THREAD' as TEMP_ORIGIN
        FROM PORTAL.TBL_NEWS
        LEFT JOIN mwp_threadcategory cat on cat.THREADCATEGORYNAME = 'News Discussions'
        WHERE  PORTAL.TBL_NEWS.THREAD_ID = 0

        for x in (SELECT news_id,news_body_clob FROM portal.tbl_news WHERE THREAD_ID = 0)
        loop
            UPDATE mwp_threadable
            SET threadcontent = x.news_body_clob
            WHERE TEMP_ID = x.news_id AND TEMP_ORIGIN =  'NEWS_NO_THREAD';
        end loop;

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
			LEFT JOIN mwp_threadcategory cat on cat.threadcategoryid = curr.THREADCATEGORYID
			WHERE cat.THREADCATEGORYNAME = 'Events Discussions'
		)
		SET THREADCONTENT = THREAD_MESSAGE_CLOB;
        -- EVENTS DISCUSSONS END
		
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
			LEFT JOIN mwp_threadcategory cat on cat.threadcategoryid = curr.THREADCATEGORYID
			WHERE cat.THREADCATEGORYNAME = 'Services'
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
			cat.threadcategoryid,
			THREAD_SUBJECT,
			THREAD_TIMESTAMP,
			USER_NAME,
			THREAD_STATUS,
			THREAD_ID
		FROM PORTAL.TBL_FORUM_THREAD par
		LEFT JOIN PORTAL.TBL_FORUM_CATEGORY chi ON par.THREAD_CATEGORY = chi.FORUM_CATEGORY_ID
		LEFT JOIN mwp_threadcategory cat ON cat.THREADCATEGORYNAME = 'Comments and Suggestions'
		WHERE chi.FORUM_CATEGORY_NAME = 'Comments and Suggestions';

        UPDATE
        (
            SELECT 
				curr.THREADCONTENT,
				prev.THREAD_MESSAGE_CLOB
			FROM MWP_THREADABLE curr
			LEFT JOIN PORTAL.TBL_FORUM_THREAD prev on curr.TEMP_ID = prev.THREAD_ID
			LEFT JOIN mwp_threadcategory cat ON cat.THREADCATEGORYID = curr.THREADCATEGORYID
			WHERE cat.THREADCATEGORYNAME = 'Comments and Suggestions'
        )
        SET THREADCONTENT = THREAD_MESSAGE_CLOB;
        --- COMMENTS AND SUGGESTIONS END		
		
		--- START CALENDAR EVENTS
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
			cat.THREADCATEGORYID as THREADCATEGORYID,
			cal_subject as THREADTITLE,
			cal_eventstart as THREADTIMESTAMP,
			user_name as THREADABLEAUTHOR,
			cal_event_status as THREADISPUBLISHED,
			cal_num AS TEMP_ID,
			'CALENDAR_EVENTS' as TEMP_ORIGIN
		FROM
			portal.tbl_calendar_event
		LEFT JOIN MWP_THREADCATEGORY cat ON cat.THREADCATEGORYNAME = 'Events Discussions'
		WHERE THREAD_ID = 0;
		
		for x in (SELECT cal_num, CAL_DESCRIPTION_CLOB FROM portal.tbl_calendar_event WHERE THREAD_ID = 0)
		loop

			UPDATE mwp_threadable
			SET threadcontent = x.CAL_DESCRIPTION_CLOB
			WHERE TEMP_ID = x.cal_num AND TEMP_ORIGIN =  'CALENDAR_EVENTS';
		end loop;
		
		--- END CALENDAR EVENTS
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
	-- START UPDATE THE EVENTS WITH ORIGINAL THREAD
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
    LEFT JOIN MWP.MWP_THREADABLE curr ON prev.THREAD_ID = curr.TEMP_ID 
    LEFT JOIN MWP.MWP_THREADABLEEVENTCAT cat ON prev.CAL_CATEGORY_ID = cat.TEMP_ID
    WHERE prev.thread_id > 0
    LOG ERRORS INTO ERR$_MWP_THREADABLEEVENT ('INSERT') REJECT LIMIT UNLIMITED;
    -- END UPDATE THE EVENTS WITH ORIGINAL THREAD

    -- START INSERT THE EVENTS WITHOUT ORIGINAL THREAD
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
    LEFT JOIN MWP.MWP_THREADABLE curr ON prev.CAL_NUM = curr.TEMP_ID AND curr.TEMP_ORIGIN = 'CALENDAR_EVENTS'
    LEFT JOIN MWP.MWP_THREADABLEEVENTCAT cat ON prev.CAL_CATEGORY_ID = cat.TEMP_ID
    WHERE prev.thread_id = 0
    LOG ERRORS INTO ERR$_MWP_THREADABLEEVENT ('INSERT') REJECT LIMIT UNLIMITED;
    -- END INSERT THE EVENTS WITHOUT ORIGINAL THREAD
    -- MWP_THREADABLEEVENT END









    -- MWP_THREADABLENEWS START xxx
	-- START INSERT NO ORIG THREAD TO MWP_THREADABLENEWS
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
    LEFT JOIN MWP.MWP_THREADABLE curr ON prev.NEWS_ID = curr.TEMP_ID AND curr.TEMP_ORIGIN = 'NEWS_NO_THREAD'
    LEFT JOIN PORTAL.TBL_NEWS_PICTURE pic ON prev.NEWS_ID = pic.NEWS_ID
    WHERE prev.THREAD_ID = 0;
    -- END INSERT NO ORIG THREAD TO MWP_THREADABLENEWS

    -- START INSERT HAS ORIG THREAD TO MWP_THREADABLENEWS
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
    LEFT JOIN MWP_THREADCATEGORY cat ON cat.THREADCATEGORYNAME = 'News Discussions'
    LEFT JOIN MWP.MWP_THREADABLE curr ON prev.THREAD_ID = curr.TEMP_ID AND curr.THREADCATEGORYID = cat.THREADCATEGORYID
    LEFT JOIN PORTAL.TBL_NEWS_PICTURE pic ON prev.NEWS_ID = pic.NEWS_ID
    WHERE prev.THREAD_ID > 0 AND curr.THREADTITLE = prev.NEWS_TITLE;
    -- END INSERT HAS ORIG THREAD TO MWP_THREADABLENEWS


    -- ERROR TABLES
     INSERT
    INTO ERR_MWP_THREADABLENEWS
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
    LEFT JOIN MWP_THREADCATEGORY cat ON cat.THREADCATEGORYNAME = 'News Discussions'
    LEFT JOIN MWP.MWP_THREADABLE curr ON prev.THREAD_ID = curr.TEMP_ID AND curr.THREADCATEGORYID = cat.THREADCATEGORYID
    LEFT JOIN PORTAL.TBL_NEWS_PICTURE pic ON prev.NEWS_ID = pic.NEWS_ID
    WHERE prev.THREAD_ID > 0 AND curr.THREADTITLE <> prev.NEWS_TITLE;
    -- ERROR TABLES
    


    -- UPDATE CONTENT
    UPDATE 
    (
        SELECT 
            prev.NEWS_BODY_CLOB,
            curr.NEWSEXCERP
            
        FROM MWP_THREADABLENEWS curr
        LEFT JOIN PORTAL.TBL_NEWS prev ON prev.NEWS_ID = curr.TEMP_ID
    )
    SET NEWSEXCERP = NEWS_BODY_CLOB;
    -- UPDATE CONTENT
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
        REPLYCONTENT, --MOVED THE LONG DATA TYPE TO LONG TYPE COLUMN THEN AFTER THE INSERT CHANGED THE TYPE OF THIS TABLE TO CLOB
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
    DBMS_ERRLOG.create_error_log ('MWP_IWANTTO');
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
    LOG ERRORS INTO ERR$_MWP_IWANTTO ('INSERT') REJECT LIMIT UNLIMITED;
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
                ONLINE_FORMS_REQUIREMENTS
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
                ONLINE_FORMS_PROCEDURES
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







    












