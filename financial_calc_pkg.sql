-- First, drop the package if it exists
BEGIN
  EXECUTE IMMEDIATE 'DROP PACKAGE financial_calc_pkg';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -4043 THEN
      RAISE;
    END IF;
END;
/

-- Create the package specification (public interface)
CREATE OR REPLACE PACKAGE financial_calc_pkg AS
  -- Public constants
  g_default_interest_rate CONSTANT NUMBER := 0.05;  -- 5% default interest rate
  g_default_term_years CONSTANT NUMBER := 5;        -- 5 year default term
  
  -- Public variables
  g_tax_rate NUMBER := 0.20;                        -- 20% tax rate
  
  -- Public functions and procedures
  FUNCTION calculate_loan_payment(
    p_principal NUMBER,
    p_interest_rate NUMBER DEFAULT g_default_interest_rate,
    p_term_years NUMBER DEFAULT g_default_term_years
  ) RETURN NUMBER;
  
  FUNCTION calculate_investment_return(
    p_principal NUMBER,
    p_interest_rate NUMBER DEFAULT g_default_interest_rate,
    p_term_years NUMBER DEFAULT g_default_term_years,
    p_apply_tax BOOLEAN DEFAULT FALSE
  ) RETURN NUMBER;
  
  FUNCTION calculate_after_tax_return(
    p_principal NUMBER,
    p_interest_rate NUMBER DEFAULT g_default_interest_rate,
    p_term_years NUMBER DEFAULT g_default_term_years
  ) RETURN NUMBER;
  
  PROCEDURE display_amortization_schedule(
    p_principal NUMBER,
    p_interest_rate NUMBER DEFAULT g_default_interest_rate,
    p_term_years NUMBER DEFAULT g_default_term_years
  );
  
  -- Public setter for tax rate
  PROCEDURE set_tax_rate(p_tax_rate NUMBER);
  
END financial_calc_pkg;
/

-- Create the package body (implementation)
CREATE OR REPLACE PACKAGE BODY financial_calc_pkg AS
  -- Private constants
  c_months_per_year CONSTANT NUMBER := 12;
  
  -- Private variables
  v_last_calculation_date DATE := SYSDATE;
  
  -- Private functions
  FUNCTION convert_annual_to_monthly_rate(p_annual_rate NUMBER) RETURN NUMBER IS
  BEGIN
    RETURN p_annual_rate / c_months_per_year;
  END;
  
  FUNCTION calculate_compound_interest(
    p_principal NUMBER,
    p_interest_rate NUMBER,
    p_term_years NUMBER
  ) RETURN NUMBER IS
    v_result NUMBER;
  BEGIN
    -- Compound interest formula: P(1 + r)^t
    v_result := p_principal * POWER(1 + p_interest_rate, p_term_years);
    
    -- Update private tracking variable
    v_last_calculation_date := SYSDATE;
    
    RETURN v_result;
  END;
  
  -- Public function implementations
  FUNCTION calculate_loan_payment(
    p_principal NUMBER,
    p_interest_rate NUMBER DEFAULT g_default_interest_rate,
    p_term_years NUMBER DEFAULT g_default_term_years
  ) RETURN NUMBER IS
    v_monthly_rate NUMBER;
    v_num_payments NUMBER;
    v_payment NUMBER;
  BEGIN
    -- Convert annual rate to monthly
    v_monthly_rate := convert_annual_to_monthly_rate(p_interest_rate);
    
    -- Calculate number of payments
    v_num_payments := p_term_years * c_months_per_year;
    
    -- Calculate monthly payment using loan payment formula
    -- Payment = P * (r * (1 + r)^n) / ((1 + r)^n - 1)
    v_payment := p_principal * (v_monthly_rate * POWER(1 + v_monthly_rate, v_num_payments)) 
                 / (POWER(1 + v_monthly_rate, v_num_payments) - 1);
    
    RETURN ROUND(v_payment, 2);
  END;
  
  FUNCTION calculate_investment_return(
    p_principal NUMBER,
    p_interest_rate NUMBER DEFAULT g_default_interest_rate,
    p_term_years NUMBER DEFAULT g_default_term_years,
    p_apply_tax BOOLEAN DEFAULT FALSE
  ) RETURN NUMBER IS
    v_total_return NUMBER;
    v_tax_amount NUMBER := 0;
  BEGIN
    -- Call private function for compound interest calculation
    v_total_return := calculate_compound_interest(p_principal, p_interest_rate, p_term_years);
    
    -- Apply tax if requested
    IF p_apply_tax THEN
      v_tax_amount := (v_total_return - p_principal) * g_tax_rate;
      v_total_return := v_total_return - v_tax_amount;
    END IF;
    
    RETURN ROUND(v_total_return, 2);
  END;
  
  FUNCTION calculate_after_tax_return(
    p_principal NUMBER,
    p_interest_rate NUMBER DEFAULT g_default_interest_rate,
    p_term_years NUMBER DEFAULT g_default_term_years
  ) RETURN NUMBER IS
  BEGIN
    -- Reuse the investment return function with tax parameter set to TRUE
    RETURN calculate_investment_return(p_principal, p_interest_rate, p_term_years, TRUE);
  END;
  
  PROCEDURE display_amortization_schedule(
    p_principal NUMBER,
    p_interest_rate NUMBER DEFAULT g_default_interest_rate,
    p_term_years NUMBER DEFAULT g_default_term_years
  ) IS
    v_monthly_payment NUMBER;
    v_remaining_balance NUMBER := p_principal;
    v_interest_payment NUMBER;
    v_principal_payment NUMBER;
    v_monthly_rate NUMBER;
    v_payment_number NUMBER := 1;
    v_total_payments NUMBER;
  BEGIN
    -- Get monthly payment using our public function
    v_monthly_payment := calculate_loan_payment(p_principal, p_interest_rate, p_term_years);
    
    -- Convert to monthly rate
    v_monthly_rate := convert_annual_to_monthly_rate(p_interest_rate);
    
    -- Calculate total number of payments
    v_total_payments := p_term_years * c_months_per_year;
    
    -- Display header
    DBMS_OUTPUT.PUT_LINE('===== Loan Amortization Schedule =====');
    DBMS_OUTPUT.PUT_LINE('Principal: $' || TO_CHAR(p_principal, '999,999,999.99'));
    DBMS_OUTPUT.PUT_LINE('Interest Rate: ' || TO_CHAR(p_interest_rate * 100, '99.99') || '%');
    DBMS_OUTPUT.PUT_LINE('Term: ' || p_term_years || ' years');
    DBMS_OUTPUT.PUT_LINE('Monthly Payment: $' || TO_CHAR(v_monthly_payment, '999,999.99'));
    DBMS_OUTPUT.PUT_LINE('--------------------------------');
    DBMS_OUTPUT.PUT_LINE('Payment# | Interest | Principal | Remaining Balance');
    DBMS_OUTPUT.PUT_LINE('--------------------------------');
    
    -- Calculate and display each payment
    -- Only show first 12 payments and last payment for brevity
    WHILE v_payment_number <= v_total_payments LOOP
      -- Calculate interest for this period
      v_interest_payment := v_remaining_balance * v_monthly_rate;
      
      -- Calculate principal for this period
      v_principal_payment := v_monthly_payment - v_interest_payment;
      
      -- Update remaining balance
      v_remaining_balance := v_remaining_balance - v_principal_payment;
      
      -- Display this payment
      IF v_payment_number <= 12 OR v_payment_number = v_total_payments THEN
        DBMS_OUTPUT.PUT_LINE(
          LPAD(v_payment_number, 8) || ' | ' ||
          LPAD('$' || TO_CHAR(v_interest_payment, '999.99'), 9) || ' | ' ||
          LPAD('$' || TO_CHAR(v_principal_payment, '999.99'), 9) || ' | ' ||
          LPAD('$' || TO_CHAR(v_remaining_balance, '999,999.99'), 17)
        );
      ELSIF v_payment_number = 13 THEN
        DBMS_OUTPUT.PUT_LINE('  ...');
      END IF;
      
      -- Increment payment number
      v_payment_number := v_payment_number + 1;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('--------------------------------');
  END;
  
  PROCEDURE set_tax_rate(p_tax_rate NUMBER) IS
  BEGIN
    -- Validate tax rate is between 0 and 1
    IF p_tax_rate >= 0 AND p_tax_rate <= 1 THEN
      g_tax_rate := p_tax_rate;
      DBMS_OUTPUT.PUT_LINE('Tax rate updated to ' || TO_CHAR(p_tax_rate * 100) || '%');
    ELSE
      RAISE_APPLICATION_ERROR(-20001, 'Tax rate must be between 0 and 1');
    END IF;
  END;
  
END financial_calc_pkg;
/

-- Test the package
SET SERVEROUTPUT ON
DECLARE
  v_loan_payment NUMBER;
  v_investment_return NUMBER;
  v_after_tax_return NUMBER;
BEGIN
  -- Test loan payment calculation
  v_loan_payment := financial_calc_pkg.calculate_loan_payment(100000, 0.045, 30);
  DBMS_OUTPUT.PUT_LINE('Monthly payment for $100,000 loan: $' || TO_CHAR(v_loan_payment, '999,999.99'));
  
  -- Test investment return calculation
  v_investment_return := financial_calc_pkg.calculate_investment_return(10000, 0.07, 10);
  DBMS_OUTPUT.PUT_LINE('Investment return after 10 years: $' || TO_CHAR(v_investment_return, '999,999.99'));
  
  -- Test after-tax return calculation
  v_after_tax_return := financial_calc_pkg.calculate_after_tax_return(10000, 0.07, 10);
  DBMS_OUTPUT.PUT_LINE('After-tax investment return: $' || TO_CHAR(v_after_tax_return, '999,999.99'));
  
  -- Change tax rate
  financial_calc_pkg.set_tax_rate(0.25);
  
  -- Recalculate after-tax return with new rate
  v_after_tax_return := financial_calc_pkg.calculate_after_tax_return(10000, 0.07, 10);
  DBMS_OUTPUT.PUT_LINE('After-tax investment return with new tax rate: $' || TO_CHAR(v_after_tax_return, '999,999.99'));
  
  -- Display amortization schedule for a small loan
  financial_calc_pkg.display_amortization_schedule(25000, 0.04, 5);
END;
/