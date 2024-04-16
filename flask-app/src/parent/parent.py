from flask import Blueprint, request, jsonify, make_response, current_app
import json
from src import db

parent = Blueprint('parent', __name__)

@parent.route('/parents', methods=['GET'])
def get_parents():
    cursor = db.get_db().cursor()
    cursor.execute('SELECT email, firstName, lastName, studentEmail FROM parent')
    row_headers = [x[0] for x in cursor.description]
    json_data = []
    theData = cursor.fetchall()
    for row in theData:
        json_data.append(dict(zip(row_headers, row)))
    the_response = make_response(jsonify(json_data))
    the_response.status_code = 200
    the_response.mimetype = 'application/json'
    return the_response


@parent.route('/parents', methods=['PUT'])
def edit_parents():
    parent_info = request.json
    #current_app.logger.info(parent_info)
    p_email = parent_info['email']
    first = parent_info['firstName']
    last = parent_info['lastName']
    p_stEmail = parent_info['studentEmail']
    
    query = 'UPDATE parent SET firstName = %s, lastName = %s, studentEmail = %s WHERE email = %s'
    data = (first, last, p_stEmail, p_email)
    cursor = db.get_db().cursor()
    r = cursor.execute(query, data)
    db.get_db().commit()
    return 'parents updated!'


@parent.route('/parents', methods=['POST'])
def add_parent():
    parent_info = request.json
    current_app.logger.info(parent_info)
    
    p_email = parent_info['email']
    first = parent_info['firstName']
    last = parent_info['lastName']
    p_stEmail = parent_info['studentEmail']
    
    query = 'INSERT INTO parent (email, firstName, lastName, studentEmail) VALUES (%s, %s, %s, %s)' 
    current_app.logger.info(query)
    data = (p_email, first, last, p_stEmail)
    cursor = db.get_db().cursor()
    r = cursor.execute(query, data)
    db.get_db().commit()
    return 'parent added!'


@parent.route('/parents', methods=['DELETE'])
def parent_remove():
    # collecting data from the request object
    parent_info = request.json
    p_email = parent_info['email']
    query = f'DELETE FROM parent WHERE email = "{p_email}";'
    current_app.logger.info(f'Query = {query}')
    cursor = db.get_db().cursor()
    cursor.execute(query)
    db.get_db().commit()
    return 'parent removed!'

