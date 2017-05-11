begin
  for o in (SELECT DOWNLOADS_CONTENT_ID, TEMP_ID FROM MWP_DOWNLOADS_CONTENT)
  loop
    EXECUTE IMMEDIATE '
    INSERT INTO MWP_DOWNLOADS_FILE
    (
      DOWNLOADS_FILE_CONTENT_ID,
      TEMP_ID,
      TEMP_FILE
    )


    SELECT 
        '|| o.DOWNLOADS_CONTENT_ID ||',
        TEMP_ID,
        TEMP_PDF
    FROM MWP_DOWNLOADS_CONTENT WHERE TEMP_PDF IS NOT NULL AND TEMP_ID = '|| o.TEMP_ID;
  end loop;
end;
