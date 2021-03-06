--------------------------------
INSERT
  INTO MWP_EVENT_CALENDAR
  (
    EVENT_CAL_TIMESTAMP,
    EVENT_CAL_START_POST,
    EVENT_CAL_END_POST,
    EVENT_CAL_TYPE,
    EVENT_CAL_USERNAME,
    EVENT_CAL_URL,
    EVENT_CAL_SUBJECT,
    EVENT_CAL_START_DATE,
    EVENT_CAL_END_DATE,
    EVENT_CAL_ISPUBLISHED,
    EVENT_CAL_ISDELETED,
    TEMP_ID,
    EVENT_CAL_CATEGORY_ID,
    EVENT_CAL_FORUM_THREAD_ID
  )
  SELECT 
    CAL_CALENDAR_ID as EVENT_CAL_TIMESTAMP,
    CAL_STARTDATE as EVENT_CAL_START_POST,
    CAL_ENDDATE as EVENT_CAL_END_POST,
    CAL_EVENT_TYPE as EVENT_CAL_TYPE,
    USER_NAME as EVENT_CAL_USERNAME,
    CAL_URL as EVENT_CAL_URL,
    CAL_SUBJECT as EVENT_CAL_SUBJECT,
    CAL_EVENTSTART as EVENT_CAL_START_DATE,
    CAL_EVENTEND as EVENT_CAL_END_DATE,
    1 as EVENT_CAL_ISPUBLISHED,
    0 as EVENT_CAL_ISDELETED,
    CAL_NUM as TEMP_ID,
    cat.EVENT_CAL_CATEGORY_ID as EVENT_CAL_CATEGORY_ID,
    forum.FORUM_THREAD_ID as EVENT_CAL_FORUM_THREAD_ID
  FROM PORTAL.TBL_CALENDAR_EVENT por
  LEFT JOIN MWP_EVENT_CALENDAR_CATEGORY cat ON cat.TEMP_ID = por.CAL_CATEGORY_ID
  LEFT JOIN MWP_FORUM_THREAD forum ON forum.TEMP_ID = por.THREAD_ID;
LOG ERRORS INTO ERR$_MWP_EVENT_CALENDAR ('INSERT') REJECT LIMIT UNLIMITED;



--------------------------------
begin
  for o in (SELECT CAL_NUM,CAL_DESCRIPTION_CLOB FROM PORTAL.TBL_CALENDAR_EVENT)
  loop
    UPDATE MWP_EVENT_CALENDAR
    SET EVENT_CAL_DESCRIPTION = o.CAL_DESCRIPTION_CLOB
    WHERE TEMP_ID = o.CAL_NUM;
  end loop;
end;


