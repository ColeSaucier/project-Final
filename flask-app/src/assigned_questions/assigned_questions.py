from flask import Blueprint, request, jsonify, make_response, current_app
import json
from src import db


assigned_questions = Blueprint('assigned_questions', __name__)

@assigned_questions.route('/assign', methods=['POST'])
def add_new_assignment():
    # Collecting data from the request object
    the_data = request.json
    current_app.logger.info(the_data)
    
    # Extracting variables
    questions = the_data.get('questions', [])
    class_id = the_data.get('classId')
    
    for question in questions:
        question_id = question.get('questionId')
        answer = question.get('answer')
        query = f'INSERT INTO assignedQuestions (questionId, answer, classId) VALUES ("{question_id}", "{answer}", "{class_id}")'
        current_app.logger.info(query)
        