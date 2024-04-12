from flask import Blueprint, request, jsonify, make_response, current_app
import json
from src import db


assigned_questions = Blueprint('assigned_questions', __name__)

@assigned_questions.route('/assign', methods=['POST'])
def add_new_assignment():
    # Collecting data 
    the_data = request.json
    current_app.logger.info(the_data)
    
    # Extracting variables
    questions = the_data.get('questions', [])
    class_id = the_data.get('classId')   
    
    # Iterate through questions
    for question_id in questions:
        question_query = 'SELECT question_text FROM questions WHERE questionId = %s'
        cursor = db.get_db().cursor()
        cursor.execute(question_query, (question_id,))
        question_text = cursor.fetchone()
        answer_query = 'SELECT answer FROM questions WHERE questionId = %s'
        cursor.execute(answer_query, (question_id,))
        answer = cursor.fetchone()
        insert_query = 'INSERT INTO assignedQuestions (questionId, question_text, answer, classId) VALUES (%s, %s, %s, %s)'
        cursor.execute(insert_query, (question_id, question_text[0], answer[0], class_id))
        db.get_db().commit()

    return 'Success!'

### Get all the classrooms
@assigned_questions.route('/classrooms', methods = ['GET'])
def get_all_categories():
    query = '''
        SELECT DISTINCT classId FROM assignedQuestions ORDER BY classId ASC;
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

### Get the assinment from the classroom
@assigned_questions.route('/class_assigned', methods = ['GET'])
def get_selected():

    # collecting data from the request object 
    the_data = request.json
    current_app.logger.info(the_data)
    query = f'''
        SELECT * FROM assignedQuestions
        WHERE classId = '{the_data}'
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

@assigned_questions.route('/delete_assigned', methods=['DELETE'])
def delete_assigned():
    # collecting data from the request object
    the_data = request.json
    assignedQuestion = the_data['assignedQuestionId']
    query = f'DELETE FROM assignedQuestions WHERE assignedQuestionId = {assignedQuestion};'
    current_app.logger.info(f'Query = {query}')
    cursor = db.get_db().cursor()
    cursor.execute(query)
    db.get_db().commit()
    return 'Success!'

