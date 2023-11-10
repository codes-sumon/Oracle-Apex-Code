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