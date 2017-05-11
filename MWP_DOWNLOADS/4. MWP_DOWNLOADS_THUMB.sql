begin
  for o in (SELECT DOWNLOADS_CONTENT_ID, TEMP_ID FROM MWP_DOWNLOADS_CONTENT WHERE TEMP_THUMB IS NOT NULL)
  loop
    EXECUTE IMMEDIATE '
    INSERT INTO MWP_DOWNLOADS_THUMB
    (
      DOWNLOADS_THUMB_CONTENT_ID,
      TEMP_ID,
      TEMP_FILE
    )


    SELECT 
        '|| o.DOWNLOADS_CONTENT_ID ||',
        TEMP_ID,
        TEMP_THUMB
    FROM MWP_DOWNLOADS_CONTENT WHERE TEMP_ID = '|| o.TEMP_ID;
  end loop;
end;
