-- This file is to bootstrap a database for the CS3200 project.

-- Create a new database.  You can change the name later.  You'll
-- need this name in the FLASK API file(s),  the AppSmith
-- data source creation.
drop database math_learning_db;
CREATE DATABASE IF NOT EXISTS math_learning_db;

-- Via the Docker Compose file, a special user called webapp will
-- be created in MySQL. We are going to grant that user
-- all privilages to the new database we just created.
-- TODO: If you changed the name of the database above, you need
-- to change it here too.
grant all privileges on math_learning_db.* to 'webapp'@'%';
flush privileges;

-- Move into the database we just created.
-- TODO: If you changed the name of the database above, you need to
-- change it here too.
USE math_learning_db;


CREATE TABLE IF NOT EXISTS siteAdmin
(
   adminid INT PRIMARY KEY AUTO_INCREMENT,
   firstName VARCHAR(50),
   lastName VARCHAR(50),
   email VARCHAR(50) UNIQUE NOT NULL,
   phoneNumber VARCHAR(50) not null
);


CREATE TABLE IF NOT EXISTS teacher (
   teacherId INT PRIMARY KEY AUTO_INCREMENT,
   firstName VARCHAR(50) NOT NULL,
   lastName VARCHAR(50) NOT NULL,
   email VARCHAR(50) NOT NULL,
   phoneNumber VARCHAR(50) NOT NULL
);


CREATE TABLE IF NOT EXISTS classroom (
   classId INT PRIMARY KEY AUTO_INCREMENT,
   teacherId INT NOT NULL,
   adminEmail VARCHAR(50) NOT NULL,
   FOREIGN KEY (teacherId) REFERENCES teacher(teacherId) ON UPDATE CASCADE ON DELETE CASCADE,
   FOREIGN KEY (adminEmail) REFERENCES siteAdmin(email) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS students (
   email VARCHAR(100) NOT NULL,
   firstName VARCHAR(50) NOT NULL,
   PRIMARY KEY (email, firstName),
   lastName VARCHAR(50) NOT NULL,
   classroomId INT NOT NULL,
   FOREIGN KEY (classroomId) REFERENCES classroom(classId) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS parent (
   email VARCHAR(100) PRIMARY KEY,
   firstName VARCHAR(50) NOT NULL,
   lastName VARCHAR(50) NOT NULL,
   studentEmail varchar(50),
   FOREIGN KEY (studentEmail) REFERENCES students(Email) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS questions (
   questionId INT PRIMARY KEY AUTO_INCREMENT,
   subject VARCHAR(50) NOT NULL,
   answer VARCHAR(50) NOT NULL,
   question_text VARCHAR(255) UNIQUE NOT NULL
);


CREATE TABLE IF NOT EXISTS leaderboard (
   email VARCHAR(100) PRIMARY KEY,
   firstName VARCHAR(50) NOT NULL,
   numberOfCorrect INT DEFAULT 0,
   FOREIGN KEY (email) REFERENCES students(email) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS assignedQuestions (
   assignedQuestionId INT AUTO_INCREMENT,
   questionId INT NOT NULL,
   answer VARCHAR(50) NOT NULL,
   classId INT,
   question_text VARCHAR(255) NOT NULL,
   PRIMARY KEY (assignedQuestionId, classId),
   FOREIGN KEY (questionId) REFERENCES questions(questionId) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS activity (
   activityId INT PRIMARY KEY AUTO_INCREMENT,
   email VARCHAR(100) NOT NULL,
   dateCompleted DATETIME DEFAULT CURRENT_TIMESTAMP(),
   submittedAnswer VARCHAR(50) NOT NULL,
   correctness BOOLEAN DEFAULT FALSE,
   assignedQuestionId INT,
   FOREIGN KEY (email) REFERENCES students(email) ON UPDATE CASCADE ON DELETE CASCADE,
   FOREIGN KEY (assignedQuestionId) REFERENCES assignedQuestions(assignedQuestionId) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS studentsProgress (
   studentEmail VARCHAR(100),
   subject VARCHAR(100),
   PRIMARY KEY (studentEmail, subject),
   parentEmail  VARCHAR(100) NOT NULL,
   totalCorrect INT DEFAULT 0,
   totalAttempts INT DEFAULT 0,
   firstName VARCHAR(50) NOT NULL,
   firstDate DATE NOT NULL,
   lastDate DATE NOT NULL,
   FOREIGN KEY (studentEmail, firstName) REFERENCES students(email, firstName) ON UPDATE CASCADE ON DELETE CASCADE,
   FOREIGN KEY (parentEmail) REFERENCES parent(email) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS classroomProgress (
   assignedQuestionId INT,
   email VARCHAR(50) NOT NULL,
   PRIMARY KEY (assignedQuestionId, email),
   firstName VARCHAR(50),
   totalAttempts INT NOT NULl DEFAULT 0,
   correctness BOOLEAN DEFAULT FALSE,
   firstDate DATE,
   lastDate DATE,
   classId INT NOT NULL,
   FOREIGN KEY (email, firstName) REFERENCES students(email, firstName) ON UPDATE CASCADE ON DELETE CASCADE,
   FOREIGN KEY (assignedQuestionId, classId) REFERENCES assignedQuestions(assignedQuestionId, classId) ON UPDATE CASCADE ON DELETE CASCADE
);

DELIMITER $$
CREATE TRIGGER addCorrectAnswers
AFTER INSERT ON activity
FOR EACH ROW
BEGIN
    IF NEW.correctness = TRUE THEN
        UPDATE leaderboard
        SET numberOfCorrect = numberOfCorrect + 1
        WHERE email = NEW.email;

        UPDATE studentsProgress
        SET totalCorrect = totalCorrect + 1
        WHERE studentEmail = NEW.email
        AND subject = (SELECT q.subject
                     FROM questions q
                     JOIN assignedQuestions aq ON q.questionId = aq.questionId
                     WHERE aq.assignedQuestionId = NEW.assignedQuestionId);

    UPDATE classroomProgress
    SET correctness = 1
    WHERE email = NEW.email AND assignedQuestionId = NEW.assignedQuestionId;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER addAttempt
AFTER INSERT ON activity
FOR EACH ROW
BEGIN
    -- Update studentsProgress totalAttempts
    UPDATE studentsProgress
    SET totalAttempts = totalAttempts + 1
    WHERE studentEmail = NEW.email
      AND subject = (SELECT q.subject
                     FROM questions q
                     JOIN assignedQuestions aq ON q.questionId = aq.questionId
                     WHERE aq.assignedQuestionId = NEW.assignedQuestionId);

   -- Update studentsProgress lastDate
    UPDATE studentsProgress
    SET lastDate = NEW.dateCompleted
    WHERE studentEmail = NEW.email
      AND subject = (SELECT q.subject
                     FROM questions q
                     JOIN assignedQuestions aq ON q.questionId = aq.questionId
                     WHERE aq.assignedQuestionId = NEW.assignedQuestionId);

    -- studentsProgress: Determine if firstDate is null and update if needed
    IF (SELECT s.firstDate
                      FROM studentsProgress s
                      WHERE s.studentEmail = NEW.email
                        AND s.subject = (SELECT q.subject
                                         FROM questions q
                                         JOIN assignedQuestions aq ON q.questionId = aq.questionId
                                         WHERE aq.assignedQuestionId = NEW.assignedQuestionId)) IS NULL THEN
        UPDATE studentsProgress s
        SET s.firstDate = NEW.dateCompleted
        WHERE s.studentEmail = NEW.email
      AND subject = (SELECT q.subject
                     FROM questions q
                     JOIN assignedQuestions aq ON q.questionId = aq.questionId
                     WHERE aq.assignedQuestionId = NEW.assignedQuestionId);
    END IF;

    -- Update classroomProgress totalAttempts
    UPDATE classroomProgress
    SET totalAttempts = totalAttempts + 1
    WHERE email = NEW.email AND assignedQuestionId = NEW.assignedQuestionId;

    -- Update classroomProgress lastDate
    UPDATE classroomProgress
    SET lastDate = NEW.dateCompleted
    WHERE email = NEW.email AND assignedQuestionId = NEW.assignedQuestionId;

    -- classroomProgress: Determine if firstDate is null and update if needed
    IF (SELECT c.firstDate
                      FROM classroomProgress c
                      WHERE c.email = NEW.email AND c.assignedQuestionId = NEW.assignedQuestionId) IS NULL THEN
        UPDATE classroomProgress c
        SET c.firstDate = NEW.dateCompleted
        WHERE c.email = NEW.email AND c.assignedQuestionId = NEW.assignedQuestionId;
    END IF;
END$$
DELIMITER ;

CREATE TRIGGER addStudent_leaderboard
AFTER INSERT ON students
FOR EACH ROW
BEGIN
    -- Insert a new row into the leaderboard table
    INSERT INTO leaderboard (email, firstName, numberOfCorrect)
    VALUES (NEW.email, NEW.firstName, 0);
END;

-- on insert of assigned questions, creates a clasroomprogress for students with same classid
CREATE TRIGGER addClassroom_Progress
AFTER INSERT ON assignedQuestions
FOR EACH ROW
BEGIN
    INSERT INTO classroomProgress (assignedQuestionId, email, firstName, classId)
    SELECT NEW.assignedQuestionId, s.email, s.firstName, NEW.classId
    FROM students s
    WHERE s.classroomId = NEW.classId;
END;



-- Insert statement for siteAdmin table
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber)
VALUES ('John', 'Doe', 'johndoe@example.com', '123-456-7890');

INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber)
VALUES ('Jane', 'Smith', 'janesmith@example.com', '987-654-3210');

INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber)
VALUES ('Alice', 'Johnson', 'alicejohnson@example.com', '555-123-4567');


-- Insert statement for teacher table
INSERT INTO teacher (firstName, lastName, email, phoneNumber)
VALUES ('Mark', 'Anderson', 'mark.anderson@example.com', '111-222-3333');

INSERT INTO teacher (firstName, lastName, email, phoneNumber)
VALUES ('Emily', 'Brown', 'emily.brown@example.com', '444-555-6666');

INSERT INTO teacher (firstName, lastName, email, phoneNumber)
VALUES ('James', 'Wilson', 'james.wilson@example.com', '777-888-9999');


-- Insert statement for classroom table
INSERT INTO classroom (teacherId, adminEmail)
VALUES (1, 'johndoe@example.com');

INSERT INTO classroom (teacherId, adminEmail)
VALUES (2, 'janesmith@example.com');

INSERT INTO classroom (teacherId, adminEmail)
VALUES (3, 'alicejohnson@example.com');


-- Insert statement for students table
INSERT INTO students (email, firstName, lastName, classroomId)
VALUES ('student1@example.com', 'Michael', 'Williams', 1);

INSERT INTO students (email, firstName, lastName, classroomId)
VALUES ('student2@example.com', 'Sophia', 'Taylor', 2);

INSERT INTO students (email, firstName, lastName, classroomId)
VALUES ('student3@example.com', 'Ethan', 'Martinez', 3);


-- Insert statement for parent table
INSERT INTO parent (email, firstName, lastName, studentEmail)
VALUES ('parent1@example.com', 'Laura', 'Williams', 'student1@example.com');

INSERT INTO parent (email, firstName, lastName, studentEmail)
VALUES ('parent2@example.com', 'David', 'Taylor', 'student2@example.com');

INSERT INTO parent (email, firstName, lastName, studentEmail)
VALUES ('parent3@example.com', 'Sophie', 'Martinez', 'student3@example.com');


-- Insert statement for questions table
INSERT INTO questions (subject, answer, question_text)
VALUES ('Math', '42', '6x7');

INSERT INTO questions (subject, answer, question_text)
VALUES ('Science', 'Newton', 'Who discovered the law of gravity?');

INSERT INTO questions (subject, answer, question_text)
VALUES ('History', 'Washington', 'Who was the first President of the United States?');


-- Insert statement for assignedQuestions table
INSERT INTO assignedQuestions (questionId, question_text, answer, classId)
VALUES (1, '6x7','42', 1);

INSERT INTO assignedQuestions (questionId, question_text, answer, classId)
VALUES (2, 'Who discovered the law of gravity?','Newton', 2);

INSERT INTO assignedQuestions (questionId, question_text, answer, classId)
VALUES (3, 'Who was the first President of the United States?','Washington', 3);


-- Insert statement for activity table
INSERT INTO activity (email, submittedAnswer, assignedQuestionId)
VALUES ('student1@example.com', '42', 1);

INSERT INTO activity (email, submittedAnswer, assignedQuestionId)
VALUES ('student2@example.com', 'Newton', 2);

INSERT INTO activity (email, submittedAnswer, assignedQuestionId)
VALUES ('student3@example.com', 'Adams', 3);

-- Insert statement for all the data

USE math_learning_db;

INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Kayla', 'Anderson', 'margaretmitchell@example.com', '450.604.0335x961');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Sara', 'Chan', 'monica96@example.net', '479-931-3655x2558');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Kayla', 'Chandler', 'juan07@example.org', '+1-591-304-5691x79989');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Darlene', 'Martin', 'claudia78@example.net', '(514)431-0981x60890');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Ashley', 'Montoya', 'ygriffith@example.com', '(835)950-2715x671');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Shelby', 'Roth', 'dthompson@example.com', '001-859-863-5109x26744');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Eric', 'Barnett', 'hramirez@example.org', '639-864-6898x4804');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Todd', 'Brown', 'james69@example.org', '546.316.0043x02102');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('David', 'Singleton', 'tonywall@example.com', '220.977.3819');
INSERT INTO siteAdmin (firstName, lastName, email, phoneNumber) VALUES ('Ricky', 'Jimenez', 'alopez@example.net', '247.725.9869x7753');


INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Jonathan', 'Young', 'reginald57@example.org', '311-506-8827x24826');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Patrick', 'Campbell', 'amanda08@example.com', '+1-332-374-3733');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Lisa', 'Sims', 'iwatson@example.net', '001-451-512-3907x06972');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Wendy', 'Taylor', 'moonwilliam@example.org', '+1-328-463-0883x1419');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Joseph', 'Ball', 'morganarmstrong@example.com', '565.797.0123x65303');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Marilyn', 'Wilson', 'ypeterson@example.org', '(387)637-5725');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Hector', 'Garrett', 'stonejeremy@example.org', '660-745-7185x434');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Douglas', 'Martinez', 'zreid@example.net', '522.566.4857x297');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Jeffrey', 'Wright', 'ashley50@example.org', '377-940-4196');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Sandra', 'Andrews', 'arthur54@example.org', '(388)912-0714x3431');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Melissa', 'Cohen', 'mcmillanleslie@example.org', '001-856-350-3981');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Gavin', 'Guzman', 'brandon12@example.com', '+1-868-887-4199');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Maria', 'Armstrong', 'blanchardzachary@example.net', '+1-534-214-7694');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Zachary', 'Gutierrez', 'matthewhines@example.com', '419-820-6708');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Janet', 'Brown', 'kellyshelton@example.org', '(507)602-1740');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Timothy', 'Walters', 'caitlin93@example.net', '(735)998-7103');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Pamela', 'Miller', 'dhogan@example.net', '375-299-4412');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Steve', 'Newman', 'rwilliams@example.org', '6447184706');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Brandon', 'Bell', 'xgeorge@example.net', '929.547.1947x16947');
INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES ('Misty', 'Cooke', 'kathleen50@example.org', '+1-605-695-3535x691');


INSERT INTO classroom (teacherId, adminEmail) VALUES (1, 'juan07@example.org');
INSERT INTO classroom (teacherId, adminEmail) VALUES (2, 'dthompson@example.com');
INSERT INTO classroom (teacherId, adminEmail) VALUES (3, 'juan07@example.org');
INSERT INTO classroom (teacherId, adminEmail) VALUES (4, 'monica96@example.net');
INSERT INTO classroom (teacherId, adminEmail) VALUES (5, 'margaretmitchell@example.com');
INSERT INTO classroom (teacherId, adminEmail) VALUES (6, 'dthompson@example.com');
INSERT INTO classroom (teacherId, adminEmail) VALUES (7, 'margaretmitchell@example.com');
INSERT INTO classroom (teacherId, adminEmail) VALUES (8, 'margaretmitchell@example.com');
INSERT INTO classroom (teacherId, adminEmail) VALUES (9, 'hramirez@example.org');
INSERT INTO classroom (teacherId, adminEmail) VALUES (10, 'hramirez@example.org');
INSERT INTO classroom (teacherId, adminEmail) VALUES (11, 'monica96@example.net');
INSERT INTO classroom (teacherId, adminEmail) VALUES (12, 'monica96@example.net');
INSERT INTO classroom (teacherId, adminEmail) VALUES (13, 'ygriffith@example.com');
INSERT INTO classroom (teacherId, adminEmail) VALUES (14, 'monica96@example.net');
INSERT INTO classroom (teacherId, adminEmail) VALUES (15, 'claudia78@example.net');
INSERT INTO classroom (teacherId, adminEmail) VALUES (16, 'ygriffith@example.com');
INSERT INTO classroom (teacherId, adminEmail) VALUES (17, 'dthompson@example.com');
INSERT INTO classroom (teacherId, adminEmail) VALUES (18, 'james69@example.org');
INSERT INTO classroom (teacherId, adminEmail) VALUES (19, 'alopez@example.net');
INSERT INTO classroom (teacherId, adminEmail) VALUES (20, 'james69@example.org');

/* Generate fake data for questions table */
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '2', 'What is 1 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '4', 'What is 2 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '6', 'What is 3 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '8', 'What is 4 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '10', 'What is 5 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '12', 'What is 6 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '14', 'What is 7 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '16', 'What is 8 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '18', 'What is 9 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '20', 'What is 10 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Science', 'Newton', 'Who discovered gravity?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '26', 'What is the square root of 676?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '28', 'What is 14 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Science', 'O', 'What is the chemical symbol for oxygen?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '32', 'What is 16 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Science', '299792458', 'What is the speed of light in m/s?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Science', '6', 'What is the atomic number of carbon?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '38', 'What is 19 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '40', 'What is 20 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '44', 'What is 22 plus 22?');
INSERT INTO questions (subject, answer, question_text) VALUES ('History', '1945', 'What year did World War II end?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '48', 'What is 24 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('History', '1776', 'What year was the Declaration of Independence signed?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '52', 'What is 26 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('History', 'Paris', 'What is the capital of France?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '56', 'What is 28 times 2?');
INSERT INTO questions (subject, answer, question_text) VALUES ('History', 'Harper Lee', 'Who wrote "To Kill a Mockingbird"?');
INSERT INTO questions (subject, answer, question_text) VALUES ('Math', '60', 'What is 30 times 2?');

INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('brookemcmahon@example.org', 'Heidi', 'Weaver', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('russellcory@example.com', 'Bradley', 'Campbell', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('cannonkristen@example.net', 'Michael', 'Webb', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jasonmitchell@example.com', 'Brian', 'Simpson', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jenkinsthomas@example.com', 'Jason', 'Mitchell', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('thompsonerin@example.net', 'Rebecca', 'Smith', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('zzhang@example.org', 'Jason', 'Martin', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('alanrivera@example.net', 'Jessica', 'Jensen', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('gscott@example.com', 'Austin', 'Torres', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('prestonmolly@example.com', 'Robert', 'Pena', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('williambeasley@example.com', 'Carol', 'Lopez', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('daniellegeorge@example.org', 'Joshua', 'Hall', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('toddvernon@example.net', 'Sylvia', 'Murphy', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('wbrooks@example.net', 'Destiny', 'Travis', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('johnathan44@example.com', 'Kyle', 'Castro', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('gvillarreal@example.net', 'Michael', 'Davis', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('richardfox@example.com', 'Jasmine', 'Ellison', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jonespamela@example.com', 'Gregory', 'Mason', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('swilson@example.org', 'Andrew', 'Swanson', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('pwright@example.com', 'Gabrielle', 'Alvarez', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('juliasullivan@example.net', 'Dawn', 'Baldwin', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('thomas29@example.net', 'Alexandra', 'Lewis', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('williamsalexis@example.net', 'Nicholas', 'Newman', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('reynoldsmark@example.com', 'Vincent', 'Moody', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('pmaxwell@example.net', 'Diana', 'Weber', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('krobinson@example.net', 'Nicole', 'Taylor', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('hfranklin@example.net', 'Jason', 'Daniels', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('sarawilliams@example.net', 'Miguel', 'Evans', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('matthew24@example.net', 'Jacob', 'Evans', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jennifer23@example.org', 'Nancy', 'Gordon', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('dortiz@example.net', 'Jeffery', 'Elliott', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('adrienne09@example.net', 'Edward', 'Ballard', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('kimberly67@example.com', 'Jessica', 'Brown', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('julia70@example.com', 'Tammy', 'Miller', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('fwhite@example.org', 'Harold', 'Ray', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('zimmermancarla@example.com', 'Jonathan', 'Martinez', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('gregoryfisher@example.com', 'Holly', 'Williams', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('ellistimothy@example.org', 'Sandra', 'Collins', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michaelmccarthy@example.net', 'Stephanie', 'Washington', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('andrewhester@example.org', 'Sarah', 'Mitchell', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('sjohnson@example.net', 'Daniel', 'Young', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('crystal81@example.org', 'Veronica', 'Crawford', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('deannajones@example.net', 'Tammy', 'Harris', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('monroekimberly@example.net', 'Philip', 'Smith', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('havila@example.com', 'Stephanie', 'Bailey', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('hhernandez@example.com', 'Joseph', 'Erickson', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('fischerbrittany@example.net', 'Linda', 'Wilson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('troywatkins@example.com', 'Kristin', 'Chavez', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('dward@example.com', 'Darin', 'Buckley', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('woodrichard@example.com', 'Eric', 'May', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('mcintyrejesus@example.com', 'Nicole', 'Campbell', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('logan20@example.org', 'Hailey', 'Lyons', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('bross@example.net', 'Hannah', 'Williams', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('edwardjohnson@example.net', 'Andrew', 'Murray', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('mwalters@example.net', 'Miguel', 'Peterson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('iramirez@example.org', 'Brady', 'Evans', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('stacyburgess@example.org', 'Erin', 'Peterson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('feliciagraham@example.org', 'Vincent', 'Sandoval', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('lbradshaw@example.com', 'Kenneth', 'Green', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('sgardner@example.com', 'Wanda', 'Watson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jfinley@example.com', 'Amy', 'Brown', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('antonio94@example.net', 'Kimberly', 'Jones', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('crystalbrown@example.net', 'Patrick', 'Garcia', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('cynthia79@example.org', 'Jonathan', 'Rosales', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('susanelliott@example.com', 'Frank', 'Miller', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('bjohnson@example.net', 'Larry', 'Clark', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('rpark@example.net', 'Cheryl', 'Ingram', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('wsalas@example.org', 'Amber', 'Keller', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jeffreyward@example.org', 'Autumn', 'Brewer', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('cynthia35@example.net', 'Jeremy', 'Young', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('tracy21@example.org', 'John', 'Harrison', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('blackkatherine@example.com', 'Christina', 'Watts', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('uhorn@example.com', 'Timothy', 'Brown', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('charlesvalentine@example.org', 'Gregory', 'Bishop', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('markavery@example.net', 'Gregory', 'Gray', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jasongonzalez@example.com', 'Lindsay', 'Li', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('hunterrobin@example.org', 'Jamie', 'Lee', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('xmcknight@example.org', 'Raymond', 'Ramirez', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('christy59@example.com', 'Amanda', 'Wood', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('brockjasmine@example.com', 'Jacob', 'Wilson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('olong@example.net', 'Michael', 'Zimmerman', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('bryanlittle@example.org', 'Thomas', 'Freeman', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('dawnmurphy@example.org', 'Hannah', 'Wilkinson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('snyderisaiah@example.com', 'Kathleen', 'Jones', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('wardjuan@example.com', 'Pamela', 'Young', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jameswheeler@example.com', 'Katherine', 'Hunt', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('lserrano@example.com', 'Robert', 'Sanders', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('tmassey@example.net', 'Danielle', 'Pearson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('cscott@example.com', 'Rebecca', 'Rivera', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('fieldsadrienne@example.com', 'Denise', 'Terry', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('wrightcorey@example.com', 'Laura', 'Mcdonald', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('oallen@example.com', 'Eric', 'Diaz', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('arnoldgabrielle@example.net', 'Robert', 'King', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('melissa43@example.org', 'Victoria', 'Shepard', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('campbellanthony@example.org', 'Jeffery', 'Le', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('vparker@example.com', 'Adrian', 'Thornton', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('danny96@example.org', 'Daniel', 'Glover', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('fcook@example.com', 'Helen', 'Nguyen', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('lauren92@example.org', 'Misty', 'Price', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michael68@example.net', 'Aaron', 'Bishop', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('melissa94@example.net', 'John', 'Turner', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('svega@example.com', 'Amy', 'Atkinson', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('thomascasey@example.org', 'Julie', 'Drake', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('carriewallace@example.com', 'Joshua', 'Johnson', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('paulconner@example.com', 'Miranda', 'Abbott', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('johnhughes@example.org', 'Glen', 'Moyer', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('margaretbenjamin@example.com', 'Jennifer', 'Lee', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('geraldobrien@example.com', 'Dale', 'Taylor', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('mathewsandrew@example.org', 'Jason', 'Watkins', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('ymyers@example.com', 'Katie', 'Elliott', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('marthacarter@example.org', 'Brooke', 'Hickman', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('carlareeves@example.net', 'Douglas', 'Grant', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('yanderson@example.net', 'Mercedes', 'Cardenas', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('xtaylor@example.com', 'Joseph', 'Jensen', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('spearsjohn@example.com', 'Cynthia', 'George', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('danielrobinson@example.org', 'Mark', 'Barnett', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('davidfowler@example.org', 'Andrew', 'Obrien', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('fisherchristina@example.com', 'Jennifer', 'Rich', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('kyoung@example.com', 'William', 'Hernandez', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('david49@example.com', 'Cole', 'Tyler', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('tyrone33@example.com', 'Johnny', 'Freeman', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michael12@example.net', 'Beverly', 'Gamble', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('christian29@example.net', 'Michelle', 'Frazier', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('zsullivan@example.org', 'Brandon', 'Walton', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('samuelmcintosh@example.com', 'Kristin', 'Miller', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('carriebuck@example.org', 'Ronald', 'Hood', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('gavin81@example.com', 'Vanessa', 'Choi', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('hayley42@example.org', 'Kimberly', 'Poole', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('nbullock@example.org', 'Laura', 'Cantu', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('patrick90@example.org', 'Tammy', 'Roberts', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('nedwards@example.org', 'Tiffany', 'Johnson', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('leonsmith@example.com', 'Alyssa', 'Gonzalez', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jrosario@example.org', 'Adam', 'Caldwell', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('alan52@example.org', 'Marissa', 'Dodson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('williamsshelby@example.net', 'Melvin', 'Evans', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('williamsbrian@example.org', 'Charles', 'Swanson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('robert65@example.net', 'Rachel', 'Saunders', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('ihuber@example.org', 'Brian', 'Barrera', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('nshelton@example.org', 'Ernest', 'Hunter', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('matthewedwards@example.com', 'Lisa', 'Williams', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jennifer48@example.net', 'Morgan', 'Tapia', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('john14@example.com', 'Deborah', 'Nelson', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('qwiggins@example.org', 'Lindsay', 'Jones', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('porterbrittany@example.com', 'Amy', 'Deleon', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('zcardenas@example.net', 'Samantha', 'Mccarty', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('lisaharvey@example.com', 'Jamie', 'Spencer', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jhahn@example.org', 'Joseph', 'Neal', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('angelareid@example.org', 'Anna', 'Cooke', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jmccarthy@example.com', 'David', 'Woods', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('kennethrobertson@example.org', 'David', 'Camacho', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('matthew62@example.com', 'Richard', 'Martinez', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('aaron88@example.org', 'Tammy', 'Arellano', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('dodonnell@example.org', 'Jennifer', 'White', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michael77@example.net', 'Mary', 'Gould', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('charlescaleb@example.com', 'Tammy', 'Edwards', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('cohentaylor@example.net', 'Stephen', 'Duncan', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('richardkelli@example.net', 'Maria', 'Russell', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('rbeasley@example.net', 'Paula', 'Porter', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('stephaniemclaughlin@example.org', 'Michael', 'Graham', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('benjamincarr@example.net', 'Joshua', 'Massey', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michael56@example.net', 'Jason', 'Stevenson', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('nicholasmckenzie@example.com', 'Jennifer', 'Romero', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('gmartinez@example.net', 'Tara', 'Williams', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('fernandezsara@example.org', 'John', 'Brown', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('pcardenas@example.net', 'Edward', 'Yates', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michelleking@example.com', 'Nicholas', 'Richardson', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('halecody@example.com', 'Ronald', 'Miller', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michelledalton@example.com', 'Hannah', 'Carpenter', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('amber44@example.org', 'Adam', 'Carter', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('alex11@example.net', 'David', 'Strickland', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jacob73@example.org', 'Kelly', 'Jones', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('xblankenship@example.org', 'Christopher', 'Blankenship', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('wendy06@example.com', 'Ashley', 'Curtis', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('rodriguezjesse@example.net', 'Jessica', 'Castro', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jerome32@example.com', 'Alexander', 'Jacobson', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('victoriaharvey@example.org', 'Anne', 'Robertson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('gonzalezkristina@example.net', 'Amanda', 'Lopez', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('kathleen01@example.com', 'Jonathan', 'Ward', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('joneschristine@example.com', 'Darryl', 'Rios', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('sancheznathaniel@example.com', 'Olivia', 'Montoya', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('stricklandjoshua@example.com', 'Alyssa', 'Stevens', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michaelsanders@example.com', 'Alex', 'Hogan', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('zimmermanjoseph@example.net', 'Doris', 'Ray', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('gmurray@example.net', 'Jessica', 'Watson', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('baldwinalexander@example.com', 'Paul', 'Wagner', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('shelby43@example.net', 'Maria', 'Arellano', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('russell07@example.org', 'Anna', 'Hernandez', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('millerashley@example.com', 'Johnny', 'Garrett', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jeremiahcharles@example.com', 'Marisa', 'Warren', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('llarson@example.net', 'Colleen', 'Rodriguez', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('schmittwilliam@example.com', 'Cheryl', 'Vasquez', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('darrelltodd@example.com', 'Shawn', 'Smith', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('charlesthomas@example.com', 'Amy', 'Hicks', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('wking@example.com', 'Vanessa', 'Blanchard', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('lambertkevin@example.net', 'Haley', 'Davis', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('danabrown@example.net', 'Rachel', 'Smith', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jeffreybryan@example.com', 'Gary', 'Perez', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('shawnwilliams@example.org', 'Sonya', 'Zimmerman', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michael45@example.com', 'Timothy', 'Gray', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('perezgary@example.org', 'Raymond', 'Baker', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('bowmanwillie@example.org', 'Michael', 'Thomas', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('christopher84@example.com', 'Caitlin', 'Miller', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('taramiller@example.com', 'Michael', 'Martinez', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('rodriguezjeffrey@example.org', 'Gwendolyn', 'Coleman', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jessicabass@example.com', 'Jeremiah', 'Dorsey', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('dharris@example.com', 'Sheila', 'Sampson', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jenniferthomas@example.com', 'Mary', 'Martin', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('tuckermichael@example.com', 'Thomas', 'Daniels', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('ubridges@example.com', 'Lauren', 'Jones', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('deanna97@example.com', 'Elizabeth', 'Sullivan', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jeffreyburton@example.net', 'Alexandra', 'Ortiz', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('kevin16@example.org', 'George', 'Johnson', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('davidblack@example.com', 'Robert', 'Martin', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('alexandra18@example.net', 'Kristina', 'Tran', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michelle97@example.org', 'Crystal', 'Hicks', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('kirklisa@example.org', 'Shannon', 'Taylor', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('peggycruz@example.org', 'Maria', 'Clark', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('frankgibson@example.com', 'Jillian', 'Jordan', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('dcox@example.org', 'Melanie', 'Martin', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('shannonward@example.net', 'Kelly', 'Smith', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('xbrown@example.org', 'Timothy', 'Foster', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('bakerjason@example.net', 'Sandra', 'Price', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('josehill@example.org', 'Zoe', 'Noble', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('nweeks@example.net', 'Rebekah', 'Grant', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('christophertaylor@example.net', 'Johnny', 'Vang', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('marcusherman@example.com', 'Brandon', 'Livingston', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('daniel60@example.com', 'Henry', 'Anderson', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('homichelle@example.org', 'Diane', 'Parsons', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('lawsonpeter@example.net', 'Michael', 'Diaz', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('april62@example.net', 'Christopher', 'Wilson', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('smithtiffany@example.org', 'Lisa', 'Roberson', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('jacobmacias@example.net', 'Michael', 'Jones', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('karenkelly@example.net', 'Benjamin', 'Rivera', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('russojeffrey@example.net', 'Rachel', 'Wagner', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('michael87@example.com', 'Thomas', 'Mora', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('gdavid@example.net', 'Jenna', 'Smith', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('tbutler@example.org', 'Debbie', 'Knight', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('oacosta@example.com', 'John', 'Kelley', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('smckenzie@example.net', 'Tamara', 'Deleon', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('frankmatthew@example.net', 'Austin', 'Phillips', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('bernardtheresa@example.org', 'Victor', 'Blevins', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('dianestrong@example.com', 'Lisa', 'Newman', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('trogers@example.net', 'Kimberly', 'Acosta', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('seanelliott@example.com', 'Andrew', 'Wright', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('russellmccall@example.net', 'Regina', 'Silva', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('craiggreene@example.org', 'Jason', 'Ford', 2);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('robertrivera@example.com', 'Kenneth', 'Simon', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('benjaminglover@example.org', 'Shane', 'Gutierrez', 3);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('sbarber@example.org', 'Gregory', 'Cross', 1);
INSERT INTO students (email, firstName, lastName, classroomId) VALUES ('rebeccabarrera@example.com', 'Carol', 'Bates', 2);


INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('slucas@example.org', 'Alexis', 'Harmon', 'wardjuan@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('thompsonthomas@example.org', 'Timothy', 'Allen', 'dawnmurphy@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('mwhite@example.com', 'Meghan', 'Brown', 'jfinley@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('forbesangela@example.net', 'Scott', 'Allen', 'lserrano@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('andersenrenee@example.net', 'Keith', 'Davis', 'zimmermancarla@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('butlerebony@example.com', 'Kathleen', 'Rhodes', 'jfinley@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ohardy@example.com', 'Sandra', 'Castro', 'jameswheeler@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('mccoystephanie@example.net', 'Shelly', 'Chambers', 'russojeffrey@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('kylierichardson@example.com', 'Fred', 'Morris', 'fisherchristina@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('amybaker@example.com', 'Emily', 'Figueroa', 'brookemcmahon@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('riverachristopher@example.org', 'Anthony', 'Roberson', 'michael77@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('grose@example.com', 'Natalie', 'Smith', 'rpark@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('espinozajohn@example.com', 'Cody', 'Mahoney', 'daniel60@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('brendacase@example.org', 'Amanda', 'Baker', 'christopher84@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('donna81@example.com', 'Tony', 'Wright', 'jerome32@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('robertsonkaren@example.org', 'Corey', 'Anderson', 'qwiggins@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('njohnson@example.com', 'Megan', 'Mccormick', 'benjaminglover@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('kevinlowe@example.com', 'Cynthia', 'Adams', 'feliciagraham@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('edavis@example.net', 'Robert', 'Ferguson', 'tyrone33@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('dawsonbrooke@example.com', 'Molly', 'Sweeney', 'toddvernon@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('johnsonjason@example.com', 'Justin', 'Williams', 'sgardner@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('clifford58@example.org', 'Scott', 'Graves', 'gvillarreal@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ian10@example.com', 'Amanda', 'Bryant', 'jerome32@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('stephanie06@example.org', 'Robert', 'Hill', 'michelle97@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('lopezkaren@example.com', 'Carrie', 'Buck', 'rodriguezjeffrey@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('aaronhall@example.net', 'Eric', 'Decker', 'campbellanthony@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jamiepeters@example.net', 'Aaron', 'Lyons', 'dortiz@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('cburns@example.org', 'Melissa', 'Gonzalez', 'davidfowler@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('daniellehuynh@example.org', 'Keith', 'Delgado', 'kimberly67@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('tayloranna@example.com', 'Melinda', 'Morgan', 'jerome32@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('stephanieweber@example.net', 'Douglas', 'Kerr', 'jrosario@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('farellano@example.com', 'Rachel', 'Martin', 'porterbrittany@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('michael87@example.net', 'Sonya', 'Smith', 'gmartinez@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('adam68@example.net', 'Colleen', 'Gonzalez', 'bernardtheresa@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('trevinokatie@example.net', 'Christopher', 'Simmons', 'jessicabass@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('vrobertson@example.org', 'Roberto', 'Sandoval', 'russellcory@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('cmccarthy@example.com', 'Sharon', 'Smith', 'halecody@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('mryan@example.net', 'Raymond', 'Solomon', 'gavin81@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('lori64@example.net', 'Cindy', 'Powell', 'dawnmurphy@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('angelawilson@example.org', 'Alexander', 'Richards', 'johnathan44@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('markcuevas@example.net', 'Krista', 'Perez', 'kevin16@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('teresa95@example.org', 'Frank', 'Smith', 'danielrobinson@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('brittany76@example.net', 'Bruce', 'Yates', 'christy59@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('russellcharles@example.org', 'Brian', 'Jennings', 'rpark@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('fewing@example.org', 'Johnny', 'Gutierrez', 'hunterrobin@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('farrellkarl@example.net', 'Allen', 'Arnold', 'juliasullivan@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('egarcia@example.com', 'James', 'Davis', 'benjaminglover@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('sullivanmelissa@example.com', 'Kylie', 'Villarreal', 'tmassey@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('michaeltaylor@example.com', 'Angela', 'Phillips', 'millerashley@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('vriddle@example.org', 'Dean', 'Aguirre', 'angelareid@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('edward97@example.net', 'Jesse', 'Scott', 'carriebuck@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('christian99@example.org', 'Karen', 'Smith', 'russojeffrey@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('phamdouglas@example.com', 'Sandra', 'Cowan', 'arnoldgabrielle@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('timothy63@example.org', 'Donna', 'Mills', 'dharris@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('druiz@example.com', 'Omar', 'Harris', 'lbradshaw@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('davidroberts@example.com', 'Lauren', 'Ortega', 'dward@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('cherryterri@example.com', 'Natalie', 'Villanueva', 'deanna97@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('walteryork@example.org', 'Tyrone', 'Collins', 'crystal81@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('michelledecker@example.com', 'Melissa', 'Garcia', 'dianestrong@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('michaeljimenez@example.net', 'Peter', 'Hawkins', 'pcardenas@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jeffreywalter@example.com', 'Dorothy', 'Cross', 'benjaminglover@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('zachary81@example.org', 'Stephanie', 'Williams', 'ihuber@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('cookbenjamin@example.com', 'Alexander', 'Gross', 'pcardenas@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('mejiakathryn@example.com', 'Zachary', 'Wells', 'gregoryfisher@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('todd46@example.com', 'Alexandra', 'Carroll', 'taramiller@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('tamarawheeler@example.net', 'Cameron', 'White', 'vparker@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('markedwards@example.org', 'Robert', 'Torres', 'michelledalton@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('josephmitchell@example.com', 'Kimberly', 'Adams', 'snyderisaiah@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('irobinson@example.com', 'John', 'Green', 'smithtiffany@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('oliviatorres@example.com', 'Joseph', 'Schwartz', 'daniel60@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('sandy18@example.net', 'Lance', 'Owens', 'carriebuck@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('grayshirley@example.com', 'Michelle', 'Sawyer', 'danabrown@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('fmiller@example.org', 'Christina', 'Bond', 'edwardjohnson@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('aliciafields@example.com', 'Jasmine', 'Armstrong', 'charlesvalentine@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('prattchristopher@example.com', 'Charlotte', 'Anderson', 'susanelliott@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ashleyrobinson@example.com', 'Rhonda', 'Goodwin', 'jeffreybryan@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('fparks@example.net', 'Elizabeth', 'Herring', 'havila@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('kellis@example.net', 'Tony', 'Hartman', 'fcook@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('adambrown@example.org', 'Julia', 'Lawrence', 'toddvernon@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gregory25@example.net', 'Tyler', 'Smith', 'nedwards@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('tperry@example.net', 'Rachel', 'Barnes', 'thomas29@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('myersanthony@example.com', 'Luis', 'Rice', 'lambertkevin@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('kmeyer@example.org', 'Brian', 'Russell', 'shannonward@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('dlivingston@example.com', 'Michael', 'Vaughan', 'lserrano@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('evanbrown@example.org', 'Ryan', 'Padilla', 'robertrivera@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('loricase@example.net', 'Mark', 'Jones', 'pcardenas@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('danderson@example.com', 'Debra', 'Marquez', 'carriebuck@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('davisdawn@example.org', 'Cody', 'Lee', 'baldwinalexander@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('robertrodriguez@example.com', 'Brenda', 'Welch', 'hhernandez@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('smalone@example.com', 'Kristie', 'Martinez', 'jameswheeler@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('alexwhite@example.com', 'Matthew', 'Cardenas', 'homichelle@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('melissa94@example.net', 'Jonathan', 'Romero', 'bernardtheresa@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('brittanyward@example.org', 'Michelle', 'Williams', 'robertrivera@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ronaldhendrix@example.com', 'Peter', 'Lynch', 'wking@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('diana25@example.net', 'Amanda', 'James', 'mcintyrejesus@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('zwu@example.com', 'Victor', 'Holland', 'michaelmccarthy@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('dwayne04@example.org', 'Matthew', 'Solis', 'dward@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('markhays@example.net', 'Mark', 'Baker', 'crystal81@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('clarkkatherine@example.com', 'Brandi', 'Tucker', 'cohentaylor@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('pgarcia@example.org', 'Danny', 'Mann', 'nshelton@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('kelly41@example.com', 'Nancy', 'Morales', 'dcox@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('qfriedman@example.net', 'Michelle', 'Smith', 'sarawilliams@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('zhobbs@example.net', 'David', 'Hughes', 'olong@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('pamela22@example.org', 'Amanda', 'Cole', 'gscott@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jesus74@example.org', 'Rachael', 'Blanchard', 'gmartinez@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ericdaugherty@example.net', 'Lisa', 'Watson', 'zcardenas@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('uwatkins@example.com', 'Dustin', 'Wells', 'havila@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('linda52@example.net', 'Kevin', 'Smith', 'hfranklin@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('guzmanadam@example.com', 'Rebecca', 'Smith', 'craiggreene@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('shelly60@example.net', 'Kathryn', 'Simpson', 'melissa43@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gibsonjohn@example.net', 'Andrew', 'Campbell', 'thomas29@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('mmeadows@example.net', 'Carla', 'Snyder', 'jeffreyward@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('brownjamie@example.org', 'Carlos', 'Garcia', 'lauren92@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('heather96@example.com', 'Sarah', 'Casey', 'tbutler@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('debra32@example.net', 'Kara', 'Padilla', 'fernandezsara@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('william63@example.org', 'David', 'Howard', 'deanna97@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('scottleslie@example.com', 'Kimberly', 'Garcia', 'carriewallace@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('brettgarza@example.net', 'Curtis', 'Sanders', 'kevin16@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('frodriguez@example.org', 'Julia', 'Williams', 'snyderisaiah@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('courtneyhurst@example.com', 'Diane', 'Chavez', 'williamsalexis@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jamesdavis@example.org', 'Michael', 'Lowe', 'alanrivera@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('briggsstephen@example.org', 'Jeremy', 'Taylor', 'carriewallace@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('clarktravis@example.org', 'Sara', 'Gonzales', 'fischerbrittany@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('cory88@example.net', 'Kimberly', 'Chen', 'rbeasley@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jacksonrose@example.org', 'Selena', 'Holmes', 'matthewedwards@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gbaxter@example.com', 'Christopher', 'Rhodes', 'edwardjohnson@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gregorysantiago@example.net', 'Paul', 'Walter', 'michelle97@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('lbarnes@example.org', 'Rose', 'Brooks', 'deannajones@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('xlang@example.net', 'Gary', 'Morgan', 'lbradshaw@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('mannamanda@example.org', 'Timothy', 'Cannon', 'darrelltodd@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('andrea83@example.net', 'Charles', 'Solis', 'fernandezsara@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('heather30@example.com', 'Elijah', 'Green', 'llarson@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jacksonscott@example.net', 'Alicia', 'White', 'karenkelly@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('olsenkaitlyn@example.org', 'Teresa', 'Terry', 'hfranklin@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('brett82@example.net', 'Randy', 'Henderson', 'zsullivan@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('robert64@example.net', 'Sandra', 'Elliott', 'russellcory@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('matastacey@example.com', 'Lee', 'Wolfe', 'logan20@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('james43@example.org', 'Jennifer', 'Hines', 'victoriaharvey@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('bianca94@example.net', 'William', 'Gardner', 'mwalters@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('sararaymond@example.net', 'Michael', 'Harris', 'homichelle@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('cynthia70@example.org', 'Tracy', 'Nunez', 'pmaxwell@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('deborahluna@example.com', 'Darlene', 'Marquez', 'russellmccall@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('howardjustin@example.org', 'Sandra', 'Hunt', 'xbrown@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('annegallagher@example.org', 'Richard', 'Larson', 'zimmermancarla@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('chanmelissa@example.org', 'Christopher', 'Clark', 'andrewhester@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('johnsonadrienne@example.com', 'Sonia', 'Henry', 'feliciagraham@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('susan14@example.net', 'April', 'Welch', 'oacosta@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('mary67@example.com', 'Christopher', 'Le', 'danny96@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('sierrathompson@example.net', 'Peter', 'Moore', 'patrick90@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('richard92@example.org', 'Jennifer', 'Ryan', 'edwardjohnson@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('cardenasashley@example.org', 'Matthew', 'Garcia', 'porterbrittany@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('christiehayes@example.com', 'Tracy', 'Ryan', 'thompsonerin@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('deborahrodriguez@example.net', 'Carl', 'Miller', 'jessicabass@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('imartinez@example.com', 'Marcus', 'Morgan', 'craiggreene@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('hhouse@example.org', 'Lauren', 'Abbott', 'alanrivera@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('matthew37@example.com', 'Joe', 'Harrison', 'michael68@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('rlane@example.com', 'Elizabeth', 'Carter', 'angelareid@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('david00@example.com', 'Mark', 'Thompson', 'tuckermichael@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gonzalespaul@example.org', 'Regina', 'Le', 'dward@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jack89@example.com', 'Wesley', 'Boyd', 'stephaniemclaughlin@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('mitchellryan@example.org', 'Jeffery', 'Munoz', 'thomas29@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jamiewright@example.net', 'Heather', 'Morris', 'feliciagraham@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('lanemackenzie@example.net', 'Grace', 'Cook', 'tracy21@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('millsemily@example.com', 'Sarah', 'Ortiz', 'gmurray@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('michaellawrence@example.com', 'Amy', 'Hayes', 'blackkatherine@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('rick61@example.org', 'Brandi', 'Barnes', 'charlesthomas@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('aaronanderson@example.net', 'Nicole', 'Alexander', 'charlesthomas@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('johnsonsarah@example.net', 'Luke', 'Thomas', 'brockjasmine@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('afreeman@example.com', 'William', 'Phelps', 'rbeasley@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('odennis@example.org', 'Benjamin', 'Murray', 'cynthia79@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('crogers@example.net', 'Christopher', 'Miller', 'samuelmcintosh@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jonathanjones@example.net', 'Melissa', 'Rhodes', 'thomascasey@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('evanssarah@example.net', 'Robert', 'Krause', 'taramiller@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('marcus87@example.net', 'Gary', 'Moore', 'tracy21@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gwendolyn46@example.com', 'Evelyn', 'Johnson', 'feliciagraham@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('richardking@example.org', 'Tony', 'Daniel', 'gonzalezkristina@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('lisasanchez@example.org', 'Zachary', 'Lewis', 'williambeasley@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('fitzpatrickandrew@example.com', 'James', 'Davis', 'michaelmccarthy@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('anita43@example.com', 'Daniel', 'Hahn', 'brookemcmahon@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('david04@example.net', 'Brittany', 'Martinez', 'stricklandjoshua@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gibsonkirsten@example.net', 'Zoe', 'Perry', 'jrosario@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('graypamela@example.net', 'Darryl', 'Hardy', 'bjohnson@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('haynesmiranda@example.net', 'Karen', 'Carter', 'jasongonzalez@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('kperry@example.net', 'Beth', 'Espinoza', 'sancheznathaniel@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('olambert@example.net', 'Melissa', 'Davis', 'fwhite@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jeannecalderon@example.com', 'Robert', 'Jones', 'jessicabass@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ellenadams@example.net', 'Rebecca', 'Dickson', 'hayley42@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('wthompson@example.com', 'Paul', 'Hughes', 'wrightcorey@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('austincarla@example.net', 'Tony', 'Morrison', 'carriebuck@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('charlenehanson@example.com', 'Pedro', 'Mueller', 'michelle97@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('smithronald@example.org', 'Roger', 'Oconnell', 'nweeks@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('darrell66@example.com', 'Katrina', 'Williams', 'bross@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('saunderschad@example.org', 'Ann', 'Garcia', 'fernandezsara@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jeffreyboone@example.org', 'Noah', 'Tucker', 'oacosta@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('adam73@example.com', 'Nicole', 'Horton', 'rodriguezjeffrey@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('bsmith@example.net', 'Megan', 'Jensen', 'michaelsanders@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gmartinez@example.org', 'Lisa', 'Martinez', 'schmittwilliam@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('wbutler@example.net', 'Misty', 'Adams', 'ymyers@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('garciadaniel@example.net', 'James', 'Nguyen', 'baldwinalexander@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('henrysierra@example.com', 'Kelli', 'Hoffman', 'antonio94@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('shafferkurt@example.net', 'Shane', 'Combs', 'adrienne09@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('oschmidt@example.com', 'Erik', 'Haynes', 'nweeks@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('llewis@example.org', 'Morgan', 'Rodriguez', 'gmurray@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('linda08@example.com', 'Christine', 'Schmidt', 'campbellanthony@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('gina85@example.net', 'John', 'Valenzuela', 'tuckermichael@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('erin87@example.net', 'Danielle', 'Herrera', 'jrosario@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('kenneth07@example.net', 'Karl', 'Hampton', 'johnhughes@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('porterscott@example.com', 'Wayne', 'Moreno', 'michael45@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ztaylor@example.net', 'Alec', 'Smith', 'thomascasey@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('freemannicole@example.org', 'Melissa', 'Moore', 'frankmatthew@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('tina55@example.net', 'Robin', 'Davidson', 'charlesthomas@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('stephen17@example.com', 'Alexis', 'Gomez', 'woodrichard@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('matthewsanders@example.com', 'Erica', 'Stewart', 'fieldsadrienne@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('chanjames@example.org', 'Alex', 'Harris', 'johnathan44@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('pcarter@example.net', 'Jamie', 'Lopez', 'josehill@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('christinahawkins@example.org', 'Kevin', 'Sanchez', 'cynthia79@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ladams@example.org', 'Alyssa', 'Clarke', 'halecody@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('batesmelissa@example.net', 'Peter', 'Rodriguez', 'paulconner@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('underwoodmonica@example.com', 'Christine', 'Miller', 'prestonmolly@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('dmoss@example.com', 'Christine', 'Schwartz', 'michelledalton@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('epetersen@example.org', 'Stephen', 'Franklin', 'sjohnson@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('calvinharris@example.com', 'Justin', 'Kirk', 'seanelliott@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('justin06@example.net', 'Joshua', 'Williams', 'gonzalezkristina@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('glennvalerie@example.org', 'Andrew', 'Gregory', 'kyoung@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('wrobinson@example.com', 'Donna', 'Rojas', 'jessicabass@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('katiejackson@example.com', 'Michael', 'Taylor', 'michaelmccarthy@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('bentleychristopher@example.com', 'Joel', 'Best', 'johnathan44@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('sandra23@example.com', 'Gregory', 'Phillips', 'hfranklin@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('lorirowland@example.org', 'Christopher', 'Clark', 'rodriguezjesse@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('melissa36@example.com', 'Christopher', 'Griffin', 'lawsonpeter@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('thomasdavid@example.com', 'Jennifer', 'Adams', 'ellistimothy@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('tylerbrown@example.com', 'Melinda', 'Horn', 'zcardenas@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('stephanie54@example.com', 'Donald', 'Baker', 'dcox@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('christine17@example.org', 'Daniel', 'Carr', 'wsalas@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('calvin34@example.com', 'Regina', 'Hicks', 'swilson@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('qsmith@example.com', 'Leah', 'Hunter', 'trogers@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('laura80@example.net', 'Suzanne', 'Gibbs', 'thompsonerin@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('nicholasbryant@example.org', 'Teresa', 'Clark', 'troywatkins@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('bgiles@example.com', 'Ashley', 'Evans', 'iramirez@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('baileyjohn@example.net', 'Edward', 'Hardin', 'dharris@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('boydshannon@example.net', 'Donald', 'Sanders', 'frankgibson@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('patricia57@example.com', 'Justin', 'Kennedy', 'matthew24@example.net');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('ppowers@example.com', 'Jennifer', 'Johnson', 'thomascasey@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('jsmith@example.com', 'Kimberly', 'Miller', 'dodonnell@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('amy96@example.com', 'Ernest', 'Robinson', 'paulconner@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('brandon69@example.net', 'Deanna', 'Cross', 'uhorn@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('john37@example.net', 'James', 'Hill', 'ihuber@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('dwalters@example.com', 'Elizabeth', 'Joseph', 'davidfowler@example.org');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('pricediana@example.com', 'Dwayne', 'Thompson', 'lisaharvey@example.com');
INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES ('awest@example.net', 'Stephanie', 'Chapman', 'deanna97@example.com');


INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 1 times 2?'), '2', 6, 'What is 1 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 2 times 2?'), '4', 17, 'What is 2 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 3 times 2?'), '6', 16, 'What is 3 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 4 times 2?'), '8', 5, 'What is 4 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 5 times 2?'), '10', 2, 'What is 5 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 6 times 2?'), '12', 12, 'What is 6 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 7 times 2?'), '14', 16, 'What is 7 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 8 times 2?'), '16', 7, 'What is 8 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 9 times 2?'), '18', 19, 'What is 9 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 10 times 2?'), '20', 15, 'What is 10 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'Who discovered gravity?'), 'Newton', 1, 'Who discovered gravity?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is the square root of 676?'), '26', 12, 'What is the square root of 676?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 14 times 2?'), '28', 14, 'What is 14 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is the chemical symbol for oxygen?'), 'O', 1, 'What is the chemical symbol for oxygen?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 16 times 2?'), '32', 12, 'What is 16 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is the speed of light in m/s?'), '299792458', 9, 'What is the speed of light in m/s?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is the atomic number of carbon?'), '6', 7, 'What is the atomic number of carbon?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 19 times 2?'), '38', 7, 'What is 19 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 20 times 2?'), '40', 8, 'What is 20 times 2?');

INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 22 plus 22?'), '44', 17, 'What is 22 plus 22?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What year did World War II end?'), '1945', 2, 'What year did World War II end?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 24 times 2?'), '48', 17, 'What is 24 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What year was the Declaration of Independence signed?'), '1776', 14, 'What year was the Declaration of Independence signed?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 26 times 2?'), '52', 18, 'What is 26 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is the capital of France?'), 'Paris', 13, 'What is the capital of France?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 28 times 2?'), '56', 17, 'What is 28 times 2?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'Who wrote "To Kill a Mockingbird"?'), 'Harper Lee', 18, 'Who wrote "To Kill a Mockingbird"?');
INSERT INTO assignedQuestions (questionId, answer, classId, question_text) VALUES ((SELECT questionId FROM questions WHERE question_text = 'What is 30 times 2?'), '60', 16, 'What is 30 times 2?');



INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('sarawilliams@example.net', 'O', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('dawnmurphy@example.org', '38', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('johnathan44@example.com', '48', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('dawnmurphy@example.org', '26', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('brookemcmahon@example.org', 'Paris', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('stephaniemclaughlin@example.org', '299792458', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('robert65@example.net', '299792458', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jeffreyburton@example.net', '44', 28);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('daniel60@example.com', '18', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('lambertkevin@example.net', '14', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('paulconner@example.com', '8', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bakerjason@example.net', '12', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('williamsbrian@example.org', '2', 6);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('peggycruz@example.org', '2', 28);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jasongonzalez@example.com', '40', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('marcusherman@example.com', 'Harper Lee', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('peggycruz@example.org', '40', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('charlesvalentine@example.org', '6', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('hhernandez@example.com', '8', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('joneschristine@example.com', 'Newton', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('russellcory@example.com', 'O', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('carriewallace@example.com', '16', 8);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jacobmacias@example.net', '299792458', 18);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('johnathan44@example.com', '299792458', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('josehill@example.org', '12', 13);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('sgardner@example.com', '2', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('thompsonerin@example.net', '44', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('benjaminglover@example.org', '48', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xblankenship@example.org', '16', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jrosario@example.org', '1945', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('oacosta@example.com', '52', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('april62@example.net', '12', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('gmartinez@example.net', '2', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('christian29@example.net', '299792458', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('kathleen01@example.com', '1945', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('shawnwilliams@example.org', 'Washington', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('monroekimberly@example.net', '60', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('cynthia79@example.org', '299792458', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('smckenzie@example.net', '18', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('charlescaleb@example.com', '4', 28);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('feliciagraham@example.org', '299792458', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xtaylor@example.com', '1945', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('krobinson@example.net', 'Harper Lee', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('davidfowler@example.org', '12', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('taramiller@example.com', '4', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('hfranklin@example.net', '18', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('qwiggins@example.org', 'Paris', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('mwalters@example.net', '14', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('shawnwilliams@example.org', '32', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('yanderson@example.net', '299792458', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('havila@example.com', '6', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('mwalters@example.net', '1776', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xmcknight@example.org', 'Harper Lee', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jhahn@example.org', '6', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('brookemcmahon@example.org', 'Paris', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('hfranklin@example.net', '12', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('tbutler@example.org', '8', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('christophertaylor@example.net', 'Paris', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('carlareeves@example.net', '14', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('richardkelli@example.net', '12', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('blackkatherine@example.com', '2', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('yanderson@example.net', '10', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bryanlittle@example.org', '8', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('nweeks@example.net', '56', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('richardfox@example.com', '44', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('wking@example.com', '20', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('mathewsandrew@example.org', '12', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('gscott@example.com', 'Harper Lee', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('rodriguezjeffrey@example.org', '14', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('logan20@example.org', '20', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('juliasullivan@example.net', '8', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('carriewallace@example.com', '4', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('dodonnell@example.org', 'Harper Lee', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('alex11@example.net', '10', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('charlescaleb@example.com', '10', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('susanelliott@example.com', '1945', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('joneschristine@example.com', '40', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('richardfox@example.com', 'Harper Lee', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('cscott@example.com', 'Newton', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('john14@example.com', '20', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('schmittwilliam@example.com', '299792458', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jeffreyward@example.org', '52', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('carriewallace@example.com', '1776', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('havila@example.com', '8', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michaelmccarthy@example.net', '52', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michael45@example.com', '12', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xbrown@example.org', '44', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fwhite@example.org', '2', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('pwright@example.com', '1945', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('stephaniemclaughlin@example.org', '1945', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jeffreybryan@example.com', '38', 13);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('josehill@example.org', '14', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('christian29@example.net', '2', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('wendy06@example.com', '60', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('crystal81@example.org', '40', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michael68@example.net', 'O', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('ymyers@example.com', '38', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jessicabass@example.com', '38', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('samuelmcintosh@example.com', '18', 13);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xbrown@example.org', '40', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('leonsmith@example.com', '14', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('perezgary@example.org', '8', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('gmartinez@example.net', '20', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('paulconner@example.com', '10', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jameswheeler@example.com', '1945', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('danielrobinson@example.org', '38', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bross@example.net', 'Newton', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xblankenship@example.org', '4', 18);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('uhorn@example.com', 'O', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('nicholasmckenzie@example.com', '14', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xbrown@example.org', '16', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('cohentaylor@example.net', '52', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('joneschristine@example.com', '56', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('smithtiffany@example.org', '4', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('nicholasmckenzie@example.com', '18', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('cannonkristen@example.net', '48', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michelledalton@example.com', '28', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('hunterrobin@example.org', '28', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('rodriguezjesse@example.net', 'Newton', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('baldwinalexander@example.com', '1945', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('nweeks@example.net', '6', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fisherchristina@example.com', '1776', 8);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('wrightcorey@example.com', '2', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('lawsonpeter@example.net', 'Harper Lee', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bernardtheresa@example.org', 'O', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bowmanwillie@example.org', '16', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('tracy21@example.org', '1776', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('rpark@example.net', 'Paris', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('david49@example.com', '26', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('williamsbrian@example.org', '299792458', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('adrienne09@example.net', '6', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('gvillarreal@example.net', '16', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('ellistimothy@example.org', '56', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('troywatkins@example.com', '6', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bjohnson@example.net', '32', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('tuckermichael@example.com', '60', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('tuckermichael@example.com', '26', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fieldsadrienne@example.com', '18', 8);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('zimmermancarla@example.com', '56', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('kathleen01@example.com', '8', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('schmittwilliam@example.com', 'Harper Lee', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('williamsbrian@example.org', '10', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jessicabass@example.com', '60', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('sbarber@example.org', '4', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('blackkatherine@example.com', '20', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('frankgibson@example.com', 'Paris', 6);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('tyrone33@example.com', 'Harper Lee', 8);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('krobinson@example.net', '56', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('shannonward@example.net', '18', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('matthew24@example.net', '8', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('cannonkristen@example.net', '8', 28);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('carriebuck@example.org', '52', 6);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('victoriaharvey@example.org', '48', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('uhorn@example.com', '10', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('swilson@example.org', '12', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bernardtheresa@example.org', '1945', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('trogers@example.net', '8', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('pwright@example.com', '6', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('markavery@example.net', '16', 13);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('melissa94@example.net', '32', 18);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('victoriaharvey@example.org', 'Washington', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('swilson@example.org', '48', 18);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('melissa94@example.net', '14', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('woodrichard@example.com', '26', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bryanlittle@example.org', '32', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('monroekimberly@example.net', '26', 7);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('peggycruz@example.org', 'O', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('olong@example.net', '6', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('nedwards@example.org', '1776', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('johnathan44@example.com', 'Paris', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('nweeks@example.net', '14', 1);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('homichelle@example.org', 'Newton', 6);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('matthewedwards@example.com', '299792458', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('blackkatherine@example.com', '52', 7);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('lbradshaw@example.com', '6', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('troywatkins@example.com', '20', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('zzhang@example.org', '6', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('julia70@example.com', '8', 8);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jrosario@example.org', '2', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('aaron88@example.org', '56', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('tracy21@example.org', '6', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('dcox@example.org', '12', 18);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('kennethrobertson@example.org', '2', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jameswheeler@example.com', '26', 7);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jasongonzalez@example.com', '1945', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('melissa94@example.net', '4', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('cynthia35@example.net', '8', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jennifer23@example.org', '28', 6);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('frankmatthew@example.net', '12', 8);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bernardtheresa@example.org', '28', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('lauren92@example.org', '10', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('angelareid@example.org', '38', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fwhite@example.org', 'Harper Lee', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('patrick90@example.org', '56', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('iramirez@example.org', 'Newton', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('mcintyrejesus@example.com', 'Washington', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('havila@example.com', '20', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('robert65@example.net', '12', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michaelsanders@example.com', '18', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('davidblack@example.com', '6', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('williamsshelby@example.net', '40', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('edwardjohnson@example.net', '6', 3);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('lambertkevin@example.net', '8', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fieldsadrienne@example.com', '20', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jeffreyward@example.org', '20', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('olong@example.net', '60', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('alanrivera@example.net', '44', 8);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jonespamela@example.com', '6', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('williamsshelby@example.net', '32', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jessicabass@example.com', '44', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('wrightcorey@example.com', '56', 24);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('danabrown@example.net', '26', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jessicabass@example.com', '18', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('sarawilliams@example.net', '48', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('williamsshelby@example.net', '18', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('llarson@example.net', '16', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michael68@example.net', 'Newton', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('christian29@example.net', '1776', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bross@example.net', '14', 28);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('llarson@example.net', '18', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('uhorn@example.com', 'O', 22);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jrosario@example.org', 'Newton', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('marcusherman@example.com', '48', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('deannajones@example.net', '28', 28);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jasongonzalez@example.com', '12', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('krobinson@example.net', '48', 28);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('christian29@example.net', 'Washington', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('williamsshelby@example.net', '18', 7);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('karenkelly@example.net', '8', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('andrewhester@example.org', '28', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('kathleen01@example.com', '40', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fischerbrittany@example.net', '10', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jessicabass@example.com', '2', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('shelby43@example.net', '6', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('kirklisa@example.org', '28', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('qwiggins@example.org', '12', 13);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('alex11@example.net', '10', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xtaylor@example.com', '48', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jeffreyburton@example.net', '1776', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('tuckermichael@example.com', '26', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('craiggreene@example.org', '20', 1);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('rpark@example.net', '20', 18);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('stricklandjoshua@example.com', '18', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('rebeccabarrera@example.com', 'Washington', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('tbutler@example.org', '299792458', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('alan52@example.org', '12', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('karenkelly@example.net', '32', 8);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('darrelltodd@example.com', '56', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('sancheznathaniel@example.com', '14', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('halecody@example.com', 'O', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('taramiller@example.com', '8', 11);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('david49@example.com', '1776', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('trogers@example.net', '44', 13);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('john14@example.com', '48', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('gdavid@example.net', 'Paris', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michelledalton@example.com', '16', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('deannajones@example.net', '14', 27);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('russellmccall@example.net', '14', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jasonmitchell@example.com', '18', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('rbeasley@example.net', '8', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('antonio94@example.net', '1945', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('kimberly67@example.com', 'Newton', 20);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('smithtiffany@example.org', '12', 6);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michaelsanders@example.com', 'Newton', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jameswheeler@example.com', '38', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('dodonnell@example.org', '6', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('joneschristine@example.com', '56', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('halecody@example.com', '16', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('john14@example.com', 'O', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('hfranklin@example.net', '6', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('sgardner@example.com', '48', 15);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fieldsadrienne@example.com', 'Newton', 23);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michael45@example.com', 'Washington', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('dharris@example.com', '12', 26);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('benjaminglover@example.org', '28', 2);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('bakerjason@example.net', '56', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('zzhang@example.org', '52', 10);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('zcardenas@example.net', '2', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michael45@example.com', '16', 1);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('gscott@example.com', '60', 14);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('michael45@example.com', 'Paris', 21);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('danny96@example.org', '299792458', 19);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('antonio94@example.net', '38', 6);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('jameswheeler@example.com', 'Washington', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('susanelliott@example.com', '60', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fernandezsara@example.org', '2', 9);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xblankenship@example.org', 'Washington', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('alex11@example.net', '60', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('melissa43@example.org', '26', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('baldwinalexander@example.com', '40', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('johnhughes@example.org', 'O', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('xbrown@example.org', '10', 25);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('fisherchristina@example.com', '16', 4);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('johnathan44@example.com', '48', 16);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('julia70@example.com', '14', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('gdavid@example.net', 'Washington', 17);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('williambeasley@example.com', '40', 13);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('samuelmcintosh@example.com', '2', 12);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('richardkelli@example.net', '32', 5);
INSERT INTO activity (email, submittedAnswer, assignedQuestionId) VALUES ('ymyers@example.com', 'Paris', 27);