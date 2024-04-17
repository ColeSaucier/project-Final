-- This file is to bootstrap a database for the CS3200 project.

-- Create a new database.  You can change the name later.  You'll
-- need this name in the FLASK API file(s),  the AppSmith
-- data source creation.
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

