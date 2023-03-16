---------------- Library ---------------- 
SELECT *
FROM LIB_BOOK_DP;
SELECT *
FROM LIB_RESERVATION_CS lrc;
SELECT *
FROM LIB_MEMBER_CS lmc;
SELECT *
FROM LIB_RENTAL_DP lrd ;
SELECT *
FROM LIB_BOOK_COPY_DP lbcd ;

/*
ZADATAK: MODELIRANJE SUSTAVA KNJIŽNICE
Potrebno je napraviti model podataka koji definira sustav knjižnice.
Sustav knjižnice:
Za posuđivanje knjiga u knjižnici potrebno je biti �?lanom knjižnice, tj. imati �?lansku iskaznicu. Članarina
je na godišnjoj bazi, plaća se unaprijed i vrijedi godinu dana od dana uplate. Djeca mlađa od 15 godina
ne plaćaju �?lanarinu. U nekom trenutku dozvoljeno je imati posuđene maksimalno 3 knjige. Rok za
vraćanje knjiga/e je 15 dana. Ukoliko se knjiga/e ne vrate u zadanom roku, plaća se zakasnina u iznosu
0,5kn/dan/knjiga. U knjižnici postoji više kopija iste knjige. Moguća je rezervacija knjiga – �?lana se SMSom obavijesti o raspoloživosti knjige, a rok za posuđivanje rezervirane knjige je 3 dana. Ukoliko se
rezervirana knjiga u tom roku ne posudi, rezervacija se briše.
Zadaci:
• Definirati sve tablice i kolone potrebne za funkcioniranje gore opisane knjižnice
• Definirati veze (relacije) između tablica (entiteta) te odrediti njihovu kardinalnost (1:1, 1:n, m:n)
• Po želji skicirati ER (entity-relationship) dijagram koji definira veze između tablica (nadogradnja
prethodne to�?ke)
• Definirati sve primarne i strane klju�?eve na tablicama, kao i check constraint-e
• Napuniti sve tablice sa primjernim podacima (10-15 redaka po tablici)
• Primjenom do sada nau�?enog i po uzoru na rješenje videoteke iz prethodnih zadataka, potrebno
je kreirati paket sa svim funkcijama i procedurama koje će omogućiti rad gore opisane knjižnice
 */
----------------------------------------------------
CREATE SEQUENCE LIB_MEMBER_ID_SEQ_DP
 START WITH     100
 INCREMENT BY   1
 NOCACHE
 NOCYCLE;

CREATE SEQUENCE LIB_MEMBERSHIP_SEQ_DP
 START WITH     100
 INCREMENT BY   1
 NOCACHE
 NOCYCLE;
----------------------------------------------------

--spec
CREATE OR REPLACE PACKAGE LIBRARY_DP AS
    PROCEDURE LIB_NEW_MEMBER_DP(
		   p_LAST_NAME IN NEO_WH_EDU.LIB_MEMBER_DP.LAST_NAME%TYPE,
		   p_FIRST_NAME IN NEO_WH_EDU.LIB_MEMBER_DP.FIRST_NAME%TYPE,
		   p_ADDRESS IN NEO_WH_EDU.LIB_MEMBER_DP.ADDRESS%TYPE,
		   p_CITY IN NEO_WH_EDU.LIB_MEMBER_DP.CITY%TYPE,
		   p_PHONE IN NEO_WH_EDU.LIB_MEMBER_DP.PHONE%TYPE,
		   p_JOIN_DATE IN NEO_WH_EDU.LIB_MEMBER_DP.JOIN_DATE%TYPE DEFAULT SYSTIMESTAMP);

	PROCEDURE LIB_RESERVE_BOOK_DP
	    (BOOK_id_in IN NEO_WH_EDU.LIB_BOOK_DP.BOOK_ID%TYPE,
	 	MEMBER_ID_in IN NEO_WH_EDU.LIB_MEMBER_DP.MEMBER_ID%TYPE);  
        
	PROCEDURE LIB_RETURN_BOOK_DP
	     (title_id_in IN NEO_WH_EDU.LIB_BOOK_COPY_DP.title_id%TYPE,
	     copy_id_in IN NEO_WH_EDU.LIB_BOOK_COPY_DP.copy_id%TYPE,
	     status_in in NEO_WH_EDU.LIB_BOOK_COPY_DP.status%type);
	
	PROCEDURE LIB_CLEAN_RESERVATIONS_DP;
    
    FUNCTION LIB_BOOK_RENTAL_DP(p_book_title_id NUMBER, p_member_id NUMBER) RETURN date;
   
    PROCEDURE LIB_CHECK_RESERVATIONS_DP
     (title_id_in IN NEO_WH_EDU.LIB_BOOK_COPY_DP.title_id%TYPE);
		
END LIBRARY_DP;

--body
CREATE OR REPLACE PACKAGE BODY LIBRARY_DP AS

--EXCEPTION_HANDLER
PROCEDURE EXCEPTION_HANDLER (
    error_code_in IN number,
    program_name_in IN varchar2)
IS
	 e_pk_violation EXCEPTION;
	 e_fk_violation EXCEPTION;
	 PRAGMA EXCEPTION_INIT(e_pk_violation, -1);
	 PRAGMA EXCEPTION_INIT(e_fk_violation, -2291);
	BEGIN
	 IF error_code_in= -1 THEN
     dbms_output.put_line('Primary key violation!' );
	 RAISE e_pk_violation;
	 ELSE
	    IF error_code_in = -2291 THEN
            dbms_output.put_line('Foreign key violation!' );
	        RAISE e_fk_violation;
            
        ELSE
            DBMS_OUTPUT.PUT_LINE
	      ('EXCEPTION_HANDLER caught: -> Error code: ' || error_code_in || 
	        ' in program:  ' || program_name_in);
            END IF;
	 END IF;

END EXCEPTION_HANDLER; 

--CREATE MEMBER
PROCEDURE LIB_NEW_MEMBER_DP(
		   p_LAST_NAME IN NEO_WH_EDU.LIB_MEMBER_DP.LAST_NAME%TYPE,
		   p_FIRST_NAME IN NEO_WH_EDU.LIB_MEMBER_DP.FIRST_NAME%TYPE,
		   p_ADDRESS IN NEO_WH_EDU.LIB_MEMBER_DP.ADDRESS%TYPE,
		   p_CITY IN NEO_WH_EDU.LIB_MEMBER_DP.CITY%TYPE,
		   p_PHONE IN NEO_WH_EDU.LIB_MEMBER_DP.PHONE%TYPE,
		   p_JOIN_DATE IN NEO_WH_EDU.LIB_MEMBER_DP.JOIN_DATE%TYPE DEFAULT SYSTIMESTAMP)
	AS
        v_code  NUMBER;
        v_errm  VARCHAR2(64);
	    BEGIN
	        INSERT INTO LIB_MEMBER_DP(MEMBER_ID, LAST_NAME, FIRST_NAME, ADDRESS, CITY, 
	                                PHONE, JOIN_DATE)
	        VALUES (LIB_MEMBER_ID_SEQ_DP.NEXTVAL, p_LAST_NAME, p_FIRST_NAME, p_ADDRESS, p_CITY,
	                            p_PHONE, p_JOIN_DATE);
	        COMMIT;
END LIB_NEW_MEMBER_DP;

--RESERVE BOOK
PROCEDURE LIB_RESERVE_BOOK_DP
    (BOOK_id_in IN NEO_WH_EDU.LIB_BOOK_DP.BOOK_ID%TYPE,
 	MEMBER_ID_in IN NEO_WH_EDU.LIB_MEMBER_DP.MEMBER_ID%TYPE)
IS
    v_number_of_rented_titles number;
    v_code  NUMBER;
    v_errm  VARCHAR2(64);
	BEGIN
		 SELECT count(*)
	     INTO v_number_of_rented_titles
		 FROM NEO_WH_EDU.LIB_BOOK_COPY_DP
		 WHERE TITLE_ID=BOOK_id_in AND status in ('AVAILABLE' , 'DAMAGED');
		 --if it isn't avalale or damaged and it's id is in table it has to be rented

		 IF v_number_of_rented_titles = 0 THEN 
		 INSERT INTO LIB_RESERVATION_DP VALUES (BOOK_id_in, MEMBER_ID_in, sysdate, sysdate+3);
		 			dbms_output.put_line('The book is reservated and 
						expected day of book avalivility is: ' || TO_CHAR(sysdate+3) );
					COMMIT;
		 ELSE
		 	dbms_output.put_line('Can not make reservation - the book is avalable for rent or damaged!');
         END IF;
        
         EXCEPTION
             WHEN NO_DATA_FOUND THEN
                 dbms_output.put_line ('No book found!');
          WHEN OTHERS THEN
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 64);
            EXCEPTION_HANDLER(v_code, v_errm);
             	
END LIB_RESERVE_BOOK_DP;

--RENT BOOK
FUNCTION LIB_BOOK_RENTAL_DP(p_book_title_id NUMBER, p_member_id NUMBER)
RETURN date AS
    return_date date;
    title_copy_status varchar2(12);
    v_copy_id number;
    v_code  NUMBER;
    v_errm  VARCHAR2(64);
    v_member_has_membership int; -- is membership valid
    v_days_of_valid_membership int:= 0;
    v_number_of_rented_books int := 0;
    
   BEGIN 
	  --check status of book copy
      SELECT status, copy_id
      INTO title_copy_status, v_copy_id
	  FROM LIB_BOOK_COPY_DP
	  WHERE TITLE_ID=p_book_title_id
	  FETCH FIRST 1 ROWS ONLY; 
      
      --check if has membership
      SELECT count(*)
      into v_member_has_membership
      FROM LIB_MEMBERSHIP_DP 
      where member_id = p_member_id;
      
      --save number of days of payed membership
      if v_member_has_membership>0 then
          SELECT VALID_UNTIL_DATE - sysdate
          into v_days_of_valid_membership
          FROM LIB_MEMBERSHIP_DP 
          where member_id = p_member_id;
      end if;
      
      --save number of books not returned by member
      SELECT count(*)
      INTO v_number_of_rented_books
      FROM NEO_WH_EDU.LIB_RENTAL_DP
      WHERE MEMBER_ID = p_member_id AND
      ACT_RET_DATE IS NULL; -- IF its NULL it means he hasn't returned it yet
      
      --first check membership
      IF v_days_of_valid_membership < 0 then
        dbms_output.put_line ('Member with id:' || p_member_id ||
        ' has invalid or unpayed membership');
        return null;
    
      ELSE
      
      IF title_copy_status = 'AVAILABLE'
            AND v_number_of_rented_books < 3 THEN
	  		UPDATE LIB_BOOK_COPY_DP  set STATUS='RENTED'
	  		WHERE p_book_title_id = title_id and rownum = 1;
			INSERT INTO NEO_WH_EDU.LIB_RENTAL_DP
			(RENT_DATE, ACT_RET_DATE ,EXP_RET_DATE, TITLE_ID,MEMBER_ID, copy_id)
			VALUES
			(SYSDATE, NULL,SYSDATE + 15, p_book_title_id, p_member_id, v_copy_id);
			COMMIT;
			return_date := SYSDATE + 15;
      ELSE
	        --dbms_output.put_line ('The book with title id:' || p_book_title_id || ' is rented or damaged');
	  		LIB_RESERVE_BOOK_DP(p_book_title_id, p_member_id);
	 		RETURN NULL;
      end if;
      end if;
      return return_date;
        EXCEPTION
          WHEN OTHERS THEN
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 64);
            EXCEPTION_HANDLER(v_code, v_errm); --internal procedure
END LIB_BOOK_RENTAL_DP;

PROCEDURE LIB_RETURN_BOOK_DP
     (title_id_in IN NEO_WH_EDU.LIB_BOOK_COPY_DP.title_id%TYPE,
     copy_id_in IN NEO_WH_EDU.LIB_BOOK_COPY_DP.copy_id%TYPE,
     status_in in NEO_WH_EDU.LIB_BOOK_COPY_DP.status%type)
IS
	v_latency_fee NUMBER;
	v_rent_date date;
    title_copy_status varchar2(12);
    v_code  NUMBER;
    v_errm  VARCHAR2(64);
	BEGIN
		 SELECT status
	     INTO title_copy_status
		 FROM NEO_WH_EDU.LIB_BOOK_COPY_DP
		 WHERE TITLE_ID=title_id_in AND COPY_ID = copy_id_in;
		 IF title_copy_status = 'RENTED' THEN
		 	dbms_output.put_line('The book with title id:' || title_id_in ||
            ' was RENTED' || ' and now its: ' || status_in );
		 END IF;
		 
		 SELECT RENT_DATE
	     INTO v_rent_date
		 FROM NEO_WH_EDU.LIB_RENTAL_DP
		 WHERE TITLE_ID=title_id_in AND COPY_ID = copy_id_in and ACT_RET_DATE is null;
         -- added and ACT_RET_DATE is null to ignore already returned books

         IF sysdate > (v_rent_date + 15) then
             v_latency_fee := round(sysdate - (v_rent_date + 15)) * 0.5;
            --round to upper
		 	dbms_output.put_line('CUSTOMER HAS TO PAY
            LATENCY FEE:' || v_latency_fee ||  ' KN - BECAUSE HE WAS LATE:'
                || to_char(round(sysdate - (v_rent_date + 15))) || ' DAYS!');
             update NEO_WH_EDU.LIB_RENTAL_DP
             set LATENCY_FEE = v_latency_fee
             where title_id = title_id_in
             and copy_id = copy_id_in;
             COMMIT;
		 END IF;
         
		 update NEO_WH_EDU.LIB_RENTAL_DP
		 set act_ret_date = sysdate
		 where title_id = title_id_in
		 and copy_id = copy_id_in;
		 update NEO_WH_EDU.LIB_BOOK_COPY_DP
		 set status = status_in
		 where title_id = title_id_in
		 and copy_id = copy_id_in;
		 --if there's reservarion for given book - inform the oldest reservation, call the customer and refresh
		 LIB_CHECK_RESERVATIONS_DP(title_id_in);
		 COMMIT;
         
        EXCEPTION
          WHEN OTHERS THEN
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 64);
            EXCEPTION_HANDLER(v_code, v_errm);
            
END LIB_RETURN_BOOK_DP;

PROCEDURE LIB_CLEAN_RESERVATIONS_DP IS
    rows_deleted VARCHAR2(50);
    BEGIN
    
    DELETE
    FROM
        NEO_WH_EDU.LIB_RESERVATION_DP
    WHERE
        RESERVATION_EXP < SYSDATE;

    rows_deleted := (SQL%ROWCOUNT ||' expired reservations deleted.');
    DBMS_OUTPUT.PUT_LINE(rows_deleted);
   
    COMMIT;

END LIB_CLEAN_RESERVATIONS_DP;

PROCEDURE LIB_CHECK_RESERVATIONS_DP
     (title_id_in IN NEO_WH_EDU.LIB_BOOK_COPY_DP.title_id%TYPE)
IS
    v_code  NUMBER;
    v_errm  VARCHAR2(64);
    v_member_id_to_inform NUMBER;
    v_phone varchar2(30);

	BEGIN
        SELECT member_id
        into v_member_id_to_inform
        FROM LIB_RESERVATION_DP lrd 
        WHERE TITLE_ID = title_id_in
        ORDER BY RESERVATION_DATE  ASC 
        FETCH FIRST ROW ONLY;
        
        if v_member_id_to_inform is not null then
            select PHONE
            into v_phone
            from lib_member_dp
            where member_id=v_member_id_to_inform;
            
            UPDATE LIB_RESERVATION_DP set RESERVATION_EXP=sysdate
            WHERE MEMBER_ID = v_member_id_to_inform
            AND rownum = 1;
            commit;
            
            dbms_output.put_line('Call' || v_phone);
        else 
            dbms_output.put_line('There is no
            reservations for id:' || title_id_in);
        end if;

         
        EXCEPTION
          WHEN OTHERS THEN
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 64);
            EXCEPTION_HANDLER(v_code, v_errm);
            
END LIB_CHECK_RESERVATIONS_DP;

END LIBRARY_DP;  

----------------------TEST----------------------
BEGIN
LIBRARY_DP.LIB_NEW_MEMBER_DP ('Zeljko', 'Pervan', 'Chestnut Street', 'Boston', '617-123-4567');
LIBRARY_DP.LIB_NEW_MEMBER_DP ('Zlatan', 'Zuhric', 'Hiawatha Drive', 'New York', '516-123-4567');
END;

BEGIN
DBMS_OUTPUT.PUT_LINE(LIBRARY_DP.LIB_BOOK_RENTAL_DP(1, 100)); --title member
END;
BEGIN
DBMS_OUTPUT.PUT_LINE(LIBRARY_DP.LIB_BOOK_RENTAL_DP(3, 100));
END;
BEGIN
-- since there is no more copies left - member 101 will have the reservation for book 3
DBMS_OUTPUT.PUT_LINE(LIBRARY_DP.LIB_BOOK_RENTAL_DP(3, 101));
END;
BEGIN
--member with id 104 has not payed membership so it renturnes message
DBMS_OUTPUT.PUT_LINE(LIBRARY_DP.LIB_BOOK_RENTAL_DP(3, 104));
END;

BEGIN
LIBRARY_DP.LIB_RETURN_BOOK_DP(3, 1, 'AVAILABLE'); -- title, copy, staus
END;

-- we will change the dates to invoke latency fee charging for member 100 for book 3 copy 1
UPDATE NEO_WH_EDU.LIB_RENTAL_DP
SET RENT_DATE = sysdate - 50
WHERE TITLE_ID  =3 AND COPY_ID =1;
COMMIT;
BEGIN
LIBRARY_DP.LIB_RETURN_BOOK_DP(3, 1, 'AVAILABLE');
END;

commit

--cleaning up reservations that has expired with message how many have we deleted (alter reservation exp first)
BEGIN
LIBRARY_DP.LIB_CLEAN_RESERVATIONS_DP;
END;

----------------Helper code----------------
SELECT *
FROM LIB_BOOK_DP;
SELECT *
FROM LIB_RESERVATION_CS lrc;
SELECT *
FROM LIB_MEMBER_CS lmc;
SELECT *
FROM LIB_RENTAL_DP lrd ;
SELECT *
FROM LIB_BOOK_COPY_DP lbcd ;

