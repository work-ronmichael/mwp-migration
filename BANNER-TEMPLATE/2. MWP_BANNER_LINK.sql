begin
  for o in (SELECT BANNER_ID, TEMP_ID FROM MWP_BANNER_TEMPLATE)
  loop
    EXECUTE IMMEDIATE '
    INSERT INTO MWP_BANNER_LINK
    (
      BANNER_URL,
      BANNER_URL_POSITION,
      BANNER_ID,
      TEMP_ID
    )
    SELECT 
      TEMPLATE_URL,
      TEMPLATE_URL_POSITION,
      '||  o.BANNER_ID ||',
      TEMPLATE_URL_ID
    FROM PORTAL.TBL_TEMPLATE_LINK WHERE TEMPLATE_ID = ' || o.TEMP_ID;
  end loop;
end;