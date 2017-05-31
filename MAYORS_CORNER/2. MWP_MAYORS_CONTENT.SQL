begin
  for o in (SELECT MC_CATEGORY_ID,TEMP_ID FROM MWP_MAYORS_CORNER_CATEGORY)
  loop
    EXECUTE IMMEDIATE '
    INSERT
    INTO MWP_MAYORS_CORNER
      (
        MC_SUBJECT,
        MC_CONTENT,
        MC_TIMESTAMP,
        MC_ISCOMMENTALLOWED,
        MC_USERNAME,
        MC_CATEGORY_ID,
        MC_ISPUBLISHED,
        MC_ISDELETED,
        TEMP_ID
      )
    SELECT 
      BLOG_SUBJECT,
      BLOG_MESSAGE_CLOB,
      BLOG_TIMESTAMP,
      BLOG_ALLOW_COMMENTS,
      USER_NAME,
      '|| o.MC_CATEGORY_ID ||',
      1 as ispublished,
      0 as isdeleted,
      BLOG_ID
    FROM PORTAL.TBL_BLOG WHERE BLOG_CATEGORY_ID ='|| o.TEMP_ID;
  end loop;
end;