begin
  for o in (SELECT MAKATI_VIDEO_ID, TEMP_ID FROM MWP_MAKATI_VIDEOS )
  loop
    EXECUTE IMMEDIATE '
    INSERT
    INTO MWP_MAKATI_VIDEO_FILE
      (
        MAKATI_VIDEO_ID,
        TEMP_ID,
        TEMP_FILE,
        TEMP_FOLDER
      )
    SELECT 
      '|| o.MAKATI_VIDEO_ID ||',
      '|| o.TEMP_ID ||',
      WEBCAST_HTMLFILE,
      WEBCAST_FOLDER
    FROM PORTAL.TBL_WEBCAST WHERE WEBCAST_ID =' || o.TEMP_ID;
  end loop;
end;



