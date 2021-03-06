DECLARE 
	CURSOR c IS SELECT BLOG_CATEGORY_NAME,BLOG_DESCRIPTION,BLOG_CATEGORY_ID FROM PORTAL.TBL_BLOG_CATEGORY ;
	rc c%ROWTYPE;
BEGIN
	OPEN c;
	LOOP
	FETCH c INTO rc;
	EXIT WHEN c%NOTFOUND;
  
  INSERT INTO MWP_MAYORS_CORNER_CATEGORY(
    MC_CATEGORY_NAME,
    MC_CATEGORY_DESCRIPTION,
    TEMP_ID
  )
  VALUES(rc.BLOG_CATEGORY_NAME,rc.BLOG_DESCRIPTION,rc.BLOG_CATEGORY_ID);
END LOOP;	
COMMIT;
END;