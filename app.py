import os
from flask import Flask, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_smorest import Api
from dotenv import load_dotenv
from schemas import EmployeeSchema, EmployeeUpdateSchema
from models import EmployeeModel
from sqlalchemy.exc import SQLAlchemyError
from flask_smorest import abort

# Initialize SQLAlchemy
db = SQLAlchemy()

def create_app():
    app = Flask(__name__)

    # Add API title, version, and OpenAPI version configurations
    app.config["API_TITLE"] = "Employee Management API"
    app.config["API_VERSION"] = "v1"
    app.config["OPENAPI_VERSION"] = "3.0.0"

    # Load environment variables from .env file
    load_dotenv()

    # MySQL connection string from .env
    mysql_host = os.environ.get('MYSQL_HOST', 'localhost')
    mysql_user = os.environ.get('MYSQL_USER', 'root')
    mysql_password = os.environ.get('MYSQL_PASSWORD', 'rootpassword')
    mysql_db = os.environ.get('MYSQL_DB', 'employees_db')

    # Set up SQLAlchemy URI
    app.config["SQLALCHEMY_DATABASE_URI"] = f"mysql+pymysql://{mysql_user}:{mysql_password}@{mysql_host}:3306/{mysql_db}"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["PROPAGATE_EXCEPTIONS"] = True

    # Initialize db and migration
    db.init_app(app)
    migrate = Migrate(app, db)

    # Initialize API with Flask-Smorest
    api = Api(app)

    # Import resources after db initialization to avoid circular import
    from resources.employee import blp as employee_blp

    # Register the blueprints (change to '/api' prefix for API routes)
    api.register_blueprint(employee_blp, url_prefix='/api')

    # Health check endpoint
    @app.route("/health", methods=["GET"])
    def health_check():
        try:
            # Test database connection
            with app.app_context():
                db.session.execute('SELECT 1')
            return "OK", 200
        except Exception as e:
            return f"Error: {str(e)}", 500

    # Root route (home page) to avoid 404 error
    @app.route("/", methods=["GET"])
    def home():
        return render_template("home.html", version=app.config["API_VERSION"])

    # New route to display the employee list (render as HTML)
    @app.route("/employee", methods=["GET"])
    def list_employees():
        # Query all employees from the EmployeeModel
        employees = EmployeeModel.query.all()

        # Pass the employees data to the template
        return render_template("employees.html", employees=employees)

    return app
