--PRE REQUISITE MWP_DOWNLOADS_CATEGORY


--IMPORT CONTENT FOR CATEGORY
begin
  for o in (SELECT DOWNLOADS_CATEGORY_ID, TEMP_ID FROM MWP_DOWNLOADS_CATEGORY where TEMP_TYPE = 'CATEGORY')
  loop
    EXECUTE IMMEDIATE '
    INSERT INTO MWP_DOWNLOADS_CONTENT
    (
        DOWNLOADS_CONTENT_CATEGORY_ID,
        DOWNLOADS_CONTENT_TITLE,
        DOWNLOADS_CONTENT_DESCRIPTION,
        DOWNLOADS_CONTENT_LINK,
        DOWNLOADS_CONTENT_ISPUBLISHED,
        DOWNLOADS_CONTENT_ISDELETED,
        DOWNLOADS_CONTENT_TIMESTAMP,
        DOWNLOADS_CONTENT_ROW,
        TEMP_ID,
        TEMP_PDF,
        TEMP_THUMB,
        TEMP_ORIGIN
    )


    SELECT 
        '|| o.DOWNLOADS_CATEGORY_ID ||',
        DOWNLOADS_TITLE,
        DOWNLOADS_DESC,
        DOWNLOADS_LINK,
        1,
        0,
        DOWNLOADS_TIMESTAMP,
        DOWNLOADS_SORT_ORDER,
        DOWNLOADS_ID,
        DOWNLOADS_PDF,
        DOWNLOADS_THUMB,
        ''CATEGORY''
    FROM PORTAL.TBL_DOWNLOADS WHERE DOWNLOADS_CATEGORY = ' || o.TEMP_ID;
  end loop;
end;




--IMPORT CONTENT OF SUBCATEGORY
begin
  for o in (SELECT DOWNLOADS_CATEGORY_ID, TEMP_ID FROM MWP_DOWNLOADS_CATEGORY where TEMP_TYPE = 'SUB-CATEGORY')
  loop
    EXECUTE IMMEDIATE '
    INSERT INTO MWP_DOWNLOADS_CONTENT
    (
        DOWNLOADS_CONTENT_CATEGORY_ID,
        DOWNLOADS_CONTENT_TITLE,
        DOWNLOADS_CONTENT_DESCRIPTION,
        DOWNLOADS_CONTENT_LINK,
        DOWNLOADS_CONTENT_ISPUBLISHED,
        DOWNLOADS_CONTENT_ISDELETED,
        DOWNLOADS_CONTENT_TIMESTAMP,
        DOWNLOADS_CONTENT_ROW,
        TEMP_ID,
        TEMP_PDF,
        TEMP_THUMB,
        TEMP_ORIGIN
    )


    SELECT 
        '|| o.DOWNLOADS_CATEGORY_ID ||',
        DOWNLOADS_TITLE,
        DOWNLOADS_DESC,
        DOWNLOADS_LINK,
        1,
        0,
        DOWNLOADS_TIMESTAMP,
        DOWNLOADS_SORT_ORDER,
        DOWNLOADS_ID,
        DOWNLOADS_PDF,
        DOWNLOADS_THUMB,
        ''SUB-CATEGORY''
    FROM PORTAL.TBL_DOWNLOADS WHERE DOWNLOADS_SUBCATEGORY = ' || o.TEMP_ID;
  end loop;
end;