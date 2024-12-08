from flask.views import MethodView
from flask_smorest import Blueprint, abort
from sqlalchemy.exc import SQLAlchemyError

from db import db
from models.employee import EmployeeModel  # Import EmployeeModel
from schemas import EmployeeSchema, EmployeeUpdateSchema  # Import Employee schemas

blp = Blueprint("Employees", __name__, description="Operations on employees")


@blp.route("/employee/<string:employee_id>")
class Employee(MethodView):
    @blp.response(200, EmployeeSchema)
    def get(self, employee_id):
        # Fetch employee by employee_id
        employee = EmployeeModel.query.get_or_404(employee_id)
        return employee

    def delete(self, employee_id):
        # Delete employee by employee_id
        employee = EmployeeModel.query.get_or_404(employee_id)
        db.session.delete(employee)
        db.session.commit()
        return {"message": "Employee deleted."}, 200

    @blp.arguments(EmployeeUpdateSchema)
    @blp.response(200, EmployeeSchema)
    def put(self, employee_data, employee_id):
        # Fetch employee by employee_id
        employee = EmployeeModel.query.get(employee_id)

        if employee:
            # Update employee fields based on the request
            for key, value in employee_data.items():
                setattr(employee, key, value)
        else:
            # If employee does not exist, create a new one with the given data
            employee = EmployeeModel(id=employee_id, **employee_data)

        try:
            # Save changes to the database
            db.session.add(employee)
            db.session.commit()
        except SQLAlchemyError:
            db.session.rollback()  # Rollback in case of error
            abort(500, message="An error occurred while updating the employee.")

        return employee


@blp.route("/employee")
class EmployeeList(MethodView):
    @blp.response(200, EmployeeSchema(many=True))
    def get(self):
        # Fetch all employees
        return EmployeeModel.query.all()

    @blp.arguments(EmployeeSchema)
    @blp.response(201, EmployeeSchema)
    def post(self, employee_data):
        # Check if the employee already exists based on employee_id or email
        existing_employee = EmployeeModel.query.filter(
            (EmployeeModel.employee_id == employee_data["employee_id"]) | 
            (EmployeeModel.email == employee_data["email"])
        ).first()

        if existing_employee:
            abort(400, message="An employee with that ID or email already exists.")

        # Add new employee
        employee = EmployeeModel(**employee_data)

        try:
            db.session.add(employee)
            db.session.commit()
        except SQLAlchemyError:
            db.session.rollback()  # Rollback in case of error
            abort(500, message="An error occurred while inserting the employee.")

        return employee
