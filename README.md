# Financial Calculator Package Overview - PLSQL Oracle DB

This financial calculator package demonstrates several important PL/SQL package concepts:

## 1. Public vs Private Elements:
- **Public (accessible outside the package):**
  - Functions and procedures in the **package specification**.
  
- **Private (only accessible within the package):**
  - Functions and variables in the **package body** that are not declared in the specification.

## 2. Package Variables:
- **Public Constants:**
  - `g_default_interest_rate`: Default interest rate (5%).
  - `g_default_term_years`: Default term in years (5 years).
  
- **Public Variables:**
  - `g_tax_rate`: Tax rate (20%).

- **Private Constants:**
  - `c_months_per_year`: Constant for the number of months per year (12).

- **Private Variables:**
  - `v_last_calculation_date`: Maintains the last calculation date for internal use.

## 3. Function Calling Patterns:
- **Private Functions Called by Public Functions:**
  - `convert_annual_to_monthly_rate`: A private function used by the public functions for converting the annual interest rate to monthly rate.

- **Public Functions Calling Other Public Functions:**
  - `calculate_after_tax_return` calls `calculate_investment_return` to compute after-tax returns.

- **Default Parameter Values Using Package Constants:**
  - Functions like `calculate_loan_payment` and `calculate_investment_return` use default values from package constants.

## 4. Package Features:
- **Input Validation:**
  - Input validation is included in the `set_tax_rate` procedure.

- **Reuse of Functionality Across Multiple Functions:**
  - Functions like `calculate_loan_payment` and `calculate_investment_return` reuse the same logic for calculation of financial data.

- **State Maintenance Between Calls:**
  - The variable `v_last_calculation_date` tracks the last calculation date, ensuring the state is maintained between calls.

## 5. How to Use This Package:
- Run the entire script to create the package and test it.
- Make sure `SERVEROUTPUT` is ON to see the results.
- The test block at the end demonstrates how to call each function.

- Expected outcome
- ![image](https://github.com/user-attachments/assets/7981539f-6629-42e4-a861-3d8d69e2a5f9)

