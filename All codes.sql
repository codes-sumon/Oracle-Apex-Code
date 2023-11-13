--Link a item
javascript:$s("P2_CAT_ID", "#CAT_NO#");


--collection create
IF NOT APEX_COLLECTION.COLLECTION_EXISTS ('ITEM_DETAILS') THEN
    APEX_COLLECTION.CREATE_COLLECTION('ITEM_DETAILS');
ELSE
    APEX_COLLECTION.TRUNCATE_COLLECTION ('ITEM_DETAILS');
END IF;


--save into a collection
DECLARE
    vSEQID NUMBER := 0;
    V_ITEM_QTY NUMBER :=0;
    V_TOTAL_PRICE NUMBER :=0;
BEGIN
    IF NOT APEX_COLLECTION.COLLECTION_EXISTS ('ITEM_DETAILS')
    THEN
        APEX_COLLECTION.CREATE_COLLECTION ('ITEM_DETAILS');
    END IF;
    
    FOR r IN (SELECT SEQ_ID,  N001 ITEM_QTY, N003 TOTAL_PRICE
              FROM APEX_COLLECTIONS
              WHERE COLLECTION_NAME = 'ITEM_DETAILS' AND C001 = :P3_ITEM)
    LOOP
        vSEQID := r.SEQ_ID;
        V_ITEM_QTY := r.ITEM_QTY;
        V_TOTAL_PRICE := r.TOTAL_PRICE;
        EXIT;
    END LOOP;
    -- MAINTAIN COLLECTION
    IF :P3_ITEM IS NOT NULL
    THEN
        IF :P3_ITEM_QTY > 0
        THEN
            IF vSEQID = 0  THEN
                APEX_COLLECTION.ADD_MEMBER (
                    P_COLLECTION_NAME   => 'ITEM_DETAILS',
                    P_C001              => :P3_ITEM,
                    P_N001              => :P3_ITEM_QTY,
                    P_N002              => :P3_UNIT_PRICE,
                    P_N003              => :P3_TOTAL_PRICE -- P_SUBTOTALP_SUBTOTAL 
                    );
            ELSE
                APEX_COLLECTION.UPDATE_MEMBER (
                    P_COLLECTION_NAME   => 'ITEM_DETAILS',
                    P_SEQ               => VSEQID,
                    P_C001              => :P3_ITEM,
                    P_N001              => :P3_ITEM_QTY + V_ITEM_QTY,
                    P_N002              => :P3_UNIT_PRICE,
                    P_N003              => :P3_TOTAL_PRICE  + V_TOTAL_PRICE-- P_SUBTOTALP_SUBTOTAL 
                    );
            END IF;
            COMMIT;
        END IF;
    END IF;
	BEGIN
    SELECT SUM(NVL(N003,0)) INTO :P3_SUB_TOTAL --calculate total 
        FROM   APEX_COLLECTIONS 
        WHERE  COLLECTION_NAME = 'ITEM_DETAILS';
    EXCEPTION
        WHEN OTHERS THEN
            :P3_SUB_TOTAL := 0;
    END;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR (-20001, SQLERRM);
END;
  



  ---remove from collection
BEGIN
    BEGIN
        APEX_COLLECTION.DELETE_MEMBER (P_COLLECTION_NAME   => 'ITEM_DETAILS',
                                       P_SEQ               => :P3_SEQ_ID);
        apex_collection.resequence_collection( p_collection_name => 'ITEM_DETAILS');
    END;

    BEGIN
        SELECT  SUM(NVL(N003,0))
                INTO :P3_SUB_TOTAL
          FROM APEX_COLLECTIONS
         WHERE COLLECTION_NAME = 'ITEM_DETAILS';
    END;

END;


---- CLASS 4 

CREATE TABLE PUR_MST(
    PUR_ID NUMBER CONSTRAINT PUR_MST_PK PRIMARY KEY,
    PUR_CODE VARCHAR2(30),
    CUS_NAME VARCHAR2(150),
    CUS_PHONE VARCHAR2(15),
    CUS_ADDS VARCHAR2(200)
)

ALTER TABLE PUR_MST
ADD TOTAL_DISCOUNT NUMBER

ALTER TABLE PUR_MST
ADD GRAND_TOTAL_AMOUNT NUMBER

ALTER TABLE PUR_MST
ADD SUB_TOTAL NUMBER

CREATE TABLE PUR_DTL(
    PUR_DTL_ID NUMBER CONSTRAINT PUR_DTL_ID_PK PRIMARY KEY,
    PUR_MST_ID NUMBER,
    SL_NO NUMBER,
    ITEM_ID NUMBER,
    ITEM_QTY NUMBER,
    ITEM_PRICE NUMBER,
    TOTAL_AMOUNT NUMBER)

--success message
apex_application.g_print_success_message := 'Save successfully';

--error message
apex_error.add_error
(   p_message               => 'Already advice created for this!!',
    p_display_location      => apex_error.c_inline_in_notification
);


---MASTER DETAILS INSERT CODE
DECLARE
    V_PUR_ID NUMBER := 0;
    V_PUR_DTL_ID NUMBER := 0;
    V_PUR_CODE VARCHAR2(20);
BEGIN
    SELECT NVL(MAX(PUR_ID),0)+1
    INTO V_PUR_ID
    FROM PUR_MST;

    SELECT 'INV-'||TO_CHAR(SYSDATE, 'YYYYMMDD')||'-'||LPAD(V_PUR_ID,5, '0')
    INTO V_PUR_CODE
    FROM DUAL;

    INSERT INTO PUR_MST(PUR_ID, PUR_CODE, CUS_NAME, CUS_PHONE, CUS_ADDS, SUB_TOTAL, TOTAL_DISCOUNT, GRAND_TOTAL_AMOUNT)
    VALUES(V_PUR_ID, V_PUR_CODE, :P3_CUS_NAME, :P3_PHONE_NUMBER, :P3_ADDRESS, :P3_SUB_TOTAL, :P3_DISCOUNT, :P3_GRAND_TOTAL);

    FOR I IN (SELECT  SEQ_ID SEQ_ID,
                        C001 ITEM_ID,
                        N001 ITEM_QTY,
                        N002 UNIT_PRICE,
                        N003 TOTAL_PRICE
                FROM APEX_COLLECTIONS 
                WHERE COLLECTION_NAME = 'ITEM_DETAILS'
                ORDER BY SEQ_ID ASC)
    LOOP
        SELECT NVL(MAX(PUR_DTL_ID),0)+1
        INTO V_PUR_DTL_ID
        FROM PUR_DTL;
        INSERT INTO PUR_DTL(PUR_DTL_ID, PUR_MST_ID, SL_NO, ITEM_ID, ITEM_QTY, ITEM_PRICE, TOTAL_AMOUNT)
                    VALUES(V_PUR_DTL_ID, V_PUR_ID, I.SEQ_ID, I.ITEM_ID, I.ITEM_QTY, I.UNIT_PRICE, I.TOTAL_PRICE);
    END LOOP;
    

    :P3_MESSAGE := 'Invoice Save: '||V_PUR_CODE;
    -- apex_error.add_error
    --     (   p_message               => 'Invoice Save: '||V_PUR_CODE,
    --         p_display_location      => apex_error.c_inline_in_notification
    --     );
END;



--class 5
--master save
BEGIN
    IF NVL(:P4_TOTAL,0) > 0 AND  NVL(:P4_GRAND_TOTAL_AMOUNT,0) > 0 THEN
        UPDATE PUR_MST
        SET CUS_NAME = :P4_CUS_NAME,
            CUS_PHONE = :P4_PHN,
            CUS_ADDS =  :P4_ADD,
            SUB_TOTAL = :P4_TOTAL, 
            TOTAL_DISCOUNT = :P4_DISCOUNT,
            GRAND_TOTAL_AMOUNT = :P4_GRAND_TOTAL_AMOUNT
        WHERE PUR_ID = :P4_PUR_MST_ID;
    ELSE
        apex_error.add_error
        (   p_message               => 'Total and Grand total must be gatter then 0',
            p_display_location      => apex_error.c_inline_in_notification
        );
    END IF;
END;

---details save

declare 
    V_PUR_DTL_ID number;
BEGIN
    IF NVL(:P4_TOTAL,0) > 0 AND  NVL(:P4_GRAND_TOTAL_AMOUNT,0) > 0 THEN
        case :APEX$ROW_STATUS
            when 'C' then
                SELECT NVL(MAX(PUR_DTL_ID),0)+1
                INTO V_PUR_DTL_ID
                FROM PUR_DTL;
                
                INSERT INTO PUR_DTL(PUR_DTL_ID, PUR_MST_ID, SL_NO, ITEM_ID, ITEM_QTY, ITEM_PRICE, TOTAL_AMOUNT)
                    VALUES(V_PUR_DTL_ID, :P4_PUR_MST_ID, :SL_NO, :ITEM_ID, :ITEM_QTY, :ITEM_PRICE, :TOTAL_AMOUNT);
                    
            when 'U' then
                 UPDATE PUR_DTL
                    SET  ITEM_ID = :ITEM_ID,
                        ITEM_QTY = :ITEM_QTY,
                        ITEM_PRICE = :ITEM_PRICE,
                        TOTAL_AMOUNT = :TOTAL_AMOUNT
                    WHERE PUR_MST_ID = :P4_PUR_MST_ID
                    and PUR_DTL_ID = :PUR_DTL_ID;

            when 'D' then
                delete from PUR_DTL
                WHERE PUR_MST_ID = :P4_PUR_MST_ID
                and PUR_DTL_ID = :PUR_DTL_ID;
        end case;
    ELSE
        apex_error.add_error
        (   p_message               => 'Total and Grand total must be gatter then 0',
            p_display_location      => apex_error.c_inline_in_notification
        );
    END IF;
END;





--not nessery 

BEGIN
   IF NOT APEX_COLLECTION.COLLECTION_EXISTS ('LC_DTL_LOAD') THEN        
        APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY (
        P_COLLECTION_NAME   => 'LC_DTL_LOAD',
        P_QUERY             => 'select  SEQ_ID AS SEQ_NO,
                                        ITEM_ID,
                                        ITEM_QTY,
                                        ITEM_QTY,
                                        UNIT_PRICE,
                                        TOTAL_PRICE,
                                        PI_DTL
                                    from PI_Details
                                WHERE PI_ID = '|| :P31_PI_CODE ||' ORDER BY SEQ_NO');
    ELSE
        APEX_COLLECTION.DELETE_COLLECTION ('LC_DTL_LOAD');
        APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY (
        P_COLLECTION_NAME   => 'LC_DTL_LOAD',
        P_QUERY             => 'select  SEQ_ID AS SEQ_NO,
                                        ITEM_ID,
                                        ITEM_QTY,
                                        ITEM_QTY,
                                        UNIT_PRICE,
                                        TOTAL_PRICE,
                                        PI_DTL
                                    from PI_Details
                                WHERE PI_ID = '|| :P31_PI_CODE ||' ORDER BY SEQ_NO');
    END IF;
