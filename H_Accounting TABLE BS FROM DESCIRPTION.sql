USE H_Accounting; 



DELIMITER $$

-- FIRST WE ENSURE TO DROP PROCEDURE AND TABLE WE WANT TO CREATE TO AVOID DUPLICATE 

DROP PROCEDURE IF EXISTS H_Accounting.p_bs;

    DROP TABLE IF EXISTS H_Accounting.ttl_bs;
    DROP TABLE IF EXISTS H_Accounting.fin_bs;

-- THEN WE CREATE A PROCEDURE WHERE WE CAN CALL BY THE INPUT CALLED yea FOR YEAR REQUIRED AS INTEGER 

CREATE PROCEDURE H_Accounting.p_bs(IN yea INT) 
READS SQL DATA
    
BEGIN

-- HERE WE DROP AGAIN THE TABLE TO BE SURE 

DROP TABLE IF EXISTS H_Accounting.ttl_bs;


-- THEN WE CREATE A TABLE CALLED ttl_bs WE WILL USE FOR OUR FORMULAS, AS A CLEAN TABLE FILTERED 

CREATE TABLE ttl_bs AS (



-- WE START BY THE WITH FUNCTION 
WITH 

-- WE WANT TO SELECT ONLY THE COLUMS WE ESTIMATE USEFUL FOR US AND WE AVOID DUPLICATE COLUMNS AS company_id
-- WE ALSO FILTER THE DEBIT AND CREDIT NULL RESULTS

		je AS (	SELECT journal_entry_id, journal_entry_code, journal_entry, serial_number, entry_date, cancelled
				FROM journal_entry
			),
	jeli AS (	SELECT journal_entry_id, account_id, description, IFNULL(debit,0) AS debit, IFNULL(credit,0) AS credit
				FROM journal_entry_line_item
			),
	acc AS (	SELECT account_id, account_code, `account`, balance_sheet_section_id, profit_loss_section_id
				FROM `account`
			),
	ss AS (		SELECT statement_section_id, company_id, statement_section_code, statement_section,
				statement_section_order, is_balance_sheet_section, debit_is_positive
				FROM statement_section
			),
            
-- SINCE entry_date IS AS A TEXT AND THE YEAR IS STUCK IN THE MIDDLE OF THE DATA, WE USE CASE TO EXTRACT THE YEAR FRPM journal_entry 
  
	ttl AS (	SELECT *, CASE 	
								WHEN journal_entry LIKE '%2014%' THEN '2014'
								WHEN journal_entry LIKE '%2015%' THEN '2015'
								WHEN journal_entry LIKE '%2016%' THEN '2016'
								WHEN journal_entry LIKE '%2017%' THEN '2017'
								WHEN journal_entry LIKE '%2018%' THEN '2018'
								WHEN journal_entry LIKE '%2019%' THEN '2019'
								WHEN journal_entry LIKE '%2020%' THEN '2020'
								WHEN journal_entry LIKE '%2021%' THEN '2021'
								WHEN journal_entry LIKE '%2022%' THEN '2022'
								WHEN journal_entry LIKE '%2023%' THEN '2023'
								WHEN journal_entry LIKE '%2024%' THEN '2024'
								WHEN journal_entry LIKE '%2025%' THEN '2025'
								WHEN journal_entry LIKE '%2026%' THEN '2026'
								WHEN journal_entry LIKE '%2027%' THEN '2027'
								WHEN journal_entry LIKE '%2028%' THEN '2028'
								WHEN journal_entry LIKE '%2029%' THEN '2029'
								WHEN journal_entry LIKE '%2030%' THEN '2030'
                                
		-- AND WE STORE THE REST OF IT IN OTHERS YEARS 
        
					ELSE 'OTHERS' END AS `year`
                    
			FROM acc 
				LEFT JOIN ss 
				ON acc.profit_loss_section_id = ss.statement_section_id
				LEFT JOIN jeli 
				USING (account_id)
                LEFt JOIN je
                USING (journal_entry_id)
                
                
	
     -- BY USING THE WHERE FUNCTION HERE, WE ALTERED IN 1 ROW THE TABLE WE WILL BE USING DURING IN ALL THE PROCEDURE
     -- WE FILTERED THE CANCELLED ENTRIES AND ENSURE TO SELECT ONLY THE BALANCE SHEET 
      
		WHERE cancelled !=0 
        AND is_balance_sheet_section = 1
            )

            
		SELECT *
    from ttl );
            
  
  
  -- THEN WE CAN CALCULATE OUR DATA. WE USE DEBIT MINUS CREDIT TO GET THE VALUE OF ASSETS 
  -- WE WILL USE CREDIT MINUS DEBIT FOR LIABILITIES 
  -- WE CALL THE YEAR FROM CASE STATEMENT TO BE EQUAL TO THE yea CALLED BY THE PROCEDURE 
  -- WE STORE THE RESULT INTO VARIABLES @xxxxx
  
          -- CURRENT ASSETS -- 
          
            SELECT IFNULL(SUM(debit)-SUM(credit),0) INTO @curr_ass
            FROM ttl_bs
			WHERE statement_section_order = '1'
            AND `year` = yea;
            
	-- WE WILL DO IT FOR THE PREVIOUS YEAR AS WELL BY CALLING yea-1 
            
            SELECT IFNULL(SUM(debit)-SUM(credit),0) INTO @curr_ass_2
            FROM ttl_bs
			WHERE statement_section_order = '1'
            AND `year` = yea-1;
            
	-- THEN WE GET THE YEAR OVER YEAR GROWTH
            
            SET @yoy_curr = IFNULL(((@curr_ass / @curr_ass_2)-1),0);
         
         -- FIXED ASSETS --- 
         
             SELECT IFNULL(SUM(debit)-SUM(credit),0) INTO @fix_ass
            FROM ttl_bs
			WHERE statement_section_order = '2'
            AND `year` = yea;
            
            SELECT IFNULL((SUM(debit)-SUM(credit)),0) INTO @fix_ass_2
            FROM ttl_bs
			WHERE statement_section_order = '2'
            AND `year` = yea-1;
            
            SET @yoy_fix = IFNULL(((@fix_ass / @fix_ass_2)-1),0);
         
           -- DEFERRED ASSETS -- 
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @def_ass
            FROM ttl_bs
			WHERE statement_section_order = '3'
            AND `year` = yea;
            
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @def_ass_2
            FROM ttl_bs
			WHERE statement_section_order = '3'
            AND `year` = yea-1;
            
            SET @yoy_def_ass = IFNULL(((@def_ass / @def_ass_2)-1),0);
            
         
          -- TOTAL ASSETS -- 
          
          SET @ttl_ass = IFNULL((@curr_ass + @fix_ass + @def_ass),0);
          
          SET @ttl_ass_2 = IFNULL((@curr_ass_2 + @fix_ass_2 + @def_ass_2),0);
          
          SET @yoy_ttl_ass = IFNULL(((@ttl_ass / @ttl_ass_2)-1),0);
         
         -- CURRENT LIABILITIES -- 
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @curr_lia
            FROM ttl_bs
			WHERE statement_section_order = '4'
            AND `year` = yea;
            
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @curr_lia_2
            FROM ttl_bs
			WHERE statement_section_order = '4'
            AND `year` = yea-1;
            
            SET @yoy_lia = IFNULL(((@curr_lia / @curr_lia_2)-1),0);
            
             -- LONG-TERM LIABILITIES -- 
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @long_lia
            FROM ttl_bs
			WHERE statement_section_order = '5'
            AND `year` = yea;
            
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @long_lia_2
            FROM ttl_bs
			WHERE statement_section_order = '5'
            AND `year` = yea-1;
            
            SET @yoy_long_lia = IFNULL(((@long_lia / @long_lia_2)-1),0);
            
   -- DEFERRED LIABILITIES -- 
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @def_lia
            FROM ttl_bs
			WHERE statement_section_order = '6'
            AND `year` = yea;
            
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @def_lia_2
            FROM ttl_bs
			WHERE statement_section_order = '6'
            AND `year` = yea-1;
            
            SET @yoy_def_lia = IFNULL(((@def_lia / @def_lia_2)-1),0);
            
             -- TOTAL LIABILITIES -- 
          
          SET @ttl_lia = IFNULL((@curr_lia + @fix_lia_2 + @def_lia),0);
          
          SET @ttl_lia_2 = IFNULL((@long_lia + @long_lia_2 + @def_lia_2),0);
          
          SET @yoy_ttl_lia = IFNULL(((@ttl_lia / @ttl_lia_2)-1),0);
          
             -- EQUITY  -- 
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @eq
            FROM ttl_bs
			WHERE statement_section_order = '6'
            AND `year` = yea;
            
            SELECT IFNULL((SUM(credit) - SUM(debit)),0) INTO @eq_2
            FROM ttl_bs
			WHERE statement_section_order = '6'
            AND `year` = yea-1;
            
            SET @yoy_eq = IFNULL(((@eq / @eq_2)-1),0);
            

-- HERE WE DROP THE TABLE BEFORE CREATING IT TO BE VERY SURE. BETTER DO IT TWICE THAN 0. 

DROP TABLE IF EXISTS H_Accounting.fin_bs;
  
  DROP TABLE IF EXISTS H_Accounting.fin_bs;
  
  -- Creation of a table including row number, categories, current fiscal year, last fiscal year and year to year growth 
  
	CREATE TABLE H_Accounting.fin_bs
		(	line_nb INT, 
			categories VARCHAR(50), 
			curr_fy VARCHAR(50),
			last_fy VARCHAR(50),
            yoy VARCHAR(50)
		);
  
  -- Now we insert the a header for the report
  
  INSERT INTO H_Accounting.fin_bs
		   (line_nb, categories, curr_fy, last_fy, yoy )
	
	VALUES (1, 'BALANCE SHEET STATEMENT', 'In 000s of USD', 'In 000s of USD', 'In %'),
    
    
    -- HERE WE CALL THE yea FROM PROCEDURE AND yea-1 
    
			(2, 'YEARS',  yea, yea-1, 'YoY Growth'),
  
		 	(3, '',  '', '', ''),
    
    
    -- HERE WE CALL OUR VARIABLES STORING OUR RESULTS IN THE FORMAT WE WANT TO SEE IT 
    
			(4, 'CURRENT ASSETS', FORMAT(@curr_ass / 1000,2),FORMAT(@curr_ass_2 / 1000,2),FORMAT(@yoy_curr,2)),

			(5, 'FIXED ASSETS',FORMAT(@fix_ass / 1000,2),FORMAT(@fix_ass_2 / 1000,2),FORMAT(@yoy_fix,2)),
   
			(6, 'DEFERRED ASSETS',FORMAT(@def_ass / 1000,2),FORMAT(@def_ass_2 / 1000,2),FORMAT(@yoy_def_ass,2)),
			
            (7, 'TOTAL ASSETS', FORMAT(@ttl_ass / 1000,2),FORMAT(@ttl_ass_2 / 1000,2),FORMAT(@yoy_ttl_ass,2)),
    
			(8, '-------------------', '-------------------','-------------------','-------------------'),
    
		 	(9, 'CURRENT LIABILITIES', FORMAT(@curr_lia / 1000,2),FORMAT(@curr_lia_2 / 1000,2),FORMAT(@yoy_lia, 2)),
			
            (10, 'LONG-TERM LIABILITIES', FORMAT(@long_lia / 1000,2),FORMAT(@long_lia_2 / 1000,2),FORMAT(@yoy_long_lia, 2)),
    
			(11, 'DEFERRED LIABILITIES', FORMAT(@def_lia / 1000,2),FORMAT(@def_lia_2 / 1000,2),FORMAT(@yoy_def_lia, 2)),
    
			(12, '-------------------', '-------------------','-------------------','-------------------'),
			
            (13, 'EQUITY', FORMAT(@eq / 1000,2),FORMAT(@eq_2 / 1000,2),FORMAT(@yoy_eq, 2));
    
      
  END$$
    DELIMITER ;
 
 
 -- THEN WE CAN CALL THE YEAR WE WANT TO RUN THE PROCEDURE WITH 
 
        CALL H_Accounting.p_bs(2017);
        
-- AND SEE THE RESULT

        SELECT * FROM H_Accounting.fin_bs;