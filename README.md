# DBMS-project
Airline Database Management System

In this document, you will find all the information to use our database management system model. All the code you need is in the file “code.sql”. First, in your terminal, set your environment in the folder “BOURGIN_MONFORT_PROJECT”. Then open Postgres with the following command: 
psql postgres

Then, create the data base airline_db with the following command:
CREATE DATABASE airline_db;

Verify that the database is well created with the command: 
\l

Then, you should connect in the database with the command:
\c airline_db

Then, you will need to create all tables of our database model. To do this, you should copy past the lines 1 to 190 of our document “code.sql”, and then execute it.
Then, to populate the database with some data, you can copy past the lines 195 to 350 of the document “code.sql” into the terminal, and then execute it.

Then, you can copy and paste some queries written after line 350 to experiment with the database. Note that if you want good results for queries assigning a plane or a crew to a flight, you should only populate the tables “Airplanes”, “Checks”, “Flights”, and “Crew”. If “CrewAssignment” and “FlightAirplaneAssignment” are already populated, availability queries will rarely return results, since they detect timetable overlaps.
You can play with all the queries and test the limits them. Enjoy ! 
We also created an interface for the tables “Airplanes”, “Checks”, “Flights”, “Crew”, “CrewAssignment” and “FlightAirplaneAssignment”.

To make the interface works on your computer, follow the steps :
-	In a terminal go to the project folder You must be in the directory where “app.py” is located. 
-	Install dependencies with the line: “python3 -m pip install streamlit sqlalchemy psycopg2-binary pandas”
-	Database setup: Make sure PostgreSQL is running and create the database:

psql postgres

CREATE DATABASE airline_db; 

Enter in the data base :  \c airline_db

Create all tables : 

CREATE TABLE Airplane (
    airplane_id INT PRIMARY KEY,
    model VARCHAR(50) NOT NULL,
    total_capacity INT NOT NULL,
    eco_capacity INT NOT NULL DEFAULT 0,
    business_capacity INT NOT NULL DEFAULT 0,
    first_capacity INT NOT NULL DEFAULT 0,
    range_km INT NOT NULL,
    min_runway_length_m INT NOT NULL,
    current_location VARCHAR(100),
    flight_status VARCHAR(20) DEFAULT 'ground',

    CHECK (total_capacity > 0),
    CHECK (eco_capacity >= 0),
    CHECK (business_capacity >= 0),
    CHECK (first_capacity >= 0),
    CHECK (range_km > 0),
    CHECK (min_runway_length_m > 0),
    CHECK (total_capacity = eco_capacity + business_capacity + first_capacity)
);

CREATE TABLE Checks (
    airplane_id INT PRIMARY KEY,
    commissioning DATE,
    next_check_A DATE,
    next_check_B DATE,
    next_check_C DATE,
    next_check_D DATE,
    last_flight_incident_level VARCHAR(30) DEFAULT 'none', -- 'none', 'light', 'medium', 'hard'
    incident_note TEXT,
    FOREIGN KEY (airplane_id) REFERENCES Airplane(airplane_id)
);

CREATE TABLE Flights (
    flight_id INT PRIMARY KEY,
    flight_number VARCHAR(10) NOT NULL,
    departure_airport VARCHAR(10) NOT NULL,
    arrival_airport VARCHAR(10) NOT NULL,
    flight_type VARCHAR(20) NOT NULL CHECK (
        flight_type IN ('short_haul', 'medium_haul', 'long_haul')
    ),
    distance_km INT NOT NULL,
    departure_runway_length_m INT NOT NULL,
    arrival_runway_length_m INT NOT NULL,
    outbound_departure_time TIMESTAMP NOT NULL,
    outbound_arrival_time TIMESTAMP NOT NULL,
    return_departure_time TIMESTAMP NOT NULL,
    return_arrival_time TIMESTAMP NOT NULL,
    status VARCHAR(20) DEFAULT 'scheduled',

    CHECK (distance_km > 0),
    CHECK (departure_runway_length_m > 0),
    CHECK (arrival_runway_length_m > 0),
    CHECK (outbound_arrival_time > outbound_departure_time),
    CHECK (return_arrival_time > return_departure_time),
    CHECK (return_departure_time > outbound_arrival_time)
);

CREATE TABLE FlightAirplaneAssignment (
    assignment_id INT PRIMARY KEY,
    flight_id INT NOT NULL,
    airplane_id INT NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assignment_status VARCHAR(20) DEFAULT 'planned' CHECK (
        assignment_status IN ('planned', 'confirmed', 'completed', 'cancelled')
    ),

    FOREIGN KEY (flight_id) REFERENCES Flights(flight_id),
    FOREIGN KEY (airplane_id) REFERENCES Airplane(airplane_id),

    UNIQUE (flight_id)
);

CREATE TABLE Crew (
    crew_id INT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    role VARCHAR(30) NOT NULL, -- Pilot, Co-Pilot, Steward, Cabin Manager
    haul_type VARCHAR(20) NOT NULL CHECK (
        haul_type IN ('short_haul', 'medium_haul', 'long_haul')
    ),
    hire_date DATE,
    airplane_model_qualification VARCHAR(50),
    experience_years INT,
    salary DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'active' -- active, on_leave, retired
);

CREATE TABLE CrewAssignment (
assignment_id INT PRIMARY KEY,
crew_id INT NOT NULL,
activity_type VARCHAR(20) NOT NULL CHECK (
activity_type IN ('flight', 'rest', 'on_call', 'training', 'medical', 'leave', 'off')
),
flight_id INT NULL,

outbound_assigned BOOLEAN NOT NULL DEFAULT FALSE,
return_assigned BOOLEAN NOT NULL DEFAULT FALSE,

duty_role VARCHAR(30) NULL CHECK (
duty_role IN ('Pilot', 'Co-Pilot', 'Steward', 'Cabin Manager')
),
start_time TIMESTAMP NOT NULL,
end_time TIMESTAMP NOT NULL,
location VARCHAR(50) NULL,
notes TEXT,
status VARCHAR(20) DEFAULT 'planned' CHECK (
status IN ('planned', 'completed', 'cancelled')
),

FOREIGN KEY (crew_id) REFERENCES Crew(crew_id),
FOREIGN KEY (flight_id) REFERENCES Flights(flight_id),

UNIQUE (crew_id, flight_id)
);


Then, populate the database with those line:

-- Airplanes
INSERT INTO Airplane (airplane_id, model, total_capacity, eco_capacity, business_capacity, first_capacity, range_km, min_runway_length_m, current_location, flight_status) VALUES
(1, 'Boeing 737',   180, 150, 24,  6,  5600, 2100, 'CDG', 'ground'),
(2, 'Airbus A320',  165, 140, 20,  5,  6300, 2000, 'CDG', 'ground'),
(3, 'Boeing 777',   350, 280, 50, 20, 13500, 3100, 'CDG', 'ground'),
(4, 'Airbus A380',  500, 400, 76, 24, 15200, 3100, 'CDG', 'ground'),
(5, 'Embraer E190', 100,  88, 12,  0,  4500, 1800, 'CDG', 'ground');

-- Checks
INSERT INTO Checks (airplane_id, commissioning, next_check_A, next_check_B, next_check_C, next_check_D, last_flight_incident_level, incident_note) VALUES
(1, '2018-03-10', '2026-06-01', '2027-01-01', '2028-01-01', '2030-01-01', 'none',   NULL),
(2, '2019-07-22', '2026-07-15', '2027-03-01', '2028-06-01', '2031-01-01', 'light',  'Minor turbulence damage on wing tip'),
(3, '2015-11-05', '2026-05-20', '2026-12-01', '2028-01-01', '2029-06-01', 'none',   NULL),
(4, '2017-02-14', '2026-08-01', '2027-06-01', '2029-01-01', '2032-01-01', 'none',   NULL),
(5, '2021-09-30', '2026-09-01', '2027-09-01', '2029-09-01', '2033-09-01', 'medium', 'Bird strike on engine 1, under review');

-- Flights (round trips)
INSERT INTO Flights (flight_id, flight_number, departure_airport, arrival_airport, flight_type, distance_km, departure_runway_length_m, arrival_runway_length_m, outbound_departure_time, outbound_arrival_time, return_departure_time, return_arrival_time, status) VALUES
(1, 'AF101', 'CDG', 'LHR', 'short_haul',    340, 2700, 3200, '2026-05-01 06:00:00', '2026-05-01 07:10:00', '2026-05-01 09:00:00', '2026-05-01 10:10:00', 'scheduled'),
(2, 'AF202', 'CDG', 'FCO', 'medium_haul',  1100, 2700, 3900, '2026-05-02 08:00:00', '2026-05-02 10:00:00', '2026-05-02 12:00:00', '2026-05-02 14:00:00', 'scheduled'),
(3, 'AF303', 'CDG', 'JFK', 'long_haul',    5830, 2700, 4400, '2026-05-03 10:00:00', '2026-05-03 21:00:00', '2026-05-04 23:00:00', '2026-05-05 11:00:00', 'scheduled'),
(4, 'AF404', 'CDG', 'DXB', 'long_haul',    5250, 2700, 4200, '2026-05-05 07:00:00', '2026-05-05 17:00:00', '2026-05-06 19:00:00', '2026-05-07 05:00:00', 'scheduled'),
(5, 'AF505', 'LHR', 'MAD', 'medium_haul',  1265, 3200, 3800, '2026-05-06 09:00:00', '2026-05-06 11:30:00', '2026-05-06 13:00:00', '2026-05-06 15:30:00', 'scheduled'),
(6, 'AF606', 'CDG', 'NRT', 'long_haul',    9720, 2700, 4000, '2026-05-07 11:00:00', '2026-05-08 07:00:00', '2026-05-09 09:00:00', '2026-05-10 05:00:00', 'scheduled'),
(7, 'AF101', 'CDG', 'NYC', 'long_haul',    340, 3100, 3100, '2026-05-10 06:00:00', '2026-05-10 07:10:00', '2026-05-10 09:00:00', '2026-05-10 10:10:00', 'scheduled');


-- Crew
INSERT INTO Crew (crew_id, first_name, last_name, role, haul_type, hire_date, airplane_model_qualification, experience_years, salary, status) VALUES
(1,  'Jean',    'Dupont',       'Pilot',         'long_haul',   '2010-04-01', 'Boeing 777',   15, 95000.00,  'active'),
(2,  'Marie',   'Laurent',      'Co-Pilot',      'long_haul',   '2015-06-15', 'Boeing 777',    9, 72000.00,  'active'),
(3,  'Pierre',  'Martin',       'Pilot',         'medium_haul', '2012-09-01', 'Airbus A320',  12, 88000.00,  'active'),
(4,  'Sophie',  'Bernard',      'Co-Pilot',      'medium_haul', '2018-03-20', 'Airbus A320',   6, 65000.00,  'active'),
(5,  'Lucas',   'Petit',        'Pilot',         'short_haul',  '2020-01-10', 'Airbus A320',   4, 70000.00,  'active'),
(6,  'Emma',    'Rousseau',     'Steward',       'long_haul',   '2016-05-05', 'Boeing 777',    8, 42000.00,  'active'),
(7,  'Hugo',    'Moreau',       'Steward',       'medium_haul', '2019-11-01', 'Airbus A320',   5, 38000.00,  'active'),
(8,  'Chloe',   'Simon',        'Cabin Manager', 'long_haul',   '2013-07-22', 'Boeing 777',   11, 55000.00,  'active'),
(9,  'Thomas',  'Michel',       'Steward',       'short_haul',  '2021-02-14', 'Airbus A320',   3, 36000.00,  'active'),
(10, 'Camille', 'Lefevre',      'Pilot',         'long_haul',   '2008-08-30', 'Airbus A380',  17, 102000.00, 'active'),
(11, 'Antoine', 'Garcia',       'Co-Pilot',      'long_haul',   '2017-04-12', 'Airbus A380',   7, 74000.00,  'active'),
(12, 'Lea',     'Durand',       'Cabin Manager', 'medium_haul', '2014-10-03', 'Airbus A320',  10, 50000.00,  'active'),
(13, 'Paul', 'Durand', 'Pilot', 'short_haul', '2020-06-15', 'Airbus A320', 5, 6500.00, 'active');

-	Leave psql
-	Update the connection string in the code at the beginning of the doc “app.py”  by replacing  “username” by your username:
postgresql+psycopg2://<username>@localhost:5432/airline_db


-	Run the application with the following line. Make sure you are still in the project folder (where app.py is):


ls
python3 -m streamlit run app.py


It should open the link : http://localhost:8501

-	Enjoy the interface




