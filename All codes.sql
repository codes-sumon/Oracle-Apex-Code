--select All
<input type="checkbox" onClick="toggle(this)" />
function toggle(source) {
  checkboxes = document.getElementsByName('f01');
  for(var i=0, n=checkboxes.length;i<n;i++) {
    checkboxes[i].checked = source.checked;
    // console.log(i);
  }
}
--

APEX_ITEM.RADIOGROUP (1,A.VC_NO) RADIOGROUP
APEX_ITEM.CHECKBOX (1,A.VC_NO) CHECKBOX

APEX_APPLICATION.G_F01(i);
APEX_APPLICATION.G_F01.count > 0 

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


----directory file save
BEGIN
    UTL_FILE.FREMOVE ('EMP_PHOTO_DIR',:P256_EMP_ID||'.jpg');
EXCEPTION
    WHEN OTHERS THEN
    NULL;
END;

DECLARE
    l_blob BLOB;
BEGIN
    IF :P256_EMP_PHOTO IS NOT NULL THEN
        select BLOB_CONTENT
             INTO l_blob
             FROM apex_application_temp_files
             where NAME = :P256_EMP_PHOTO;          

        blob_to_file(p_blob       => l_blob,
                     p_dir        => 'EMP_PHOTO_DIR',
                     p_filename =>  :P256_EMP_ID||'.jpg'
                    );
    ELSE
        RAISE_APPLICATION_ERROR(-20777,'Select a Photo!');
    END IF;
END;
--
create or replace PROCEDURE           blob_to_file (p_blob      IN OUT NOCOPY BLOB,
                                          p_dir       IN  VARCHAR2,
                                          p_filename  IN  VARCHAR2)
AS
  l_file      UTL_FILE.FILE_TYPE;
  l_buffer    RAW(32767);
  l_amount    BINARY_INTEGER := 32767;
  l_pos       INTEGER := 1;
  l_blob_len  INTEGER;
BEGIN
  l_blob_len := DBMS_LOB.getlength(p_blob);
  l_file := UTL_FILE.fopen(p_dir, p_filename,'WB', 32767);
WHILE l_pos <= l_blob_len LOOP
    DBMS_LOB.read(p_blob, l_amount, l_pos, l_buffer);
    UTL_FILE.put_raw(l_file, l_buffer, TRUE);
    l_pos := l_pos + l_amount;
  END LOOP;
  UTL_FILE.fclose(l_file);
EXCEPTION
  WHEN OTHERS THEN
    IF UTL_FILE.is_open(l_file) THEN
       UTL_FILE.fclose(l_file);
    END IF;
    RAISE;
END blob_to_file; 


---- CUSTOM AUTHENTICATION
function AUTH_USER(P_USERNAME VARCHAR2,P_PASSWORD VARCHAR2) RETURN BOOLEAN 
    IS V_COUNT NUMBER;
BEGIN 
    SELECT COUNT(USER_ID) 
    INTO V_COUNT 
    FROM MY_USERS
    WHERE IS_ACTIVE = 'Y'
    AND TRIM(USER_NAME)=TRIM(P_USERNAME) 
    AND TRIM(USER_PASSWORD)=TRIM(P_PASSWORD);

    IF V_COUNT >= 1 THEN
        RETURN TRUE;
    ELSE 
        RETURN FALSE;
    END IF;
END;

----
  CREATE TABLE "MY_USERS" 
   ("USER_ID" NUMBER(20), 
	"USER_NAME" VARCHAR2(50), 
	"FULL_NAME" VARCHAR2(100), 
	"PHONE_NUMBER" VARCHAR2(15), 
	"EMAIL_ADDRESS" VARCHAR2(25), 
	"USER_TYPE" VARCHAR2(25), 
	"SHOP_CATEGORY" VARCHAR2(50), 
	"IS_ACTIVE" VARCHAR2(10), 
	"USER_PASSWORD" VARCHAR2(100), 
	"CREATED_BY" VARCHAR2(50), 
	"CREATE_DATE" DATE,
    "UPDATE_BY" DATE, 
	"UPDATE_DATE" DATE, 
	 CONSTRAINT "MY_UID_PK" PRIMARY KEY ("USER_ID")
  USING INDEX  ENABLE
   ) ;


var spinner = apex.util.showSpinner();

$("#apex_wait_overlay").remove();
$(".u-Processing").remove(); 


-----Record declare
DECLARE
   TYPE DeptRecTyp IS RECORD (
      deptno departments.department_id%TYPE,
      dname  departments.department_name%TYPE,
      loc    departments.location_id%TYPE );
   dept_rec DeptRecTyp;
BEGIN
   SELECT department_id, department_name, location_id INTO dept_rec
      FROM departments WHERE department_id = 20;
END;
/


--------------- EXCEL FILE UPLOAD CODE----
DECLARE
V_SEQ NUMBER;
begin
SELECT NVL(MAX(SEQ_ID),0)+1 INTO V_SEQ FROM TEMP_ROSTER_EMP WHERE USER_ID = :APP_USER;
IF :P279_EMP_ID_FILE IS NOT NULL THEN
    DELETE FROM TEMP_ROSTER_EMP WHERE USER_ID = :APP_USER;
END IF;



for r1 in (select *  from
                    apex_application_temp_files f, table( apex_data_parser.parse(
                                    p_content                     => f.blob_content,
                                    p_skip_rows => 1,
                                    p_add_headers_row             => 'Y',
                                   -- p_store_profile_to_collection => 'FILE_PROV_CASH',
                                    p_file_name                   => f.filename ) ) p
                where      f.name = :P279_EMP_ID_FILE  --Page Item name
                )
        
        LOOP
                                            
            INSERT INTO TEMP_ROSTER_EMP(ROS_EMP_ID,USER_ID, SEQ_ID)
            VALUES(r1.col001,:APP_USER,V_SEQ);
        END LOOP;
        
END;

--classic report header fixed
<div style ="overflow-x: scroll;overflow-y: scroll;height:550px;">
</div>
table thead, table tfoot {
  position: sticky;
  z-index: 10; 
}

table thead {
  inset-block-start: 0;
}

table tfoot {
  inset-block-end: 0; 
  background-color: white; 
}


/* .t-Report-report thead tr th{
    background-color: red ;
} */

.t-Report-colHead{
    background-color: rgb(10, 131, 161) !important;
    /* font-weight: 300; */
}


-----Download Static File--------
function download(url, filename) {
  fetch(url)
    .then(response => response.blob())
    .then(blob => {
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = filename;
      link.click();
  })
  .catch(console.error);
}

download("#APP_FILES#JVBill_Upload.xlsx","JVBill_Upload.xlsx")
--done