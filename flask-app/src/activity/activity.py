from flask import Blueprint, request, jsonify, make_response
import json
from src import db


activity = Blueprint('activity', __name__)

# Get all activity from the database
@activity.route('/activity', methods=['GET'])
def get_activities():
    # get a cursor object from the database
    cursor = db.get_db().cursor()

    # use cursor to query the database for a list of products
    cursor.execute('SELECT * FROM activity')

    # grab the column headers from the returned data
    column_headers = [x[0] for x in cursor.description]

    # create an empty dictionary object to use in 
    # putting column headers together with data
    json_data = []

    # fetch all the data from the cursor
    theData = cursor.fetchall()

    # for each of the rows, zip the data elements together with
    # the column headers. 
    for row in theData:
        json_data.append(dict(zip(column_headers, row)))

    return jsonify(json_data)

# Input an answer - adds a row
@activity.route('/activity/<inputAnswer>', methods=['POST'])
def insert_activity(inputAnswer):
    #request is body of api input
    data = request.get_json()
    cursor = db.get_db().cursor()

    #ClassroomProgress(table) query
    if data['assignedQuestionId'] != None: #try:
        # If the questionId key is not present, retrieve the answer from the assignedQuestions table
        cursor.execute(
            "SELECT answer FROM assignedQuestions WHERE assignedQuestionId = %s",
            (data['assignedQuestionId'],)
        )
        answer = cursor.fetchone()[0]
    #ALL(table) query
    else:
        # If the assignedQuestionId key is not present, retrieve the answer from the questions table
        cursor.execute(
            "SELECT answer FROM questions WHERE questionID = %s",
            (data['questionId'],)
        )
        answer = cursor.fetchone()[0]
        data['assignedQuestionId'] = None


    # Check the correctness of the input answer
    if inputAnswer.lower() == answer.lower():
        correctness = 1
        response_message = "Correct answer!"
    else:
        correctness = 0
        response_message = "Incorrect answer. Please try again."

    # Insert a new row into activity
    cursor.execute(
        "INSERT INTO activity (email, submittedAnswer, correctness, assignedQuestionId) VALUES (%s, %s, %s, %s)",
        (data['email'], inputAnswer, correctness,
         data['assignedQuestionId'])
    )
    db.get_db().commit()


    # Return the response message
    the_response = make_response(jsonify({"message": response_message}))
    the_response.status_code = 200
    the_response.mimetype = 'application/json'
    return the_response

# Get all the questions from the database (classroom or all)
@activity.route('/<classroomYes>/<userEmail>', methods=['GET'])
def get_questions(classroomYes, userEmail):
    # get a cursor object from the database
    cursor = db.get_db().cursor()

    # Classroom or All Questions query
    if classroomYes != "classroom":
        # use cursor to query the database for a list of questions
        cursor.execute('SELECT questionId, subject, question_text FROM questions')
    else:
        # use cursor to query classroomProgress by studentEmail
        cursor.execute(f"SELECT cp.firstName AS FirstName, cp.correctness AS Done, cp.totalAttempts AS Attempts, cp.assignedQuestionId, aq.question_text FROM classroomProgress cp LEFT JOIN assignedQuestions aq ON cp.assignedQuestionId = aq.assignedQuestionId WHERE cp.email = '{userEmail}'")
    
    # grab the column headers from the returned data
    column_headers = [x[0] for x in cursor.description]

    # create an empty dictionary object to use in 
    # putting column headers together with data
    json_data = []

    # fetch all the data from the cursor
    theData = cursor.fetchall()

    # for each of the rows, zip the data elements together with
    # the column headers. 
    for row in theData:
        json_data.append(dict(zip(column_headers, row)))

    return jsonify(json_data)

