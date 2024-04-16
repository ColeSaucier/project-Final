# Some set up for the application 

from flask import Flask
from flaskext.mysql import MySQL

# create a MySQL object that we will use in other parts of the API
db = MySQL()

def create_app():
    app = Flask(__name__)
    
    # secret key that will be used for securely signing the session 
    # cookie and can be used for any other security related needs by 
    # extensions or your application
    app.config['SECRET_KEY'] = 'someCrazyS3cR3T!Key.!'

    # these are for the DB object to be able to connect to MySQL. 
    app.config['MYSQL_DATABASE_USER'] = 'root'
    app.config['MYSQL_DATABASE_PASSWORD'] = open('/secrets/db_root_password.txt').readline().strip()
    app.config['MYSQL_DATABASE_HOST'] = 'db'
    app.config['MYSQL_DATABASE_PORT'] = 3306
    app.config['MYSQL_DATABASE_DB'] = 'math_learning_db'  # Change this to your DB name

    # Initialize the database object with the settings above. 
    db.init_app(app)
    
    # Add the default route
    # Can be accessed from a web browser
    # http://ip_address:port/
    # Example: localhost:8001
    @app.route("/")
    def welcome():
        return "<h1>Welcome to the 3200 boilerplate app</h1>"

    # Import the various Beluprint Objects
    from src.questions.questions import questions
    from src.assigned_questions.assigned_questions import assigned_questions
    from src.classroom.classroom import classroom
    from src.activity.activity import activity
    from src.studentProgress.students import studentProgress
    from src.students.students import students
    from src.parent.parent import parent
    from src.adminVerification.adminVerification import adminVerification
    from src.teachers.teachers import teachers

    # Register the routes from each Blueprint with the app object
    # and give a url prefix to each
    app.register_blueprint(questions,   url_prefix='/q')
    app.register_blueprint(assigned_questions, url_prefix='/a')
    app.register_blueprint(classroom, url_prefix='/c')
    app.register_blueprint(activity, url_prefix='/a')
    app.register_blueprint(studentProgress, url_prefix='/s')
    app.register_blueprint(students, url_prefix='/st')
    app.register_blueprint(parent, url_prefix='/p')
    app.register_blueprint(adminVerification, url_prefix='/av')
    app.register_blueprint(teachers, url_prefix='/t')


    # Don't forget to return the app object
    return app