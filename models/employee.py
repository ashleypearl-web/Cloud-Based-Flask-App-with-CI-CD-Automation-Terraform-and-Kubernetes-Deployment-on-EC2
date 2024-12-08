from datetime import datetime
from db import db  # Ensure db is correctly imported from your app's SQLAlchemy instance

class EmployeeModel(db.Model):
    __tablename__ = 'employees'  # Pluralized name to follow convention

    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.String(80), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    role = db.Column(db.String(50), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)

    # Adding timestamp fields for better tracking
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<Employee {self.name} ({self.employee_id})>"

    # Add a method for easier initialization (optional but can be useful)
    @classmethod
    def create(cls, employee_id, name, role, email):
        new_employee = cls(employee_id=employee_id, name=name, role=role, email=email)
        db.session.add(new_employee)
        db.session.commit()
        return new_employee

    # Optional: Method to update employee details
    def update(self, name=None, role=None, email=None):
        if name:
            self.name = name
        if role:
            self.role = role
        if email:
            self.email = email
        db.session.commit()

    # Optional: Method to delete employee
    def delete(self):
        db.session.delete(self)
        db.session.commit()
