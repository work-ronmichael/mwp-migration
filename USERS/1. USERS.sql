INSERT
INTO USERS
  (
    USERNAME,
    USERFULLNAME,
    USEREMAIL,
    PASSWORD,
    DATECREATED,
    PASSWORDFAILCOUNT,
    PASSWORDFORMAT,
    ISAPPROVED,
    ISLOCKEDOUT,
    ISDELETED,
    TEMP_CONFIRMED
  )
SELECT 
  USER_NAME,
  CONCAT(USER_FNAME,USER_LNAME)as fullname,
  USER_EMAIL,
  USER_PASSWORD,
  SYSDATE as datecreated,
  0 as passwordfailcount,
  0 as passwordformat,
  1 as isapproved,
  0 as islockedout,
  0 as isdeleted,
  USER_CONFIRMED
FROM PORTAL.TBL_USERS ;
  
  