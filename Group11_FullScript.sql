

/* ===== BEGIN schema-create.sql ===== */

/* 
=============================================
DAMG6210 - Group Project Part 4
Group 11: Xinhao Xie, Douglas Aldridge, Anuarbek Ibrashev, Emely Andrade
11/23/2025
============================================= 
*/

USE master;
GO

IF EXISTS (SELECT name
FROM sys.databases
WHERE name = 'Group_11_Project')  
BEGIN
    ALTER DATABASE Group_11_Project SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Group_11_Project;
END
GO

CREATE DATABASE Group_11_Project;
GO

USE Group_11_Project;
GO

-- event cateogories must have a unique name
CREATE TABLE Event_Category
(
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category_name NVARCHAR(50) NOT NULL UNIQUE
);
GO

-- venue must have a name, location, and capacity > 0
CREATE TABLE Venue
(
    venue_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    location NVARCHAR(200) NOT NULL,
    capacity INT NOT NULL CHECK (capacity > 0)
);
GO

-- equipment must have a name, quantity >= 0, and status from a predefined list
CREATE TABLE Equipment
(
    equipment_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    quantity INT NOT NULL CHECK (quantity >= 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('Available', 'In Use'))
);
GO

-- student must have a name, email, major, and gradution year
CREATE TABLE Student
(
    student_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    major NVARCHAR(100),
    year INT 
);
GO

-- event organizer must have a name and type
CREATE TABLE Organizer
(
    organizer_id INT IDENTITY(1,1) PRIMARY KEY,
    org_type VARCHAR(50) NOT NULL,
    name NVARCHAR(100) NOT NULL
);
GO

-- event coordinator must have a name and email
CREATE TABLE Coordinator
(
    coordinator_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    department NVARCHAR(100),
    role_title NVARCHAR(100),
    phone VARCHAR(20)
);
GO

-- events must have a title, category, venue, organizer, scheduled start and end times
CREATE TABLE Event
(
    event_id INT IDENTITY(1,1) PRIMARY KEY,
    title NVARCHAR(200) NOT NULL,
    description NVARCHAR(MAX),
    category_id INT NOT NULL,
    venue_id INT NOT NULL,
    organizer_id INT NOT NULL,
    scheduled_start DATETIME NOT NULL,
    scheduled_end DATETIME NOT NULL,

    CONSTRAINT FK_Event_Category FOREIGN KEY (category_id) 
        REFERENCES Event_Category(category_id),
    CONSTRAINT FK_Event_Venue FOREIGN KEY (venue_id) 
        REFERENCES Venue(venue_id),
    CONSTRAINT FK_Event_Organizer FOREIGN KEY (organizer_id) 
        REFERENCES Organizer(organizer_id),
    -- business rule - end time must be after start time
    CONSTRAINT CHK_Event_Times CHECK (scheduled_end > scheduled_start)
);
GO

-- event-coordinator assignment (many-to-many)
CREATE TABLE Event_Coordinator
(
    event_id INT NOT NULL,
    coordinator_id INT NOT NULL,
    role_description NVARCHAR(200),

    -- composite PK
    CONSTRAINT PK_Event_Coordinator PRIMARY KEY (event_id, coordinator_id),
    CONSTRAINT FK_EventCoord_Event FOREIGN KEY (event_id) 
        REFERENCES Event(event_id),
    CONSTRAINT FK_EventCoord_Coordinator FOREIGN KEY (coordinator_id) 
        REFERENCES Coordinator(coordinator_id)
);
GO

-- event-volunteer assignment (many-to-many)
CREATE TABLE Event_Volunteer
(
    event_id INT NOT NULL,
    student_id INT NOT NULL,
    hours_worked DECIMAL(5,2) NULL,
    role NVARCHAR(100),

    -- composite PK
    CONSTRAINT PK_Event_Volunteer PRIMARY KEY (event_id, student_id),
    CONSTRAINT FK_EventVol_Event FOREIGN KEY (event_id) 
        REFERENCES Event(event_id),
    CONSTRAINT FK_EventVol_Student FOREIGN KEY (student_id) 
        REFERENCES Student(student_id)
);
GO

-- event-equipment assignment (many-to-many), must have quantity assigned > 0
CREATE TABLE Event_Equipment
(
    event_id INT NOT NULL,
    equipment_id INT NOT NULL,
    quantity_assigned INT NOT NULL CHECK (quantity_assigned > 0),

    -- composite PK
    CONSTRAINT PK_Event_Equipment PRIMARY KEY (event_id, equipment_id),
    CONSTRAINT FK_EventEquip_Event FOREIGN KEY (event_id) 
        REFERENCES Event(event_id),
    CONSTRAINT FK_EventEquip_Equipment FOREIGN KEY (equipment_id) 
        REFERENCES Equipment(equipment_id)
);
GO

-- event registration must have a date and status
CREATE TABLE Registration
(
    registration_id INT IDENTITY(1,1) PRIMARY KEY,
    event_id INT NOT NULL,
    student_id INT NULL,
    external_name NVARCHAR(100),
    external_email VARCHAR(100),
    registration_date DATE NOT NULL DEFAULT GETDATE(),
    ticket_status VARCHAR(20) NOT NULL DEFAULT 'Pending'
        CHECK (ticket_status IN ('Pending', 'Confirmed', 'Cancelled', 'Attended')),
    price DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (price >= 0),

    CONSTRAINT FK_Registration_Event FOREIGN KEY (event_id) 
        REFERENCES Event(event_id),
    CONSTRAINT FK_Registration_Student FOREIGN KEY (student_id) 
        REFERENCES Student(student_id)
);
GO

-- event feedback must have a rating between 1 and 5
CREATE TABLE Feedback
(
    feedback_id INT IDENTITY(1,1) PRIMARY KEY,
    event_id INT NOT NULL,
    student_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment NVARCHAR(MAX),

    CONSTRAINT FK_Feedback_Event FOREIGN KEY (event_id) 
        REFERENCES Event(event_id),
    CONSTRAINT FK_Feedback_Student FOREIGN KEY (student_id) 
        REFERENCES Student(student_id),
    -- business rule - only one feedback per student per event
    CONSTRAINT UQ_Feedback_One_Per_Student UNIQUE (event_id, student_id)
);
GO

-- survey response must have answers
CREATE TABLE Survey_Response
(
    survey_id INT IDENTITY(1,1) PRIMARY KEY,
    event_id INT NOT NULL,
    student_id INT NOT NULL,
    answers NVARCHAR(MAX) NOT NULL,

    CONSTRAINT FK_Survey_Event FOREIGN KEY (event_id) 
        REFERENCES Event(event_id),
    CONSTRAINT FK_Survey_Student FOREIGN KEY (student_id) 
        REFERENCES Student(student_id)
);
GO


/* ===== END schema-create.sql ===== */



/* ===== BEGIN 03_add_computed_event_duration.sql ===== */

/* 
=============================================
DAMG6210 - Group Project Part 4
Group 11: Computed Column Script
Adds: Event.duration_minutes
Run AFTER schema-create.sql
=============================================
*/

USE Group_11_Project;
GO

/* 
=============================================
Computed Column: duration_minutes
Description: Automatically calculates the event duration in minutes using scheduled_start and scheduled_end.
=============================================
*/

IF COL_LENGTH('dbo.Event', 'duration_minutes') IS NULL
BEGIN
    PRINT 'Adding computed column Event.duration_minutes...';

    ALTER TABLE dbo.Event
    ADD duration_minutes AS 
        DATEDIFF(MINUTE, scheduled_start, scheduled_end);
END
ELSE
BEGIN
    PRINT 'Computed column Event.duration_minutes already exists. Skipping...';
END
GO

/* ===== END 03_add_computed_event_duration.sql ===== */



/* ===== BEGIN 03b_add_computed_event_total_registrations.sql ===== */

/* 
=============================================
DAMG6210 - Group Project Part 4
Group 11: Computed Column Script (2)
Adds: Event.total_registrations
  - Uses a scalar function to count rows in Registration for each event_id
Run AFTER:
  - 01_schema_create.sql
  - Registration table exists
=============================================
*/

USE Group_11_Project;
GO

/* 1. Create scalar function to count registrations per event */

IF OBJECT_ID('dbo.fn_TotalRegistrations', 'FN') IS NOT NULL
BEGIN
    DROP FUNCTION dbo.fn_TotalRegistrations;
END
GO

CREATE FUNCTION dbo.fn_TotalRegistrations
(
    @EventId INT
)
RETURNS INT
AS
BEGIN
    DECLARE @cnt INT;

    SELECT @cnt = COUNT(*)
    FROM dbo.Registration
    WHERE event_id = @EventId;

    RETURN ISNULL(@cnt, 0);
END;
GO


/* 2. Add computed column on Event using the function */

IF COL_LENGTH('dbo.Event', 'total_registrations') IS NULL
BEGIN
    PRINT 'Adding computed column Event.total_registrations...';

    ALTER TABLE dbo.Event
    ADD total_registrations AS dbo.fn_TotalRegistrations(event_id);
END
ELSE
BEGIN
    PRINT 'Computed column Event.total_registrations already exists. Skipping...';
END
GO

/* ===== END 03b_add_computed_event_total_registrations.sql ===== */



/* ===== BEGIN data-populate.sql ===== */

/* 
=============================================
DAMG6210 - Group Project Part 4
Sample Data Population Script
============================================= 
*/

USE Group_11_Project;
GO

INSERT INTO Event_Category (category_name)
VALUES
    ('Academic Workshop'),
    ('Cultural Festival'),
    ('Sports Competition'),
    ('Career Fair'),
    ('Guest Lecture'),
    ('Social Gathering'),
    ('Community Service'),
    ('Arts Exhibition'),
    ('Music Performance'),
    ('Technology Showcase');
GO

INSERT INTO Venue (name, location, capacity)
VALUES
    ('Blackman Auditorium', 'Ell Hall', 989),
    ('West Village H Auditorium', 'West Village H', 500),
    ('Matthews Arena', '238 St. Botolph Street', 4666),
    ('Curry Student Center Ballroom', '346 Huntington Avenue', 800),
    ('Snell Library Plaza', 'Snell Library', 500),
    ('Richards Hall Room 235', 'Richards Hall', 75),
    ('AfterHours', 'Curry Student Center Lower Level', 300),
    ('Marino Recreation Center Gym', '285 St. Botolph Street', 1200),
    ('Centennial Common', 'Outside Snell Library', 1000),
    ('West Village G Meeting Room', 'West Village G', 100);
GO

INSERT INTO Equipment (name, quantity, status)
VALUES
    ('Projector', 15, 'Available'),
    ('Microphone', 25, 'Available'),
    ('Speaker System', 10, 'Available'),
    ('Laptop', 20, 'Available'),
    ('Stage Lighting', 5, 'Available'),
    ('Folding Chair', 500, 'Available'),
    ('Folding Table', 100, 'Available'),
    ('Banner Stand', 30, 'Available'),
    ('PA System', 8, 'In Use'),
    ('Wireless Mic', 12, 'Available'),
    ('Whiteboard', 15, 'Available'),
    ('Display Monitor', 10, 'Available');
GO

INSERT INTO Student (name, email, major, year)
VALUES
    ('Emma Johnson', 'johnson.em@northeastern.edu', 'Computer Science', 2026),
    ('Liam Chen', 'chen.l@northeastern.edu', 'Business Administration', 2027),
    ('Sophia Rodriguez', 'rodriguez.so@northeastern.edu', 'Mechanical Engineering', 2025),
    ('Noah Kim', 'kim.no@northeastern.edu', 'Data Science', 2028),
    ('Olivia Patel', 'patel.ol@northeastern.edu', 'Psychology', 2027),
    ('Ethan Brown', 'brown.et@northeastern.edu', 'Marketing', 2026),
    ('Ava Martinez', 'martinez.av@northeastern.edu', 'Computer Science', 2025),
    ('Mason Lee', 'lee.ma@northeastern.edu', 'Finance', 2027),
    ('Isabella Davis', 'davis.is@northeastern.edu', 'Biology', 2028),
    ('Lucas Wilson', 'wilson.lu@northeastern.edu', 'Information Systems', 2026),
    ('Mia Anderson', 'anderson.mi@northeastern.edu', 'Communication Studies', 2027),
    ('James Taylor', 'taylor.ja@northeastern.edu', 'Computer Science', 2025),
    ('Charlotte Moore', 'moore.ch@northeastern.edu', 'Economics', 2025),
    ('Benjamin White', 'white.be@northeastern.edu', 'Civil Engineering', 2028),
    ('Amelia Harris', 'harris.am@northeastern.edu', 'Data Science', 2027);
GO

INSERT INTO Organizer (org_type, name)
VALUES
    ('Student Organization', 'NU Hacks'),
    ('Department', 'Career Development'),
    ('Club', 'Northeastern International Student Association'),
    ('Student Organization', 'Khoury Student Council'),
    ('Department', 'Campus Recreation'),
    ('Club', 'Photography Society'),
    ('Student Organization', 'Data Science Club'),
    ('Department', 'Student Activities Office'),
    ('Club', 'Husky Debate Society'),
    ('Student Organization', 'Society of Women Engineers');
GO

INSERT INTO Coordinator (name, email, department, role_title, phone)
VALUES
    ('Sarah Mitchell', 's.mitchell@northeastern.edu', 'Student Life', 'Event Coordinator', '617-373-2001'),
    ('David Park', 'd.park@northeastern.edu', 'Khoury College', 'Program Manager', '617-373-2002'),
    ('Jennifer Lopez', 'j.lopez@northeastern.edu', 'Career Development', 'Career Advisor', '617-373-2003'),
    ('Michael Chang', 'm.chang@northeastern.edu', 'Campus Recreation', 'Sports Coordinator', '617-373-2004'),
    ('Amanda Foster', 'a.foster@northeastern.edu', 'CAMD', 'Events Manager', '617-373-2005'),
    ('Robert Garcia', 'r.garcia@northeastern.edu', 'Student Activities', 'Activities Director', '617-373-2006'),
    ('Lisa Nguyen', 'l.nguyen@northeastern.edu', 'College of Engineering', 'Outreach Coordinator', '617-373-2007'),
    ('Christopher Lee', 'c.lee@northeastern.edu', 'Student Affairs', 'Engagement Specialist', '617-373-2008'),
    ('Rachel Adams', 'r.adams@northeastern.edu', 'D''Amore-McKim', 'Program Coordinator', '617-373-2009'),
    ('Kevin Martinez', 'k.martinez@northeastern.edu', 'Curry Student Center', 'Event Planner', '617-373-2010'),
    ('Michelle Thompson', 'm.thompson@northeastern.edu', 'Student Life', 'Activities Coordinator', '617-373-2011'),
    ('Daniel Rodriguez', 'd.rodriguez@northeastern.edu', 'Facilities', 'Facilities Manager', '617-373-2012');
GO

INSERT INTO Event (title, description, category_id, venue_id, organizer_id, scheduled_start, scheduled_end)
VALUES
    ('Introduction to Machine Learning', 'Learn ML fundamentals with practical applications', 1, 2, 1, '2024-11-25 14:00:00', '2024-11-25 16:00:00'),
    ('Diwali Festival Celebration', 'Celebrate the Festival of Lights with performances and food', 2, 4, 3, '2024-11-30 18:00:00', '2024-11-30 21:00:00'),
    ('Beanpot Viewing Party', 'Watch Northeastern compete in the Beanpot tournament', 3, 7, 5, '2024-11-22 19:00:00', '2024-11-22 21:00:00'),
    ('Spring Co-op & Career Fair', 'Connect with 200+ employers for co-ops and full-time roles', 4, 3, 2, '2025-01-15 10:00:00', '2025-01-15 16:00:00'),
    ('AI Ethics in Practice', 'Industry leaders discuss real-world AI ethics challenges', 5, 1, 1, '2024-11-20 17:00:00', '2024-11-20 19:00:00'),
    ('First Year Welcome Mixer', 'Meet fellow first-year students and make connections', 6, 9, 8, '2024-11-18 16:00:00', '2024-11-18 18:00:00'),
    ('Mission Hill Community Cleanup', 'Volunteer to clean local parks and streets', 7, 9, 8, '2024-12-05 09:00:00', '2024-12-05 13:00:00'),
    ('Student Art Exhibition', 'Showcase of student artwork from all CAMD disciplines', 8, 2, 6, '2024-12-10 14:00:00', '2024-12-10 20:00:00'),
    ('Northeastern Jazz Ensemble Concert', 'Fall semester concert featuring student musicians', 9, 1, 6, '2024-12-01 19:30:00', '2024-12-01 21:30:00'),
    ('HuskieHacks 2024', '24-hour hackathon with industry mentors and prizes', 10, 6, 7, '2024-12-08 09:00:00', '2024-12-09 09:00:00'),
    ('Tableau for Data Science', 'Hands-on workshop: visualize data with Tableau', 1, 6, 4, '2024-11-27 13:00:00', '2024-11-27 15:00:00'),
    ('International Food Festival', 'Taste authentic cuisine from 20+ countries', 2, 9, 3, '2024-12-15 11:00:00', '2024-12-15 15:00:00'),
    ('Intramural Volleyball Finals', 'Championship match: Engineering vs Business', 3, 8, 5, '2024-11-28 17:00:00', '2024-11-28 20:00:00'),
    ('Resume Review Workshop', 'Get 1-on-1 feedback from career advisors', 4, 6, 2, '2024-11-21 15:00:00', '2024-11-21 17:00:00'),
    ('Senior Design Expo', 'Capstone project demonstrations from all engineering disciplines', 10, 2, 10, '2024-12-12 10:00:00', '2024-12-12 17:00:00');
GO

INSERT INTO Event_Coordinator
    (event_id, coordinator_id, role_description)
VALUES
    (1, 2, 'Technical setup and speaker coordination'),
    (1, 1, 'Registration and attendee management'),
    (2, 6, 'Cultural performances coordinator'),
    (2, 1, 'Venue setup and logistics'),
    (2, 11, 'Food vendor coordination'),
    (3, 4, 'Event setup and game coordination'),
    (4, 3, 'Employer relations and booth assignments'),
    (4, 9, 'Student registration and resume collection'),
    (5, 2, 'Panel moderation and Q&A facilitation'),
    (6, 8, 'Student activities and icebreakers'),
    (7, 8, 'Volunteer coordination and site management'),
    (7, 12, 'Supplies and equipment management'),
    (8, 5, 'Gallery curation and artist liaison'),
    (9, 5, 'Sound setup and performance coordination'),
    (10, 2, 'Hackathon judging and technical support'),
    (10, 1, 'Registration and team management'),
    (11, 9, 'Workshop facilitation and materials'),
    (12, 6, 'Food vendor coordination'),
    (12, 11, 'Entertainment and activities'),
    (13, 4, 'Tournament bracket and scheduling'),
    (14, 3, 'Resume review sessions'),
    (15, 7, 'Project evaluations and awards');
GO

INSERT INTO Event_Equipment
    (event_id, equipment_id, quantity_assigned)
VALUES
    (1, 1, 2),
    (1, 4, 5),
    (1, 11, 2),
    (2, 2, 4),
    (2, 3, 2),
    (2, 5, 3),
    (3, 9, 1),
    (4, 7, 50),
    (4, 6, 200),
    (4, 8, 20),
    (5, 1, 1),
    (5, 2, 3),
    (5, 12, 1),
    (6, 3, 2),
    (6, 7, 10),
    (7, 6, 30),
    (7, 7, 5),
    (8, 5, 2),
    (8, 8, 15),
    (9, 3, 1),
    (9, 2, 5),
    (9, 5, 3),
    (10, 4, 20),
    (10, 1, 3),
    (11, 1, 1),
    (11, 4, 10),
    (12, 7, 40),
    (13, 9, 1),
    (14, 1, 1),
    (14, 11, 1),
    (15, 8, 25),
    (15, 12, 5);
GO

INSERT INTO Registration
    (event_id, student_id, external_name, external_email, registration_date, ticket_status, price)
VALUES
    (1, 1, NULL, NULL, '2024-11-18', 'Attended', 0.00),
    (1, 7, NULL, NULL, '2024-11-19', 'Attended', 0.00),
    (1, 12, NULL, NULL, '2024-11-20', 'Attended', 0.00),
    (1, 15, NULL, NULL, '2024-11-21', 'Attended', 0.00),
    (2, 2, NULL, NULL, '2024-11-15', 'Confirmed', 10.00),
    (2, 5, NULL, NULL, '2024-11-16', 'Confirmed', 10.00),
    (2, 10, NULL, NULL, '2024-11-17', 'Confirmed', 10.00),
    (2, NULL, 'John Smith', 'john.smith@gmail.com', '2024-11-18', 'Confirmed', 15.00),
    (2, NULL, 'Maria Garcia', 'maria.g@yahoo.com', '2024-11-19', 'Confirmed', 15.00),
    (3, 3, NULL, NULL, '2024-11-20', 'Attended', 5.00),
    (3, 8, NULL, NULL, '2024-11-21', 'Attended', 5.00),
    (3, 13, NULL, NULL, '2024-11-21', 'Attended', 5.00),
    (3, 14, NULL, NULL, '2024-11-21', 'Attended', 5.00),
    (4, 1, NULL, NULL, '2024-11-22', 'Confirmed', 0.00),
    (4, 6, NULL, NULL, '2024-11-22', 'Confirmed', 0.00),
    (4, 11, NULL, NULL, '2024-11-23', 'Confirmed', 0.00),
    (5, 7, NULL, NULL, '2024-11-18', 'Attended', 0.00),
    (5, 12, NULL, NULL, '2024-11-19', 'Attended', 0.00),
    (5, 1, NULL, NULL, '2024-11-19', 'Attended', 0.00),
    (6, 4, NULL, NULL, '2024-11-16', 'Attended', 0.00),
    (6, 9, NULL, NULL, '2024-11-17', 'Attended', 0.00),
    (6, 14, NULL, NULL, '2024-11-17', 'Attended', 0.00),
    (7, 2, NULL, NULL, '2024-11-28', 'Confirmed', 0.00),
    (7, 10, NULL, NULL, '2024-11-29', 'Confirmed', 0.00),
    (8, 5, NULL, NULL, '2024-12-01', 'Confirmed', 5.00),
    (8, NULL, 'Sarah Williams', 'sarah.w@yahoo.com', '2024-12-02', 'Confirmed', 8.00),
    (9, 11, NULL, NULL, '2024-11-25', 'Confirmed', 12.00),
    (9, 3, NULL, NULL, '2024-11-26', 'Confirmed', 12.00),
    (9, NULL, 'David Brown', 'david.b@hotmail.com', '2024-11-26', 'Confirmed', 15.00),
    (10, 1, NULL, NULL, '2024-12-01', 'Confirmed', 0.00),
    (10, 7, NULL, NULL, '2024-12-02', 'Confirmed', 0.00),
    (10, 12, NULL, NULL, '2024-12-03', 'Confirmed', 0.00),
    (10, 15, NULL, NULL, '2024-12-03', 'Confirmed', 0.00),
    (11, 15, NULL, NULL, '2024-11-22', 'Confirmed', 0.00),
    (12, 2, NULL, NULL, '2024-12-05', 'Confirmed', 8.00),
    (12, 6, NULL, NULL, '2024-12-06', 'Confirmed', 8.00);
GO

INSERT INTO Event_Volunteer
    (event_id, student_id, hours_worked, role)
VALUES
    (2, 3, 4.0, 'Setup crew'),
    (2, 8, 4.0, 'Registration desk'),
    (2, 13, 3.5, 'Cleanup crew'),
    (3, 2, 2.0, 'Scoreboard operator'),
    (5, 4, 1.5, 'A/V technician'),
    (6, 5, 2.0, 'Welcome team'),
    (6, 14, 2.0, 'Activities facilitator'),
    (1, 10, 2.5, 'Lab assistant'),
    (14, 9, 1.5, 'Registration support'),
    (4, 2, NULL, 'Booth assistant'),
    (4, 10, NULL, 'Registration and check-in'),
    (7, 1, NULL, 'Team leader'),
    (7, 6, NULL, 'Supplies coordinator'),
    (7, 11, NULL, 'Cleanup volunteer'),
    (8, 4, NULL, 'Gallery attendant'),
    (9, 9, NULL, 'Usher'),
    (10, 15, NULL, 'Mentor and judge'),
    (12, 12, NULL, 'Food service volunteer'),
    (15, 7, NULL, 'Project setup');
GO

INSERT INTO Feedback
    (event_id, student_id, rating, comment)
VALUES
    (1, 1, 5, 'Great introduction to ML concepts. Very informative!'),
    (1, 7, 4, 'Useful workshop, would like more hands-on time.'),
    (1, 12, 5, 'Excellent instructor and materials.'),
    (1, 15, 4, 'Good content but moved a bit fast.'),
    (2, 2, 5, 'Amazing cultural performances! Loved the diversity.'),
    (2, 5, 4, 'Great event, but wish there was more seating.'),
    (2, 10, 5, 'Best event of the semester, highly recommend!'),
    (3, 3, 5, 'Exciting game, well organized.'),
    (3, 8, 4, 'Good competition, venue was packed!'),
    (3, 13, 5, 'Loved the energy and school spirit.'),
    (3, 14, 4, 'Great atmosphere, would attend again.'),
    (5, 7, 4, 'Very insightful panel, learned a lot about AI ethics.'),
    (5, 12, 5, 'Excellent speakers, wish it was longer.'),
    (5, 1, 5, 'Thought-provoking discussion on important topics.'),
    (6, 4, 3, 'Nice mixer but a bit crowded.'),
    (6, 9, 4, 'Good way to meet new people.'),
    (6, 14, 5, 'Fun activities and welcoming atmosphere.'),
    (14, 9, 5, 'Extremely helpful feedback on my resume!');
GO

INSERT INTO Survey_Response
    (event_id, student_id, answers)
VALUES
    (1, 1, '{"q1":"Excellent","q2":"Yes","q3":"More workshops","q4":"Clear explanations"}'),
    (1, 7, '{"q1":"Good","q2":"Yes","q3":"More practice time","q4":"Topic selection"}'),
    (1, 12, '{"q1":"Excellent","q2":"Definitely","q3":"Advanced workshop next","q4":"Instructor quality"}'),
    (1, 15, '{"q1":"Very Good","q2":"Yes","q3":"Slower pace","q4":"Content depth"}'),
    (2, 2, '{"q1":"Excellent","q2":"Yes","q3":"More cultural events","q4":"Food and performances"}'),
    (2, 5, '{"q1":"Good","q2":"Yes","q3":"Better seating","q4":"Variety of cultures"}'),
    (2, 10, '{"q1":"Excellent","q2":"Definitely","q3":"Keep same format","q4":"Everything!"}'),
    (3, 3, '{"q1":"Excellent","q2":"Yes","q3":"More tournaments","q4":"Competitive atmosphere"}'),
    (3, 8, '{"q1":"Good","q2":"Yes","q3":"Better scheduling","q4":"School spirit"}'),
    (5, 7, '{"q1":"Very Good","q2":"Yes","q3":"More panel discussions","q4":"Speaker expertise"}'),
    (5, 12, '{"q1":"Excellent","q2":"Definitely","q3":"Longer sessions","q4":"Topics covered"}'),
    (6, 4, '{"q1":"Good","q2":"Maybe","q3":"Smaller groups","q4":"Meeting new people"}'),
    (6, 9, '{"q1":"Very Good","q2":"Yes","q3":"More activities","q4":"Icebreaker games"}'),
    (6, 14, '{"q1":"Excellent","q2":"Yes","q3":"More frequent mixers","q4":"Welcoming environment"}'),
    (14, 9, '{"q1":"Excellent","q2":"Definitely","q3":"More career workshops","q4":"Personalized feedback"}');
GO

/* ===== END data-populate.sql ===== */



/* ===== BEGIN FirstView.sql ===== */

use Group_11_Project;

DROP VIEW IF EXISTS event_ranking;
GO
CREATE VIEW event_ranking AS

SELECT 
	e.Event_id,
	e.title AS EventName,
	o.organizer_id, 
	o.name AS OrganizerName,
	AVG(f.rating) AS AverageRating,
	COUNT(f.feedback_id) AS TotalFeedbacks,
	RANK() OVER (ORDER BY AVG(f.rating) DESC) AS RateRank
FROM Event e
JOIN Feedback f
	ON e.event_id = f.event_id
JOIN Organizer o
	ON e.organizer_id = o.organizer_id
GROUP BY 
	e.event_id,
	e.title,
	o.organizer_id,
	o.name;
GO

/* ===== END FirstView.sql ===== */



/* ===== BEGIN SecondView.sql ===== */

USE Group_11_Project;
DROP VIEW IF EXISTS student_profile;
GO


CREATE VIEW student_profile AS
SELECT
    s.student_id,
    s.name AS student_name,
    s.email AS student_email,
    s.major,
    s.year,

    r.registration_id,
    r.registration_date,
    r.ticket_status,
    r.price,

    e.event_id,
    e.title AS event_title,
    e.category_id,
    e.organizer_id,
    e.scheduled_start,
    e.scheduled_end,
    e.duration_minutes,

    f.feedback_id,
    f.rating AS feedback_rating,
    f.comment AS feedback_comment
FROM Student s
LEFT JOIN Registration r 
    ON s.student_id = r.student_id
LEFT JOIN Event e
    ON r.event_id = e.event_id
LEFT JOIN Feedback f
    ON s.student_id = f.student_id 
    AND e.event_id = f.event_id;


/* ===== END SecondView.sql ===== */

