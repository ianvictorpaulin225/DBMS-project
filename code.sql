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



CREATE TABLE Passenger (
    passenger_id INT PRIMARY KEY, 
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL, 
    phone VARCHAR(20),
    birth_date DATE,
    nationality VARCHAR(50),
    passport_number VARCHAR(30) UNIQUE -- unique 
);

CREATE TABLE FrequentFlyer (
    ff_id INT PRIMARY KEY, 
    passenger_id INT NOT NULL UNIQUE, -- ensures optional one to one
    ff_number VARCHAR(20) UNIQUE NOT NULL,
    tier VARCHAR(20) NOT NULL DEFAULT 'Blue'
        CHECK (tier IN ('Blue', 'Silver', 'Gold', 'Platinum')),
    points_balance INT NOT NULL DEFAULT 0,
    total_points_earned INT NOT NULL DEFAULT 0,
    enrolled_date DATE NOT NULL,

    CHECK (points_balance >= 0), --ensure no negative points
    FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id) ---ensures optional one to one FF links to real passenger
);

CREATE TABLE FlightSeat (
    seat_id INT PRIMARY KEY,
    flight_id INT NOT NULL,
    airplane_id INT NOT NULL,
    seat_number VARCHAR(10) NOT NULL,
    travel_class VARCHAR(20) NOT NULL
        CHECK (travel_class IN ('economy', 'business', 'first')),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    is_window BOOLEAN DEFAULT FALSE,
    is_aisle BOOLEAN DEFAULT FALSE,

    UNIQUE (flight_id, seat_number),  -- so seat numbering is unique on each flight
    FOREIGN KEY (flight_id) REFERENCES Flights(flight_id), --so that one flight has many seats
    FOREIGN KEY (airplane_id) REFERENCES Airplane(airplane_id) -- ensure seat is tied to actual plane
);

CREATE TABLE Ticket (
    ticket_id SERIAL PRIMARY KEY,
    passenger_id INT NOT NULL REFERENCES Passenger(passenger_id), -- ensures one actual passenger per ticket 
    flight_id INT NOT NULL REFERENCES Flights(flight_id),
    seat_id INT NOT NULL REFERENCES FlightSeat(seat_id),  --ensures one ticket per seat per flight
    booking_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    travel_class VARCHAR(20) NOT NULL CHECK (travel_class IN ('economy', 'business', 'first')),
    price NUMERIC(10,2) NOT NULL,
    ff_id INT REFERENCES FrequentFlyer(ff_id), --each ticket may reference at most one FF
    booked BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(passenger_id, flight_id), --- same passenger cant book same flight twice
	cancelled BOOLEAN DEFAULT FALSE,
	cancelled_date TIMESTAMP NULL --
);

CREATE TABLE FFPointsTransaction (
    transaction_id INT PRIMARY KEY, --for identification
    ff_id INT NOT NULL, -- for user
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    transaction_type VARCHAR(20) NOT NULL
        CHECK (transaction_type IN ('earn', 'redeem', 'expire', 'adjustment')),
    points INT NOT NULL,
    related_ticket_id INT NULL,
    notes TEXT,
    FOREIGN KEY (ff_id) REFERENCES FrequentFlyer(ff_id), --one FF may have multiple transactions
    FOREIGN KEY (related_ticket_id) REFERENCES Ticket(ticket_id) ON DELETE SET NULL -- each transaction related to a unique ticket 
);






--Database population : 


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
(6, 'AF606', 'CDG', 'NRT', 'long_haul',    9720, 2700, 4000, '2026-05-07 11:00:00', '2026-05-08 07:00:00', '2026-05-09 09:00:00', '2026-05-10 05:00:00', 'scheduled');
(7, 'AF101', 'CDG', 'NYC', 'long_haul',    340, 3100, 3100, '2026-05-10 06:00:00', '2026-05-10 07:10:00', '2026-05-10 09:00:00', '2026-05-10 10:10:00', 'scheduled'),

-- Airplane assignments
INSERT INTO FlightAirplaneAssignment (assignment_id, flight_id, airplane_id, assignment_status) VALUES
(1, 1, 2, 'confirmed'),
(2, 2, 1, 'confirmed'),
(3, 3, 3, 'confirmed'),
(4, 4, 4, 'planned'),
(5, 5, 2, 'planned');

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

-- Crew assignments
INSERT INTO CrewAssignment (assignment_id, crew_id, activity_type, flight_id, duty_role, start_time, end_time, location, status) VALUES
(1,  1,  'flight', 3,    'Pilot',         '2026-05-03 10:00:00', '2026-05-05 11:00:00', 'CDG', 'planned'),
(2,  2,  'flight', 3,    'Co-Pilot',      '2026-05-03 10:00:00', '2026-05-05 11:00:00', 'CDG', 'planned'),
(3,  6,  'flight', 3,    'Steward',       '2026-05-03 10:00:00', '2026-05-05 11:00:00', 'CDG', 'planned'),
(4,  8,  'flight', 3,    'Cabin Manager', '2026-05-03 10:00:00', '2026-05-05 11:00:00', 'CDG', 'planned'),
(5,  3,  'flight', 2,    'Pilot',         '2026-05-02 08:00:00', '2026-05-02 14:00:00', 'CDG', 'planned'),
(6,  4,  'flight', 2,    'Co-Pilot',      '2026-05-02 08:00:00', '2026-05-02 14:00:00', 'CDG', 'planned'),
(7,  7,  'flight', 2,    'Steward',       '2026-05-02 08:00:00', '2026-05-02 14:00:00', 'CDG', 'planned'),
(8,  5,  'flight', 1,    'Pilot',         '2026-05-01 06:00:00', '2026-05-01 10:10:00', 'CDG', 'planned'),
(9,  9,  'flight', 1,    'Steward',       '2026-05-01 06:00:00', '2026-05-01 10:10:00', 'CDG', 'planned'),
(10, 12, 'rest',   NULL, NULL,            '2026-05-01 00:00:00', '2026-05-03 00:00:00', 'CDG', 'planned');

-- Holidays
INSERT INTO Holidays (crew_id, holidays_left) VALUES
(1, 22), (2, 25), (3, 18), (4, 25),  (5, 20),
(6, 15), (7, 25), (8, 10), (9, 25), (10,  8),
(11, 25), (12, 12);

-- Holiday requests
INSERT INTO HolidayRequests (request_id, crew_id, start_date, end_date, status, request_date) VALUES
(1, 1,  '2026-07-01', '2026-07-14', 'approved', '2026-03-10'),
(2, 8,  '2026-08-01', '2026-08-21', 'pending',  '2026-04-01'),
(3, 10, '2026-06-15', '2026-07-15', 'approved', '2026-02-20'),
(4, 3,  '2026-09-01', '2026-09-10', 'rejected', '2026-04-05');

-- Passengers
INSERT INTO Passenger (passenger_id, first_name, last_name, email, phone, birth_date, nationality, passport_number) VALUES
(1,  'Alice',   'Fontaine',     'alice.fontaine@email.com',  '+33601010101', '1985-03-12', 'French',   'FR1234567'),
(2,  'Bob',     'Smith',        'bob.smith@email.com',       '+44701010101', '1990-07-24', 'British',  'GB9876543'),
(3,  'Carlos',  'Gomez',        'carlos.gomez@email.com',    '+34601010101', '1978-11-05', 'Spanish',  'ES5556677'),
(4,  'Diana',   'Muller',       'diana.muller@email.com',    '+49601010101', '1995-01-30', 'German',   'DE3334455'),
(5,  'Ethan',   'Brown',        'ethan.brown@email.com',     '+12125550101', '1988-06-18', 'American', 'US1112233'),
(6,  'Fatima',  'Al-Rashid',    'fatima.al@email.com',       '+97150101010', '1993-09-09', 'Emirati',  'AE6667788'),
(7,  'George',  'Papadopoulos', 'george.p@email.com',        '+30601010101', '1982-04-22', 'Greek',    'GR2223344'),
(8,  'Hannah',  'Johansson',    'hannah.j@email.com',        '+46701010101', '1999-12-01', 'Swedish',  'SE8889900'),
(9,  'Ivan',    'Petrov',       'ivan.petrov@email.com',     '+79001010101', '1975-08-14', 'Russian',  'RU4445566'),
(10, 'Julia',   'Tanaka',       'julia.tanaka@email.com',    '+81901010101', '1991-02-28', 'Japanese', 'JP7778899');

-- Frequent flyers
INSERT INTO FrequentFlyer (ff_id, passenger_id, ff_number, tier, points_balance, total_points_earned, enrolled_date) VALUES
(1, 1, 'FF-000001', 'Gold',      8500, 45000, '2015-06-01'),
(2, 2, 'FF-000002', 'Silver',    3200, 18000, '2018-03-15'),
(3, 5, 'FF-000003', 'Platinum', 22000, 95000, '2012-01-10'),
(4, 7, 'FF-000004', 'Blue',       500,  2000, '2023-11-20'),
(5, 9, 'FF-000005', 'Silver',    4100, 21000, '2017-07-04');

-- Flight seats (lights 1 and 3)
INSERT INTO FlightSeat (seat_id, flight_id, airplane_id, seat_number, travel_class, is_available, is_window, is_aisle) VALUES
-- Flight 1 (Airbus A320)
(1,  1, 2, '1A',  'first',    TRUE, TRUE,  FALSE),
(2,  1, 2, '1B',  'first',    TRUE, FALSE, FALSE),
(3,  1, 2, '1C',  'first',    TRUE, FALSE, TRUE),
(4,  1, 2, '1D',  'first',    TRUE, TRUE,  FALSE),
(5,  1, 2, '1E',  'first',    TRUE, FALSE, FALSE),
(6,  1, 2, '5A',  'business', TRUE, TRUE,  FALSE),
(7,  1, 2, '5B',  'business', TRUE, FALSE, TRUE),
(8,  1, 2, '5C',  'business', TRUE, FALSE, FALSE),
(9,  1, 2, '5D',  'business', TRUE, TRUE,  FALSE),
(10, 1, 2, '5E',  'business', TRUE, FALSE, TRUE),
(11, 1, 2, '10A', 'economy',  TRUE, TRUE,  FALSE),
(12, 1, 2, '10B', 'economy',  TRUE, FALSE, FALSE),
(13, 1, 2, '10C', 'economy',  TRUE, FALSE, TRUE),
(14, 1, 2, '10D', 'economy',  TRUE, TRUE,  FALSE),
(15, 1, 2, '10E', 'economy',  TRUE, FALSE, FALSE),
-- Flight 3 (Boeing 777)
(16, 3, 3, '1A',  'first',    TRUE, TRUE,  FALSE),
(17, 3, 3, '1B',  'first',    TRUE, FALSE, FALSE),
(18, 3, 3, '1C',  'first',    TRUE, FALSE, TRUE),
(19, 3, 3, '5A',  'business', TRUE, TRUE,  FALSE),
(20, 3, 3, '5B',  'business', TRUE, FALSE, TRUE),
(21, 3, 3, '10A', 'economy',  TRUE, TRUE,  FALSE),
(22, 3, 3, '10B', 'economy',  TRUE, FALSE, FALSE),
(23, 3, 3, '10C', 'economy',  TRUE, FALSE, TRUE),
(24, 3, 3, '10D', 'economy',  TRUE, TRUE,  FALSE),
(25, 3, 3, '10E', 'economy',  TRUE, FALSE, FALSE);

-- Tickets
INSERT INTO Ticket (passenger_id, flight_id, seat_id, booking_date, travel_class, price, ff_id, booked) VALUES
(1,  1, 1,  '2026-04-01 10:00:00', 'first',    450.00, 1, TRUE),
(2,  1, 6,  '2026-04-02 11:00:00', 'business', 280.00, 2, TRUE),
(3,  1, 11, '2026-04-03 09:00:00', 'economy',  120.00, NULL, TRUE),
(4,  3, 16, '2026-04-05 14:00:00', 'first',   1800.00, 3, TRUE),
(5,  3, 19, '2026-04-06 16:00:00', 'business', 950.00, 4, TRUE),
(6,  3, 21, '2026-04-07 08:00:00', 'economy',  420.00, 5, TRUE),
(7,  3, 22, '2026-04-08 10:00:00', 'economy',  420.00, NULL, TRUE),
(8,  3, 23, '2026-04-09 12:00:00', 'economy',  420.00, NULL, TRUE),
(9,  1, 12, '2026-04-10 15:00:00', 'economy',  120.00, NULL, TRUE),
(10, 1, 13, '2026-04-11 17:00:00', 'economy',  120.00, NULL, TRUE);

-- Mark booked seats as unavailable
UPDATE FlightSeat SET is_available = FALSE WHERE seat_id IN (1, 6, 11, 12, 13, 16, 19, 21, 22, 23);

-- FF points transactions
INSERT INTO FFPointsTransaction (transaction_id, ff_id, transaction_date, transaction_type, points, related_ticket_id, notes) VALUES
(1, 1, '2026-04-01 10:00:00', 'earn',   450,   1, 'Points earned on AF101 first class'),
(2, 2, '2026-04-02 11:00:00', 'earn',   196,   2, 'Points earned on AF101 business'),
(3, 3, '2026-04-05 14:00:00', 'earn',  1800,   4, 'Points earned on AF303 first class'),
(4, 4, '2026-04-06 16:00:00', 'earn',   475,   5, 'Points earned on AF303 business'),
(5, 5, '2026-04-07 08:00:00', 'earn',   210,   6, 'Points earned on AF303 economy'),
(6, 3, '2026-03-01 00:00:00', 'redeem', -5000, NULL, 'Upgrade redemption');




-- ALl queries :

--Flight and crew queries


-- return the airplane that can operate the flight 1 in terms of timetable
SELECT
    a.airplane_id,
    a.model,
    a.current_location,
    a.flight_status
FROM Airplane a
JOIN Flights f_target
    ON f_target.flight_id = 1
WHERE NOT EXISTS (
    SELECT 1
    FROM FlightAirplaneAssignment faa
    JOIN Flights f_assigned
        ON faa.flight_id = f_assigned.flight_id
    WHERE faa.airplane_id = a.airplane_id
      AND faa.assignment_status IN ('planned', 'confirmed')
      AND f_assigned.outbound_departure_time < f_target.return_arrival_time
      AND f_assigned.return_arrival_time > f_target.outbound_departure_time
);


--query that assigns when possible, plane i to flight j 

INSERT INTO FlightAirplaneAssignment (
    assignment_id,
    flight_id,
    airplane_id,
    assignment_status
)
SELECT
    1, -- assignement_id choice
    1, -- flight_id we want to insert a plane in
    2, -- airplane_id we want to assignthe flight on
    'planned' --status
WHERE EXISTS (
    SELECT 1
    FROM Airplane a
    JOIN Flights f
        ON f.flight_id = 1
    JOIN Checks c
        ON a.airplane_id = c.airplane_id
    WHERE a.airplane_id = 2
      AND a.range_km >= f.distance_km
      AND a.min_runway_length_m <= f.departure_runway_length_m
      AND a.min_runway_length_m <= f.arrival_runway_length_m
      AND (c.next_check_A IS NULL OR c.next_check_A > DATE(f.outbound_departure_time))
      AND (c.next_check_B IS NULL OR c.next_check_B > DATE(f.outbound_departure_time))
      AND (c.next_check_C IS NULL OR c.next_check_C > DATE(f.outbound_departure_time))
      AND (c.next_check_D IS NULL OR c.next_check_D > DATE(f.outbound_departure_time))
      AND c.last_flight_incident_level IN ('none', 'light')
)
AND EXISTS (
    SELECT 1
    FROM Airplane a
    JOIN Flights f_target
        ON f_target.flight_id = 1
    WHERE a.airplane_id = 2
      AND NOT EXISTS (
          SELECT 1
          FROM FlightAirplaneAssignment faa
          JOIN Flights f_assigned
              ON faa.flight_id = f_assigned.flight_id
          WHERE faa.airplane_id = a.airplane_id
            AND faa.assignment_status IN ('planned', 'confirmed')
            AND f_assigned.outbound_departure_time < f_target.return_arrival_time
            AND f_assigned.return_arrival_time > f_target.outbound_departure_time
      )
);




-- return all crews that can perform outbound and return trip for a flight; here for a pilot 

--Outbound
SELECT c.* FROM Crew c
JOIN Flights f ON f.flight_id = 1
JOIN FlightAirplaneAssignment faa ON faa.flight_id = f.flight_id
JOIN Airplane a ON a.airplane_id = faa.airplane_id
WHERE c.role = 'Pilot'
  AND c.status = 'active'
  AND c.haul_type = f.flight_type
  AND c.airplane_model_qualification = a.model
  AND NOT EXISTS (
      SELECT 1 FROM CrewAssignment ca
      WHERE ca.crew_id = c.crew_id
        AND ca.status <> 'cancelled'
        AND ca.start_time < f.outbound_arrival_time
        AND ca.end_time > f.outbound_departure_time
  );

-- Return
SELECT c.* FROM Crew c
JOIN Flights f ON f.flight_id = 1
JOIN FlightAirplaneAssignment faa ON faa.flight_id = f.flight_id
JOIN Airplane a ON a.airplane_id = faa.airplane_id
WHERE c.role = 'Pilot'
  AND c.status = 'active'
  AND c.haul_type = f.flight_type
  AND c.airplane_model_qualification = a.model
  AND NOT EXISTS (
      SELECT 1 FROM CrewAssignment ca
      WHERE ca.crew_id = c.crew_id
        AND ca.status <> 'cancelled'
        AND ca.start_time < f.return_arrival_time
        AND ca.end_time > f.return_departure_time
  );

-- Outbound + Return
SELECT c.* FROM Crew c
JOIN Flights f ON f.flight_id = 1
JOIN FlightAirplaneAssignment faa ON faa.flight_id = f.flight_id
JOIN Airplane a ON a.airplane_id = faa.airplane_id
WHERE c.role = 'Pilot'
  AND c.status = 'active'
  AND c.haul_type = f.flight_type
  AND c.airplane_model_qualification = a.model
  AND NOT EXISTS (
      SELECT 1 FROM CrewAssignment ca
      WHERE ca.crew_id = c.crew_id
        AND ca.status <> 'cancelled'
        AND ca.start_time < f.return_arrival_time
        AND ca.end_time > f.outbound_departure_time
  );



--Query to assign if possible, a crew to outbound flight, return flight, or outbound and return flight:
-- Outbound

INSERT INTO CrewAssignment (
    assignment_id,
    crew_id,
    activity_type,
    flight_id,
    outbound_assigned,
    return_assigned,
    duty_role,
    start_time,
    end_time,
    location,
    notes,
    status
)
SELECT
    1,
    c.crew_id,
    'flight',
    f.flight_id,
    TRUE,
    FALSE,
    'Pilot',
    f.outbound_departure_time,
    f.outbound_arrival_time,
    f.departure_airport,
    NULL,
    'planned'
FROM Crew c
JOIN Flights f
    ON f.flight_id = 1
JOIN FlightAirplaneAssignment faa
    ON faa.flight_id = f.flight_id
   AND faa.assignment_status IN ('planned', 'confirmed')
JOIN Airplane a
    ON a.airplane_id = faa.airplane_id
WHERE c.crew_id = 1
  AND c.role = 'Pilot'
  AND c.status = 'active'
  AND c.haul_type = f.flight_type
  AND c.airplane_model_qualification = a.model
  AND NOT EXISTS (
      SELECT 1
      FROM CrewAssignment ca
      WHERE ca.crew_id = c.crew_id
        AND ca.status <> 'cancelled'
        AND ca.start_time < f.outbound_arrival_time
        AND ca.end_time > f.outbound_departure_time
  );


-- returrn
INSERT INTO CrewAssignment (
    assignment_id,
    crew_id,
    activity_type,
    flight_id,
    outbound_assigned,
    return_assigned,
    duty_role,
    start_time,
    end_time,
    location,
    notes,
    status
)
SELECT
    1,  --assignement_id
    c.crew_id,
    'flight',
    f.flight_id,
    FALSE,
    TRUE,
    'Pilot',
    f.return_departure_time,
    f.return_arrival_time,
    f.arrival_airport,
    NULL,
    'planned'
FROM Crew c
JOIN Flights f
    ON f.flight_id = 1   --flight id here
JOIN FlightAirplaneAssignment faa
    ON faa.flight_id = f.flight_id
   AND faa.assignment_status IN ('planned', 'confirmed')
JOIN Airplane a
    ON a.airplane_id = faa.airplane_id
WHERE c.crew_id = 1  --crew id here
  AND c.role = 'Pilot'
  AND c.status = 'active'
  AND c.haul_type = f.flight_type
  AND c.airplane_model_qualification = a.model
  AND NOT EXISTS (
      SELECT 1
      FROM CrewAssignment ca
      WHERE ca.crew_id = c.crew_id
        AND ca.status <> 'cancelled'
        AND ca.start_time < f.return_arrival_time
        AND ca.end_time > f.return_departure_time
  );


--Outbound and return
INSERT INTO CrewAssignment (
    assignment_id,
    crew_id,
    activity_type,
    flight_id,
    outbound_assigned,
    return_assigned,
    duty_role,
    start_time,
    end_time,
    location,
    notes,
    status
)
SELECT
    1,
    c.crew_id,
    'flight',
    f.flight_id,
    TRUE,
    TRUE,
    'Pilot',
    f.outbound_departure_time,
    f.return_arrival_time,
    f.departure_airport,
    NULL,
    'planned'
FROM Crew c
JOIN Flights f
    ON f.flight_id = 1
JOIN FlightAirplaneAssignment faa
    ON faa.flight_id = f.flight_id
   AND faa.assignment_status IN ('planned', 'confirmed')
JOIN Airplane a
    ON a.airplane_id = faa.airplane_id
WHERE c.crew_id = 5
  AND c.role = 'Pilot'
  AND c.status = 'active'
  AND c.haul_type = f.flight_type
  AND c.airplane_model_qualification = a.model
  AND NOT EXISTS (
      SELECT 1
      FROM CrewAssignment ca
      WHERE ca.crew_id = c.crew_id
        AND ca.status <> 'cancelled'
        AND ca.start_time < f.return_arrival_time
        AND ca.end_time > f.outbound_departure_time
  );


--query to show all crew assignments of a specific crew
SELECT *
FROM CrewAssignement
WHERE crew_id = 42 --specific crew
ORDER BY start_time;


--query to show all crew assignments that overlap for a specific crew 
SELECT 
    a.assignment_id AS assignment_1,
    b.assignment_id AS assignment_2,
    a.start_time,
    a.end_time,
    b.start_time,
    b.end_time
FROM CrewAssignement a
JOIN CrewAssignement b 
    ON a.crew_id = b.crew_id
    AND a.assignment_id < b.assignment_id
WHERE a.crew_id = 42 -- crew spÃ©cifique
AND a.start_time < b.end_time
AND a.end_time > b.start_time;

--query to show crews who were assigned an incorrect role for a flight
SELECT
    c.crew_id,
    c.first_name,
    c.last_name,
    c.role AS crew_role,
    ca.assignment_id,
    ca.duty_role AS assigned_role,
    ca.flight_id
FROM CrewAssignment ca
JOIN Crew c
    ON ca.crew_id = c.crew_id
WHERE ca.activity_type = 'flight'
  AND c.role <> ca.duty_role;

--query to show crew that was assigned to an incorrect flight in terms of flight haul type

SELECT
    c.crew_id,
    c.first_name,
    c.last_name,
    c.haul_type AS crew_qualification,
    ca.assignment_id,
    ca.flight_id,
    f.flight_number,
    f.flight_type AS assigned_flight_type,
    ca.start_time,
    ca.end_time
FROM CrewAssignment ca
JOIN Crew c
    ON ca.crew_id = c.crew_id
JOIN Flights f
    ON ca.flight_id = f.flight_id
WHERE ca.activity_type = 'flight'
  AND (
        (c.haul_type = 'short_haul' AND f.flight_type IN ('medium_haul', 'long_haul'))
     OR (c.haul_type = 'medium_haul' AND f.flight_type = 'long_haul')
  )
ORDER BY c.crew_id, ca.start_time;



-- Query for full passenger 9 summary
SELECT
    p.passenger_id,
    p.first_name,
    p.last_name,
    p.email,
    p.nationality,
    p.passport_number,
    ff.ff_number,
    ff.tier             AS ff_tier,
    ff.points_balance,
    f.flight_number,
    f.departure_airport || ' - ' || f.arrival_airport AS route,
    f.outbound_departure_time,
    f.return_arrival_time,
    f.flight_type,
    t.ticket_id,
    t.travel_class,
    t.price,
    fs.seat_number,
    fs.is_window,
    fs.is_aisle,
    t.booking_date,
    t.booked
FROM       Passenger    p
LEFT JOIN  FrequentFlyer ff  ON ff.passenger_id  = p.passenger_id --join passengers even if not ff
LEFT JOIN  Ticket        t   ON t.passenger_id   = p.passenger_id AND t.booked = TRUE
LEFT JOIN  Flights       f   ON f.flight_id       = t.flight_id
LEFT JOIN  FlightSeat    fs  ON fs.seat_id        = t.seat_id
WHERE      p.passenger_id = 9
ORDER BY   f.outbound_departure_time

--all available seats on flight 3 for passenger 9, grouped by class
SELECT
    fs.seat_id,
    fs.seat_number,
    fs.travel_class,
    fs.is_window,
    fs.is_aisle
FROM   FlightSeat fs
WHERE  fs.flight_id    = 3
  AND  fs.is_available = TRUE
  AND NOT EXISTS ( --check ticket is not booked at ticket level if so exclude it
      SELECT 1
      FROM   Ticket t
      WHERE  t.seat_id = fs.seat_id
        AND  t.booked  = TRUE
  )
  AND NOT EXISTS (
      SELECT 1
      FROM   Ticket t2
      WHERE  t2.passenger_id = 9
        AND  t2.flight_id    = fs.flight_id
        AND  t2.booked       = TRUE --one passenger = one ticket rule exclude if qlready has ticket
  )
ORDER BY 
    CASE fs.travel_class
        WHEN 'first'    THEN 1
        WHEN 'business' THEN 2
        ELSE 3
    END,
    fs.seat_number;



--Full Query to book a ticket

-- a. Book the ticket
INSERT INTO Ticket (
    passenger_id,
    flight_id,
    seat_id,
    booking_date,
    travel_class,
    price,
    ff_id,
    booked
)
VALUES (
    9,
    3,
    24,
    NOW(), --booking data
    'economy',
    420.00, --ticket price
    (SELECT ff_id FROM FrequentFlyer WHERE passenger_id = 9), --sub query to find ff_id if none then null (ff_id is nullable)
    TRUE
); --- book the ticket, ticket id is serial so auto updates

-- b. Mark seat unavailable
UPDATE FlightSeat
SET    is_available = FALSE
WHERE  seat_id = 24
  AND  is_available = TRUE; --guard condition

-- c. Add FF points transaction if passenger enrolled
INSERT INTO FFPointsTransaction (
    transaction_id,
    ff_id,
    transaction_date,
    transaction_type,
    points,
    related_ticket_id,
    notes
)
SELECT
    (SELECT COALESCE(MAX(transaction_id), 0) + 1 FROM FFPointsTransaction), --generate new unique transaction_id
    ff.ff_id,
    NOW(),
    'earn', --transaction type
    ROUND(420.00 * 0.5),  -- 0.5 points per currency
    t.ticket_id, --link transaction to ticket for bookeeping
    'Points earned on flight 3 economy'
FROM   FrequentFlyer ff -- empty or row zith ff.ff_id and t.ticket_id
JOIN   Ticket t
    ON  t.passenger_id = ff.passenger_id
   AND  t.flight_id    = 3
   AND  t.booked       = TRUE
WHERE  ff.passenger_id = 9; --if no FF, join fails and insert is voided; good as only ff earn points

-- d. Update FF points balance if ff member
UPDATE FrequentFlyer
SET    points_balance       = points_balance       + ROUND(420.00 * 0.5),
       total_points_earned  = total_points_earned  + ROUND(420.00 * 0.5)
WHERE  passenger_id = 9;

-- Sanity check that the ticket was created and booked
SELECT t.ticket_id, t.passenger_id, t.flight_id, t.seat_id,
       t.travel_class, t.price, t.ff_id, t.booked, t.booking_date
FROM   Ticket t
WHERE  t.passenger_id = 9
  AND  t.flight_id    = 3;

-- Sanity check that the seat is now unavailable
SELECT seat_id, seat_number, travel_class, is_available
FROM   FlightSeat
WHERE  seat_id = 24;


--Query to cancel ticket
-- Reverse FF points
INSERT INTO FFPointsTransaction ( --insert point adjustment into transaction history
    transaction_id, ff_id, transaction_date,
    transaction_type, points, related_ticket_id, notes
)
SELECT
    (SELECT COALESCE(MAX(transaction_id), 0) + 1 FROM FFPointsTransaction),
    fpt.ff_id,
    NOW(),
    'adjustment',
    -fpt.points,
    fpt.related_ticket_id, 
    'Points deducted: ticket cancellation'
FROM   FFPointsTransaction fpt
JOIN   Ticket t ON t.ticket_id = fpt.related_ticket_id --find original earn transaction for this ticket
WHERE  t.passenger_id       = 9
  AND  t.flight_id          = 3
  AND  fpt.transaction_type = 'earn';

--deduct points from ticket booking
UPDATE FrequentFlyer ff
SET    points_balance = points_balance - fpt.points,
	   total_points_earned = total_points_earned - fpt.points
FROM  ( --subquery finds point ammount to subtract (original earn amount)
    SELECT fpt.points
    FROM   FFPointsTransaction fpt
    JOIN   Ticket t ON t.ticket_id = fpt.related_ticket_id
    WHERE  t.passenger_id       = 9
      AND  t.flight_id          = 3
      AND  fpt.transaction_type = 'earn'
) fpt
WHERE  ff.passenger_id = 9;

--free the seat
UPDATE FlightSeat
SET    is_available = TRUE
WHERE  seat_id = (
    SELECT seat_id FROM Ticket
    WHERE  passenger_id = 9
      AND  flight_id    = 3
      AND  booked       = TRUE
);

--delete the ticket
DELETE FROM Ticket
WHERE  passenger_id = 9
  AND  flight_id    = 3
  AND  booked       = TRUE;

-- Sanity check ticket is cancelled
SELECT * FROM Ticket
WHERE  passenger_id = 9
  AND  flight_id    = 3;
-- should return 0 rows

-- Sanity check the seat is available again
SELECT seat_id, seat_number, is_available
FROM   FlightSeat
WHERE  seat_id = 24;

-- Sanity check the transaction was logged
SELECT * FROM FFPointsTransaction
WHERE  ff_id = (SELECT ff_id FROM FrequentFlyer WHERE passenger_id = 9)
ORDER BY transaction_date;


--FrequentFlyer Queries

-- Show passengers eligible for tier promotion
WITH tier_thresholds(tier, min_points, next_tier) AS (
    VALUES
        ('Blue',    5000,     'Silver'),
        ('Silver',  10000, 'Gold'),
        ('Gold',    20000, 'Platinum'),
        ('Platinum',0 , 'Platinum') --platinum is maximum tier 
)
SELECT
    p.first_name,
    p.last_name,
    ff.tier AS current_tier,
    tt.next_tier AS eligible_for,
    ff.total_points_earned,
    tt.min_points AS threshold_required
FROM FrequentFlyer ff
JOIN Passenger p ON p.passenger_id = ff.passenger_id
JOIN tier_thresholds tt ON tt.tier = ff.tier
WHERE ff.total_points_earned >= tt.min_points 
  AND ff.tier <> tt.next_tier --not already at next tier (platinum)
ORDER BY ff.total_points_earned DESC;

-- Show passengers who can afford tier upgrade right now
WITH tier_thresholds(tier, upgrade_cost, next_tier) AS (
    VALUES
        ('Blue',     5000,  'Silver'),
        ('Silver',  10000,  'Gold'),
        ('Gold',    20000,  'Platinum'),
        ('Platinum', 0,     'Platinum')
)
SELECT
    p.first_name,
    p.last_name,
    ff.tier AS current_tier,
    tt.next_tier AS can_upgrade_to,
    ff.points_balance, --current points
    tt.upgrade_cost AS cost_to_upgrade,
    ff.points_balance - tt.upgrade_cost AS balance_after_upgrade
FROM FrequentFlyer ff
JOIN Passenger p ON p.passenger_id = ff.passenger_id
JOIN tier_thresholds tt ON tt.tier = ff.tier
WHERE ff.points_balance >= tt.upgrade_cost --enough points now for upgrade
  AND ff.tier <> 'Platinum'  --no upgrade fafter Platinum
ORDER BY ff.points_balance DESC;


--Query to spend points on tier upgrade
INSERT INTO FFPointsTransaction (
    transaction_id, 
    ff_id, 
    transaction_type, 
    points, 
    related_ticket_id, 
    notes
)
SELECT
    (SELECT COALESCE(MAX(transaction_id), 0) + 1 FROM FFPointsTransaction),
    ff.ff_id,
    'redeem',
    -CASE ff.tier 
        WHEN 'Blue'   THEN 5000 --cost depends on current tier
        WHEN 'Silver' THEN 10000
        WHEN 'Gold'   THEN 20000
    END,
    NULL, --not related to a ticket
    'Tier upgrade redemption'
FROM FrequentFlyer ff
WHERE ff.ff_id = 3
  AND ff.tier != 'Platinum'
  AND ff.points_balance >= CASE ff.tier --insert transaction if enough points
        WHEN 'Blue'   THEN 5000
        WHEN 'Silver' THEN 10000
        WHEN 'Gold'   THEN 20000
    END;

--deduct points from balance
UPDATE FrequentFlyer ff
SET points_balance = points_balance - CASE ff.tier
        WHEN 'Blue'   THEN 5000
        WHEN 'Silver' THEN 10000
        WHEN 'Gold'   THEN 20000
    END
WHERE ff.ff_id = 3
  AND ff.tier != 'Platinum'
  AND ff.points_balance >= CASE ff.tier
        WHEN 'Blue'   THEN 5000
        WHEN 'Silver' THEN 10000
        WHEN 'Gold'   THEN 20000
    END;

--upgrade tier if balance was actually deducted 
UPDATE FrequentFlyer ff1
SET tier = CASE tier
        WHEN 'Blue'   THEN 'Silver'
        WHEN 'Silver' THEN 'Gold'
        WHEN 'Gold'   THEN 'Platinum'
    END
WHERE ff_id = 3
  AND tier != 'Platinum'
  AND EXISTS ( --only upgrade if a transaction was logged 
      SELECT 1 
      FROM FFPointsTransaction fpt
      WHERE fpt.ff_id = 3
        AND fpt.transaction_type = 'redeem'
        AND fpt.notes = 'Tier upgrade redemption'
        AND fpt.transaction_date >= NOW() - INTERVAL '1 second' --want to verify the latest transaction not an ealier one
  );


-- Sanity check the transaction was logged
SELECT * FROM FFPointsTransaction
WHERE  ff_id = (SELECT ff_id FROM FrequentFlyer WHERE passenger_id = 5)
ORDER BY transaction_date;

-- Tier and point balance check
SELECT ff_id, passenger_id, tier, points_balance, total_points_earned
FROM FrequentFlyer
WHERE ff_id = 3;




----Queries to check integrity

--Query to find passenger booked mulitple times on the same flight
SELECT
    passenger_id,
    flight_id,
    COUNT(*) AS ticket_count --count all rows in groups
FROM Ticket
WHERE booked = TRUE
GROUP BY passenger_id, flight_id
HAVING COUNT(*) > 1; --passengers with multiple booked tickets on same flight

--Query to detect overbooking
WITH booked_counts AS (
    SELECT
        t.flight_id,
        t.travel_class,
        COUNT(*) AS active_tickets
    FROM   Ticket t
    WHERE  t.booked = TRUE
    GROUP BY t.flight_id, t.travel_class --count total active tickets per class for flight
),
seat_counts AS (
    SELECT
        flight_id,
        travel_class,
        COUNT(*) AS total_seats
    FROM   FlightSeat
    GROUP BY flight_id, travel_class --count total seats per class for flight
)
SELECT
    f.flight_number,
    f.departure_airport || ' - ' || f.arrival_airport AS route,
    bc.travel_class,
    bc.active_tickets,
    sc.total_seats,
    bc.active_tickets - sc.total_seats AS overbooked_by
FROM   booked_counts  bc
JOIN   seat_counts    sc
    ON  sc.flight_id    = bc.flight_id
    AND sc.travel_class = bc.travel_class
JOIN   Flights f
    ON  f.flight_id = bc.flight_id
WHERE  bc.active_tickets > sc.total_seats --join condition is more tickets than seats so overbooked
ORDER BY overbooked_by DESC; ---returns nothing as no overbooking rn: unique on seat ID in ticket table ensures no more tickets than seats



---At this points the top two queries return nothing as the database should be working properly