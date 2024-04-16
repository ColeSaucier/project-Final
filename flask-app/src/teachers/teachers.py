from flask import Blueprint, request, jsonify, make_response, current_app
import json
from src import db

teachers = Blueprint('teachers', __name__)

# Get all teachers from the DB
@teachers.route('/teacher', methods=['GET'])
def get_teachers():
    cursor = db.get_db().cursor()
    cursor.execute('select teacherId, firstName, lastName,\
        email, phoneNumber from teacher')
    row_headers = [x[0] for x in cursor.description]
    json_data = []
    theData = cursor.fetchall()
    for row in theData:
        json_data.append(dict(zip(row_headers, row)))
    the_response = make_response(jsonify(json_data))
    the_response.status_code = 200
    the_response.mimetype = 'application/json'
    return the_response

# teachers Put Route
@teachers.route('/teacher', methods=['PUT'])
def update_teachers():
    teacher_info = request.json
    # current_app.logger.info(teacher_info)
    teacherId = teacher_info['teacherId']
    firstName = teacher_info['firstName']
    lastName = teacher_info['lastName']
    email = teacher_info['email']
    phoneNumber = teacher_info['phoneNumber']
    
    query = 'UPDATE teacher SET firstName = %s, lastName = %s, email = %s, phoneNumber = %s where teacherId = %s'
    data = (firstName, lastName, email, phoneNumber, teacherId)
    cursor = db.get_db().cursor()
    r = cursor.execute(query, data)
    db.get_db().commit()
    return 'teacher updated!'


# teachers post route
@teachers.route('/teacher', methods=['POST'])
def add_new_teacher():
    
    # collecting data from the request object 
    the_data = request.json
    #current_app.logger.info(the_data)

    #extracting the variable
    #teacherId = the_data['teacherId']
    firstName = the_data['firstName']
    lastName = the_data['lastName']
    email = the_data['email']
    phoneNumber = the_data['phoneNumber']

    query = 'INSERT INTO teacher (firstName, lastName, email, phoneNumber) VALUES (%s, %s, %s, %s)' 
    #current_app.logger.info(query)
    data = (firstName, lastName, email, phoneNumber)
    cursor = db.get_db().cursor()
    r = cursor.execute(query, data)
    db.get_db().commit()
    return 'teacher added'

# teachers delete route
@teachers.route('/teacher/', methods=['DELETE'])
def delete_teacher():

    teacher_info = request.json
    teacher_id = teacher_info['teacherId']

    query = f'DELETE FROM teacher WHERE teacherId = "{teacher_id}";'
    current_app.logger.info(f'Query = {query}')

    cursor = db.get_db().cursor()
    cursor.execute(query)
    db.get_db().commit()
    return 'Success!'

# # collecting data from the request object
#     student_info = request.json
#     student_email = student_info['email']
#     query = f'DELETE FROM students WHERE email = "{student_email}";'
#     current_app.logger.info(f'Query = {query}')
#     cursor = db.get_db().cursor()
#     cursor.execute(query)
#     db.get_db().commit()
#     return 'Success!'



