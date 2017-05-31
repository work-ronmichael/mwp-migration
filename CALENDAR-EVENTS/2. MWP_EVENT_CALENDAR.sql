

--PRE REQUISITE

--MWP_EVENT_CALENDAR_CATEGORY
--MWP_FORUM_THREAD






















INSERT
INTO MWP_EVENT_CALENDAR
  (
    EVENT_CAL_TIMESTAMP,
    EVENT_CAL_START_POST,
    EVENT_CAL_END_POST,
    EVENT_CAL_TYPE,
    EVENT_CAL_USERNAME,
    EVENT_CAL_DESCRIPTION,
    EVENT_CAL_URL,


    EVENT_CAL_CATEGORY_ID,


    EVENT_CAL_FORUM_THREAD_ID,


    EVENT_CAL_SUBJECT,
    EVENT_CAL_START_DATE,
    EVENT_CAL_END_DATE,
    EVENT_CAL_ISPUBLISHED,
    EVENT_CAL_ISDELETED,
    TEMP_ID
  )






SELECT 
  
  CAL_CALENDAR_ID,
  CAL_STARTDATE,
  CAL_ENDDATE,
  CAL_EVENT_TYPE,
  USER_NAME,
  CAL_DESCRIPTION,
  CAL_URL,
  CAL_CATEGORY_ID,
  THREAD_ID,
  
  CAL_DESCRIPTION_CLOB,

  CAL_SUBJECT,
  CAL_EVENTSTART,
  CAL_EVENTEND,
  CAL_EVENT_STATUS,
  0,




  CAL_NUM
FROM PORTAL.TBL_CALENDAR_EVENT ;