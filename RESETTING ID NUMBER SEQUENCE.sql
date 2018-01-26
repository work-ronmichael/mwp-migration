
DECLARE
l_val NUMBER;
BEGIN
    execute immediate 'select SEQ_NEWS_ID.nextval from dual' INTO l_val;
    execute immediate  'alter sequence SEQ_NEWS_ID increment by -' || l_val || ' minvalue 0';
    execute immediate 'select SEQ_NEWS_ID.nextval from dual' INTO l_val;
    execute immediate 'alter sequence SEQ_NEWS_ID increment by 1 minvalue 0';
END;



--ALL SEQUENCES
DECLARE
    l_val NUMBER;
BEGIN
    for x in (select sequence_name from USER_SEQUENCES)
    loop
        execute immediate 'select '|| x.sequence_name ||'.nextval from dual' INTO l_val;
        execute immediate 'alter sequence '|| x.sequence_name ||' increment by -' || l_val || ' minvalue 0';
        execute immediate 'select '|| x.sequence_name ||'.nextval from dual' INTO l_val;
        execute immediate 'alter sequence  '|| x.sequence_name ||' increment by 1 minvalue 0';
    end loop;
END;


