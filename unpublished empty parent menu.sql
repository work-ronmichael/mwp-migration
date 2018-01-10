set serveroutput on
declare
childrenCount NUMBER;
contentCount NUMBER;
begin   
for x in (SELECT MENUID FROM MWP_CMSMENU WHERE ISPUBLISHED = 1)
    loop
        -- FIND PARENT MENU
        EXECUTE IMMEDIATE 'SELECT count(*) FROM MWP_CMSMENU WHERE MENUPARENT = ' ||  X.MENUID || '  and MENUID <>  ' || X.MENUID  into childrenCount;
        IF childrenCount = 0 THEN
        
            -- FIND CONTENT OF FOUND PARENT MENU
            EXECUTE IMMEDIATE 'SELECT count(*) FROM mwp_cmscontent WHERE menuid = ' || X.MENUID into contentCount;
                IF contentCount = 0 THEN
                    dbms_output.put_line(X.MENUID);
                    --UPDATE mwp_cmsmenu SET ispublished = 0 WHERE menuid = X.MENUID;
                END IF;
		END IF;
    end loop;
end;