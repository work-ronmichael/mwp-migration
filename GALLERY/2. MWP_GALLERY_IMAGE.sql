begin
  for o in (SELECT ALBUM_ID, TEMP_ID FROM MWP_GALLERY_ALBUM)
  loop
    EXECUTE IMMEDIATE '
    INSERT
	INTO MWP_GALLERY_IMAGE
	  (
	    IMAGE_FILE,
	    IMAGE_DESCRIPTION,
	    IMAGE_ALBUM_ID,
	    IMAGE_TIMESTAMP,
	    IMAGE_ISDELETED,
	    IMAGE_ISFEATURED,
	    IMAGE_USERNAME,
	    TEMP_ID
	  )

	SELECT   
	  GALLERY_IMAGE_FILE,
	  GALLERY_IMAGE_CAPTION,
	  '|| o.ALBUM_ID ||',
	  GALLERY_IMAGE_DATE,
	  0,
	  0,
	  USER_NAME,
	  GALLERY_IMAGE_ID
	FROM PORTAL.TBL_PHOTO_GALLERY_IMAGE WHERE GALLERY_IMAGE_ALBUM = '|| o.TEMP_ID;
  end loop;
end;








