CREATE OR REPLACE PROCEDURE APPL_PMIS.PRC_ATTENDANCE_PROCESS_BY_SUMON
AS
BEGIN
    BEGIN
        MERGE INTO  PUNCH_MECHINE_RAW_DATA A
        USING  qrypunchrawdata_appl@HSLINKHR B 
        ON (A.ID = B."intID")
        WHEN MATCHED THEN    
        UPDATE SET
            PUNCH_USER_ID                      = "intPunchUserID", 
            PUNCH_DATE                         = "dteDate",
            PUNCH_TIME                         = "dtetime", 
            STR_VER                          = "strVer", 
            YSN_IO                           = "ysnIO", 
            WORK_CODE                        = "strWorkCode", 
            FROM_MACHINE_ID                    = "strFormMechineIP",        
            ENTRY_DATE                      = "dteEntryDatetime"
            WHERE "dteDate" BETWEEN TRUNC(SYSDATE,'MON') AND LAST_DAY(TRUNC(SYSDATE,'MON'))        
        WHEN NOT MATCHED THEN
            INSERT (PUNCH_USER_ID, PUNCH_DATE, PUNCH_TIME, STR_VER, YSN_IO, WORK_CODE, FROM_MACHINE_ID, ID, ENTRY_DATE)
            VALUES ("intPunchUserID","dteDate","dtetime","strVer","ysnIO","strWorkCode","strFormMechineIP","intID","dteEntryDatetime");
        COMMIT;
    END;

    DECLARE
        V_DATE DATE :=  TRUNC(SYSDATE, 'MM');
--        V_DATE DATE :=  TRUNC(SYSDATE) -3;
    BEGIN
        WHILE V_DATE <= TRUNC(SYSDATE)
        LOOP
            BEGIN
                DELETE FROM TEMP_ATTENDANCE_DATA_SCH;
                COMMIT;
                INSERT INTO  TEMP_ATTENDANCE_DATA_SCH (EMP_ID, EMP_CARD_NO, LOCATION_ID, IN_OUT_DATE,IN_OUT_TIME, IN_OUT_TIME_SEC) 
                SELECT EMP_ID,EMP_ID EMP_CARD_NO, LOCATION_ID,  IN_OUT_DATE, IN_OUT_TIME, 
                         TO_NUMBER((TO_CHAR(IN_OUT_TIME,'HH24'))*60)*60+TO_NUMBER(TO_CHAR(IN_OUT_TIME,'MI'))*60 +TO_NUMBER(TO_CHAR(IN_OUT_TIME,'SS')) IN_OUT_TIME_SEC
                FROM (
                       SELECT DISTINCT EMP_ID,EMP_ID EMP_CARD_NO, TRUNC(PUNCH_DATE) IN_OUT_DATE,
                        TO_DATE((TO_CHAR(PUNCH_DATE, 'DD/MM/RRRR')||' '||SUBSTR(PUNCH_TIME,1,8)), 'DD/MM/RRRR HH24:MI:SS') IN_OUT_TIME,B.LOCATION_ID
                        FROM PUNCH_MECHINE_RAW_DATA A, EMP_INFO B
                        WHERE A.PUNCH_USER_ID   =B.EMP_ID
                        AND   TRUNC(PUNCH_DATE) BETWEEN V_DATE-1 AND  V_DATE +1
                        );
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20555,SQLERRM);
            END;
                    
            BEGIN
                DELETE FROM TEMP_EMP_ROSTER_S_SCH;
                COMMIT;
            
                INSERT INTO TEMP_EMP_ROSTER_S_SCH (ADATE, EMP_ID, EMP_NO, JOINING_DATE, CARD_NUMBER, SHIFT_ID, DUTY_HOURS, OFFDAY, WORK_SHIFT, OVERTIME_ELIGIBLE, LOCATION_ID, GROUP_ID,
                                S_SHIFT1, SHIFT_START, SHIFT_START_SEC, 
                                E_SHIFT1, SHIFT_END, SHIFT_END_SEC, SL_NO,OFF_DAY_ID)
                SELECT ADATE, EMP_ID,EMP_NO,JOINING_DATE,CARD_NUMBER, SHIFT_ID, DUTY_HOURS, OFFDAY, WORK_SHIFT, OVERTIME_ELIGIBLE,LOCATION_ID, GROUP_ID,
                              S_SHIFT1, SHIFT_START, TO_NUMBER((TO_CHAR(S_SHIFT1,'HH24'))*60)*60+TO_NUMBER(TO_CHAR(S_SHIFT1,'MI'))*60 +TO_NUMBER(TO_CHAR(S_SHIFT1,'SS')) SHIFT_START_SEC,
                              E_SHIFT1, SHIFT_END, TO_NUMBER((TO_CHAR(E_SHIFT1,'HH24'))*60)*60+TO_NUMBER(TO_CHAR(E_SHIFT1,'MI'))*60 +TO_NUMBER(TO_CHAR(E_SHIFT1,'SS')) SHIFT_END_SEC, ROW_NUMBER() OVER ( ORDER BY  ADATE, EMP_ID ASC) SL,
                              (SELECT OFF_DAY_ID
                                FROM EMPLOYEE_OFFDAY
                                WHERE EMP_ID = R.EMP_ID
                                AND STATUS = 1
                                ORDER BY OFF_DAY_ID ASC NULLS LAST
                                FETCH FIRST 1 ROWS ONLY) OFF_DAY_ID
                FROM(
                          SELECT ADATE, EMP_ID,EMP_NO,JOINING_DATE,CARD_NUMBER, SHIFT_ID,SHIFT_START,
                                        TO_DATE((TO_CHAR (ADATE, 'DD/MM/RRRR') || ' ' || SHIFT_START), 'DD/MM/RRRR HH24:MI:SS') S_SHIFT1, 
                                        SHIFT_END,
                                        TO_DATE((TO_CHAR (ADATE, 'DD/MM/RRRR') || ' ' || SHIFT_START), 'DD/MM/RRRR HH24:MI:SS')+(1 / 24 * DUTY_HOURS) E_SHIFT1,
                                        DUTY_HOURS, OFFDAY, WORK_SHIFT,
                                        OVERTIME_ELIGIBLE,LOCATION_ID, GROUP_ID
                            FROM (SELECT B.EMP_ID,B.EMP_NO,B.EMP_ID CARD_NUMBER,A.FROM_DATE1,A.TO_DATE1,B.JOINING_DATE,
                                  A.SHIFT_START,A.SHIFT_END,D.TMDUTY DUTY_HOURS,A.DAY_NAME OFFDAY,D.SHORT_NAME WORK_SHIFT,
                                  B.OVERTIME_ELIGIBLE,B.LOCATION_ID,A.SHIFT_ID, B.GROUPID GROUP_ID
                                  FROM EMP_ROSTER A,EMP_INFO B,
                                      (SELECT A.EMP_ID,A.FROM_DATE1,A.LOCATION_ID
                                       FROM EMP_ROSTER A,EMP_INFO B,EMP_ROSTER_MST C
                                       WHERE A.EMP_ID = B.EMP_ID
                                       AND  A.REF_NO = C.REF_NO
                                       AND  NVL(C.ACTIVE_ROSTER,'1') = '1' 
                                       AND  A.LOCATION_ID = B.LOCATION_ID
                                       AND  A.LOCATION_ID = C.LOC_ID) C,SHIFT_SEQUENCE D
                                  WHERE A.EMP_ID            = B.EMP_ID
                                  AND   A.LOCATION_ID       = B.LOCATION_ID
                                  AND   A.EMP_ID            = C.EMP_ID
                                  AND   A.LOCATION_ID       = B.LOCATION_ID
                                  AND   TRUNC(A.FROM_DATE1) = C.FROM_DATE1
                                  AND   A.SHIFT_ID          = D.SHIFT_ID 
                                  AND   A.LOCATION_ID       = B.LOCATION_ID
                                  ) A, DATE_OF_MONTH B
                            WHERE ADATE BETWEEN FROM_DATE1 AND TO_DATE1 
                            AND   ADATE >= A.JOINING_DATE
                            AND   ADATE =V_DATE
                            -- AND   A.EMP_ID = 21336
                            )  R;
                            COMMIT;
            END;
        
            --REMOVE DUBLICATE ROSTER
            DECLARE
                CURSOR C1 IS
                SELECT EMP_ID, ADATE 
                FROM TEMP_EMP_ROSTER_S_SCH
                GROUP BY EMP_ID, ADATE
                HAVING COUNT(*) > 1;
                V_SL_NO NUMBER;
            BEGIN
                FOR I IN C1 LOOP
                        SELECT SL_NO 
                        INTO V_SL_NO
                        FROM TEMP_EMP_ROSTER_S_SCH
                        WHERE EMP_ID = I.EMP_ID
                        AND ADATE = I.ADATE
                        ORDER BY SL_NO ASC NULLS LAST
                        FETCH FIRST 1 ROWS ONLY;
                    
                        DELETE FROM TEMP_EMP_ROSTER_S_SCH
                        WHERE EMP_ID = I.EMP_ID
                        AND ADATE = I.ADATE
                        AND SL_NO <> V_SL_NO;
                        COMMIT;
                END LOOP;
            END;
        
            DECLARE
                V_MIN_IN_HR NUMBER := 4; --PROVIDE IN HOURS
                V_MAX_IN_HR NUMBER := 3; --PROVIDE IN HOURS
            BEGIN
                DELETE FROM TEMP_EMP_IN_OUT_SCH; COMMIT;
                INSERT INTO TEMP_EMP_IN_OUT_SCH(EMP_ID, IN_OUT_DATE, LOC_ID,  SHIFT_ID, WORKING_HOURS, ROSTER_INTIME, ROSTER_OUTTIME,  CREATE_BY, CREATE_DATE, CARD_NUMBER,  INTIME, OUTTIME,  NOF_PUNCH)
                SELECT EMP_ID, ADATE,   LOCATION_ID,  SHIFT_ID, DUTY_HOURS,S_SHIFT1,  E_SHIFT1, 1111, SYSDATE, EMP_ID,
                    CASE WHEN GROUP_ID = 3 AND MIN_IN_TIME IS NULL --MIN IN TIME WILL GET ONLY FOR FLEXIBLE EMPLOYEE THOSE GROUP_ID IS 3
                                    THEN MIN_PUNCH
                            WHEN OFF_DAY_ID = TO_NUMBER(TO_CHAR(ADATE,'D')) AND PUNCH_COUNT <= 1 
                                    THEN   NULL
                            WHEN SHIFT_ID NOT IN(3,5) AND MIN_IN_TIME IS NULL AND MIN_COMMON IS NULL AND PUNCH_COUNT > 1 
                                    THEN MIN_PUNCH
                            -- WHEN SHIFT_ID NOT IN(3,5) AND NVL(MIN_IN_TIME,SYSDATE-365) <> MIN_PUNCH
                            --         THEN MIN_PUNCH
                             WHEN MIN_IN_TIME IS NULL AND MIN_COMMON IS NOT NULL
                                    THEN MIN_COMMON
                            ELSE MIN_IN_TIME
                    END IN_TIME,
                    CASE 
                            WHEN OFF_DAY_ID = TO_NUMBER(TO_CHAR(ADATE,'D')) AND PUNCH_COUNT <= 1 
                                        THEN   NULL
                            WHEN SHIFT_ID NOT IN(3,5) AND OUT_TIME IS NULL
                                        THEN MAX_PUNCH
                             WHEN SHIFT_ID NOT IN(3,5) AND OUT_TIME IS NOT NULL AND OUT_TIME < MAX_PUNCH
                                        THEN MAX_PUNCH
                            ELSE OUT_TIME
                    END OUT_TIME,
                    PUNCH_COUNT
                    FROM (
                            SELECT EMP_ID, ADATE,   LOCATION_ID,  GROUP_ID, SHIFT_ID, DUTY_HOURS,S_SHIFT1, SHIFT_START, SHIFT_START_SEC, E_SHIFT1, SHIFT_END, SHIFT_END_SEC,
                            (SELECT MIN(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID) AND A.IN_OUT_TIME >= (S_SHIFT1 - V_MIN_IN_HR*(1/24)) AND A.IN_OUT_TIME <= (S_SHIFT1 + V_MAX_IN_HR*(1/24)) ) MIN_IN_TIME,
                            (SELECT MAX(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID) AND A.IN_OUT_TIME >= (S_SHIFT1 - V_MIN_IN_HR*(1/24)) AND A.IN_OUT_TIME <= (S_SHIFT1 + V_MAX_IN_HR*(1/24)) ) MAX_IN_TIME,
                            (SELECT MIN(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID) AND A.IN_OUT_TIME > (S_SHIFT1 + V_MAX_IN_HR*(1/24)) AND A.IN_OUT_TIME < (E_SHIFT1 - V_MIN_IN_HR*(1/24)) ) MIN_COMMON,
                            (SELECT MAX(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID) AND A.IN_OUT_TIME > (S_SHIFT1 + V_MAX_IN_HR*(1/24)) AND A.IN_OUT_TIME < (E_SHIFT1 - V_MIN_IN_HR*(1/24)) ) MAX_COMMON,
                            (SELECT MAX(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID) AND A.IN_OUT_TIME >= (E_SHIFT1 - V_MIN_IN_HR*(1/24)) AND A.IN_OUT_TIME <= (E_SHIFT1 + V_MAX_IN_HR*(1/24))) OUT_TIME,
                            (SELECT MIN(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID) AND A.IN_OUT_DATE = R.ADATE) MIN_PUNCH,
                            (SELECT MAX(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID) AND A.IN_OUT_DATE = R.ADATE) MAX_PUNCH,
                            CASE WHEN SHIFT_ID IN (3,5) THEN 
                                (SELECT COUNT(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID)  AND A.IN_OUT_TIME BETWEEN  (S_SHIFT1 - 5*(1/24)) AND  (E_SHIFT1 + 2*(1/24)))
                            ELSE
                                (SELECT COUNT(IN_OUT_TIME) FROM TEMP_ATTENDANCE_DATA_SCH A WHERE TO_NUMBER(A.EMP_ID) = TO_NUMBER(R.EMP_ID) AND A.IN_OUT_DATE = R.ADATE)
                            END PUNCH_COUNT,
                            OFF_DAY_ID
                            FROM TEMP_EMP_ROSTER_S_SCH R
            --                WHERE ADATE =  TO_DATE('01/09/2024 00:00:00', 'MM/DD/YYYY HH24:MI:SS')
--                            WHERE EMP_ID = 3962
                            );
                COMMIT;
            END;

            BEGIN
                MERGE INTO EMP_IN_OUT A
                USING  TEMP_EMP_IN_OUT_SCH B
                ON (A.EMP_ID = B.EMP_ID AND A.IN_OUT_DATE = B.IN_OUT_DATE)
                WHEN MATCHED THEN
                    UPDATE SET
                        A.INTIME        = B.INTIME,
                        A.OUTTIME       = B.OUTTIME,
                        A.ROSTER_INTIME = B.ROSTER_INTIME,
                        A.ROSTER_OUTTIME = B.ROSTER_OUTTIME,
                        A.WORKING_HOURS = B.WORKING_HOURS,
                        A.NOF_PUNCH     = B.NOF_PUNCH
                         WHERE B.NOF_PUNCH >0
                         AND (B.INTIME IS NOT NULL OR B.OUTTIME IS NOT NULL)
                WHEN NOT MATCHED THEN
                    INSERT (A.EMP_ID, A.IN_OUT_DATE, A.INTIME, A.OUTTIME, A.ROSTER_OUTTIME, A.WORKING_HOURS, A.ROSTER_INTIME, A.APPROVED_OVERTIME_H, A.OVERTIME_ELEGIBLE, A.OVERTIME_FROM, A.OVERTIME_TO, A.APPROVED_OVERTIME_M, A.DUTY_DAY, A.EDIT_USER, A.EDIT_DATE, A.ENTRY_USER, A.ENTRY_DATE, A.ENTRY_MEDE, A.CREATE_BY, A.CREATE_DATE, A.UPDATE_BY, A.UPDATE_DAE, A.AUTHORIZED_BY, A.AUTHORIZED_DATE, A.UPDATE_DATE, A.CARD_NUMBER, A.EMP_NO, A.PRESENT_STATUS, A.LOC_ID, A.SHIFT_ID, A.OT_HR_DEDUCT, A.LATE_MIN, A.LATE_CONSIDER, A.NOF_PUNCH)
                    VALUES (B.EMP_ID, B.IN_OUT_DATE, B.INTIME, B.OUTTIME, B.ROSTER_OUTTIME, B.WORKING_HOURS, B.ROSTER_INTIME, B.APPROVED_OVERTIME_H, B.OVERTIME_ELEGIBLE, B.OVERTIME_FROM, B.OVERTIME_TO, B.APPROVED_OVERTIME_M, B.DUTY_DAY, B.EDIT_USER, B.EDIT_DATE, B.ENTRY_USER, B.ENTRY_DATE, B.ENTRY_MEDE, B.CREATE_BY, B.CREATE_DATE, B.UPDATE_BY, B.UPDATE_DAE, B.AUTHORIZED_BY, B.AUTHORIZED_DATE, B.UPDATE_DATE, B.CARD_NUMBER, B.EMP_NO, B.PRESENT_STATUS, B.LOC_ID, B.SHIFT_ID, B.OT_HR_DEDUCT, B.LATE_MIN, B.LATE_CONSIDER, B.NOF_PUNCH)
                    WHERE B.NOF_PUNCH >0
                     AND (B.INTIME IS NOT NULL OR B.OUTTIME IS NOT NULL);
                     COMMIT;
            END;

            BEGIN
                MERGE INTO EMP_IN_OUT2 A
                USING  TEMP_EMP_IN_OUT_SCH B
                ON (A.EMP_ID = B.EMP_ID AND A.IN_OUT_DATE = B.IN_OUT_DATE)
                WHEN MATCHED THEN
                    UPDATE SET
                        A.INTIME      =  B.INTIME ,
                        A.OUTTIME       = B.OUTTIME,
                        A.ROSTER_INTIME = B.ROSTER_INTIME,
                        A.ROSTER_OUTTIME = B.ROSTER_OUTTIME,
                        A.WORKING_HOURS = B.WORKING_HOURS,
                        A.NOF_PUNCH     = B.NOF_PUNCH
                         WHERE B.NOF_PUNCH >0
                         AND (B.INTIME IS NOT NULL)
                WHEN NOT MATCHED THEN
                    INSERT (A.EMP_ID, A.IN_OUT_DATE, A.INTIME, A.OUTTIME, A.ROSTER_OUTTIME, A.WORKING_HOURS, A.ROSTER_INTIME, A.APPROVED_OVERTIME_H, A.OVERTIME_ELEGIBLE, A.OVERTIME_FROM, A.OVERTIME_TO, A.APPROVED_OVERTIME_M, A.DUTY_DAY, A.EDIT_USER, A.EDIT_DATE, A.ENTRY_USER, A.ENTRY_DATE, A.ENTRY_MEDE, A.CREATE_BY, A.CREATE_DATE, A.UPDATE_BY, A.UPDATE_DAE, A.AUTHORIZED_BY, A.AUTHORIZED_DATE, A.UPDATE_DATE, A.CARD_NUMBER, A.EMP_NO, A.PRESENT_STATUS, A.LOC_ID, A.SHIFT_ID, A.OT_HR_DEDUCT, A.LATE_MIN, A.LATE_CONSIDER, A.NOF_PUNCH)
                    VALUES (B.EMP_ID, B.IN_OUT_DATE, CASE WHEN B.INTIME IS NULL THEN B.OUTTIME ELSE B.INTIME END, B.OUTTIME, B.ROSTER_OUTTIME, B.WORKING_HOURS, B.ROSTER_INTIME, B.APPROVED_OVERTIME_H, B.OVERTIME_ELEGIBLE, B.OVERTIME_FROM, B.OVERTIME_TO, B.APPROVED_OVERTIME_M, B.DUTY_DAY, B.EDIT_USER, B.EDIT_DATE, B.ENTRY_USER, B.ENTRY_DATE, B.ENTRY_MEDE, B.CREATE_BY, B.CREATE_DATE, B.UPDATE_BY, B.UPDATE_DAE, B.AUTHORIZED_BY, B.AUTHORIZED_DATE, B.UPDATE_DATE, B.CARD_NUMBER, B.EMP_NO, B.PRESENT_STATUS, B.LOC_ID, B.SHIFT_ID, B.OT_HR_DEDUCT, B.LATE_MIN, B.LATE_CONSIDER, B.NOF_PUNCH)
                    WHERE B.NOF_PUNCH >0
                     AND (B.INTIME IS NOT NULL);
                     COMMIT;
            END;
        
            V_DATE := V_DATE +1;
        END LOOP;
    END;
END;
/