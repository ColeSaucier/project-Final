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
    