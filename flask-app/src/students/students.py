from flask import Blueprint, request, jsonify, make_response, current_app
import json
from src import db

students = Blueprint('students', __name__)

@students.route('/students', methods=['GET'])
def get_students():
    cursor = db.get_db().cursor()
    cursor.execute('SELECT email, firstName, lastName, classroomId FROM students')
    row_headers = [x[0] for x in cursor.description]
    json_data = []
    theData = cursor.fetchall()
    for row in theData:
        json_data.append(dict(zip(row_headers, row)))
    the_response = make_response(jsonify(json_data))
    the_response.status_code = 200
    the_response.mimetype = 'application/json'
    return the_response


@students.route('/studentsEmails', methods=['GET'])
def get_students_emails():
    cursor = db.get_db().cursor()
    cursor.execute('SELECT email FROM students')
    row_headers = [x[0] for x in cursor.description]
    json_data = []
    theData = cursor.fetchall()
    for row in theData:
        json_data.append(dict(zip(row_headers, row)))
    the_response = make_response(jsonify(json_data))
    the_response.status_code = 200
    the_response.mimetype = 'application/json'
    return the_response


@students.route('/students', methods=['PUT'])
def edit_students():
    student_info = request.json
    #current_app.logger.info(student_info)
    st_email = student_info['email']
    first = student_info['firstName']
    last = student_info['lastName']
    st_classroomId = student_info['classroomId']
    
    query = 'UPDATE students SET firstName = %s, lastName = %s, classroomId = %s WHERE email = %s'
    data = (first, last, st_classroomId, st_email)
    cursor = db.get_db().cursor()
    r = cursor.execute(query, data)
    db.get_db().commit()
    return 'students updated!'


@students.route('/students', methods=['POST'])
def add_student():
    student_info = request.json
    current_app.logger.info(student_info)

    st_email = student_info['email']
    first = student_info['firstName']
    last = student_info['lastName']
    st_classroomId = student_info['classroomId']
    
    query = 'INSERT INTO students (email, firstName, lastName, classroomId) VALUES (%s, %s, %s, %s)' 
    current_app.logger.info(query)
    data = (st_email, first, last, st_classroomId)
    cursor = db.get_db().cursor()
    r = cursor.execute(query, data)
    db.get_db().commit()
    return 'student added'

@students.route('/students', methods=['DELETE'])
def remove_student():
    # collecting data from the request object
    student_info = request.json
    student_email = student_info['email']
    query = f'DELETE FROM students WHERE email = "{student_email}";'
    current_app.logger.info(f'Query = {query}')
    cursor = db.get_db().cursor()
    cursor.execute(query)
    db.get_db().commit()
    return 'Success!'
