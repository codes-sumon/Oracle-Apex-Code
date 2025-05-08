CREATE  TYPE address_type AS OBJECT (
  street   VARCHAR2(100),
  city     VARCHAR2(50),
  state    VARCHAR2(50),
  zip_code VARCHAR2(20)
);


CREATE  TYPE address_type_t AS OBJECT (
  street   VARCHAR2(100),
  city     VARCHAR2(50),
  state    VARCHAR2(50),
  zip_code VARCHAR2(20),
  permanent_add address_type
);

CREATE TABLE employee_obj (
  emp_id     NUMBER PRIMARY KEY,
  full_name  VARCHAR2(100),
  address    address_type
);

alter table employee_obj add permanent_add address_type_t;



INSERT INTO employee_obj (emp_id, full_name, address, PERMANENT_ADD)
VALUES (
  2,
  'Sumon Akij',
  address_type('123 Main Street', 'Dhaka', 'Dhaka Division', '1205'),
  address_type_t(
    'Current Street',
    'Dhaka',
    'Dhaka Division',
    '1205',
    address_type(
      'Permanent Street',
      'Khulna',
      'Khulna Division',
      '9000'
    )
  )
);


SELECT 
  e.emp_id,
  e.full_name,
  e.address.street AS current_street,
  e.address.city AS current_city,
  e.address.state AS current_state,
  e.address.zip_code AS current_zip_code,
  e.permanent_add.street AS permanent_street,
  e.permanent_add.permanent_add.street AS permanent_zip_code
FROM employee_obj e;
