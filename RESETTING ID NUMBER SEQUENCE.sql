
DECLARE
l_val NUMBER;

BEGIN

    execute immediate 'select SEQ_NEWS_ID.nextval from dual' INTO l_val;

    execute immediate  'alter sequence SEQ_NEWS_ID increment by -' || l_val || ' minvalue 0';

    execute immediate 'select SEQ_NEWS_ID.nextval from dual' INTO l_val;

    execute immediate 'alter sequence SEQ_NEWS_ID increment by 1 minvalue 0';
END;


