########################################################
# Sample customers blueprint of endpoints
# Remove this file if you are not using it in your project
########################################################
from flask import Blueprint, request, jsonify, make_response
import json
from src import db


activity = Blueprint('activity', __name__)
'''
@activity.route('/activity', methods=['POST'])
def add_activity():
    
    # collecting data from the request object 
    the_data = request.json
    current_app.logger.info(the_data)

    #extracting the variable
    email = the_data['email']
    submittedAnswer = the_data['submittedAnswer']
    correctness = the_data['correctness']
    assigned_questionId = the_data['assigned_questionId']
    #code for 

    # Constructing the query
    query = 'insert into activity (email, submittedAnswer, correctness, assigned_questionId) values ("'
    query += email + '", "'
    query += submittedAnswer + '", "'
    query += correctness + '", "'
    query += str(assigned_questionId) + ')'
    current_app.logger.info(query)

    # executing and committing the insert statement 
    cursor = db.get_db().cursor()
    cursor.execute(query)
    db.get_db().commit()
    
    return 'Success!'
'''
# Get all the products from the database
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

@activity.route('/activity', methods=['POST'])
def update_customer():
    #request is body of api input
    data = request.get_json()

    # Insert a new row into activity
    cursor = db.get_db().cursor()
    cursor.execute(
        "INSERT INTO activity (email, submittedAnswer, correctness, assignedQuestionId) VALUES (%s, %s, %s, %s)",
        (data['email'], data['submittedAnswer'], data['correctness'],
         data['assignedQuestionId'])
    )
    db.get_db().commit()


    #website response outputs
    the_response = make_response(jsonify(data))
    the_response.status_code = 200
    the_response.mimetype = 'application/json'
    return the_response
