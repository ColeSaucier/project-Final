from flask import Blueprint, request, jsonify, make_response
import json
from src import db


studentProgress = Blueprint('studentProgress', __name__)

# Get emails associated with a parent or any student (used by studentProgress table)
@studentProgress.route('/emails', methods=['GET'])
def get_emails():
    # get a cursor object from the database
    cursor = db.get_db().cursor()

    # query db for emails (including associated p.parent)
    cursor.execute('SELECT s.email as StudentEmail, p.email as ParentEmail FROM students s LEFT JOIN parent p ON p.studentEmail = s.email') #s.first_name, s.last_name, p.parent_name,

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



# Get specific student's progress (by subject)
@studentProgress.route('/<userEmail>', methods=['GET'])
def get_customer(userEmail):
    cursor = db.get_db().cursor()
    cursor.execute(f"select firstName as FirstName, subject as Subject, totalCorrect as Correct, totalAttempts as Attempts from studentsProgress where studentEmail = '{userEmail}'")
    row_headers = [x[0] for x in cursor.description]
    json_data = []
    theData = cursor.fetchall()
    for row in theData:
        json_data.append(dict(zip(row_headers, row)))
    the_response = make_response(jsonify(json_data))
    the_response.status_code = 200
    the_response.mimetype = 'application/json'
    return the_response

# Get specific student's progress (by subject)
@studentProgress.route('/studentEmails', methods=['GET'])
def get_studentemails():
    # get a cursor object from the database
    cursor = db.get_db().cursor()

    # query db for emails (including associated p.parent)
    cursor.execute('select firstName as FirstName, email from students') #s.first_name, s.last_name, p.parent_name,

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



