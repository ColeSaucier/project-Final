from flask import Blueprint, request, jsonify, make_response, current_app
import json
from src import db

questions = Blueprint('questions', __name__)

# Get all the questions from the database
@questions.route('/questions', methods=['GET'])
def get_questions():
    # get a cursor object from the database
    cursor = db.get_db().cursor()

    # use cursor to query the database for a list of products
    cursor.execute('SELECT questionId, subject , answer, question_text FROM questions')

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



### Get question categories
@questions.route('/types', methods = ['GET'])
def get_all_categories():
    query = '''
        SELECT DISTINCT subject FROM questions
        WHERE subject IS NOT NULL
    '''

    cursor = db.get_db().cursor()
    cursor.execute(query)

    json_data = []
    # fetch all the column headers and then all the data from the cursor
    column_headers = [x[0] for x in cursor.description]
    theData = cursor.fetchall()
    # zip headers and data together into dictionary and then append to json data dict.
    for row in theData:
        json_data.append(dict(zip(column_headers, row)))
    
    return jsonify(json_data)

### Get question categories
@questions.route('/selection', methods = ['GET'])
def get_selected():

    # collecting data from the request object 
    the_data = request.json
    current_app.logger.info(the_data)
    query = f'''
        SELECT * FROM questions
        WHERE subject = '{str(the_data)}'
    '''

    cursor = db.get_db().cursor()
    cursor.execute(query)

    json_data = []
    # fetch all the column headers and then all the data from the cursor
    column_headers = [x[0] for x in cursor.description]
    theData = cursor.fetchall()
    # zip headers and data together into dictionary and then append to json data dict.
    for row in theData:
        json_data.append(dict(zip(column_headers, row)))
    
    return jsonify(json_data)