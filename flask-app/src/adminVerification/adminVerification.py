from flask import Blueprint, request, jsonify, make_response, current_app
import json
from src import db

adminVerification = Blueprint('adminVerification', __name__)

@adminVerification.route('/check_admin/<adminid>', methods=['GET'])
def verify_admin_id(adminid):
    cursor = db.get_db().cursor()
    cursor.execute(f'SELECT COUNT(*) FROM siteAdmin WHERE adminid = {adminid}')
    result = cursor.fetchone()[0]

    if result >= 1:
        return jsonify({'id_exists': result}), 200
    else:
        return jsonify({'id_exists': result}), 400