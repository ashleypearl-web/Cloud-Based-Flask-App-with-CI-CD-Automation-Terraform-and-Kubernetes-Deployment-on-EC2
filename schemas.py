from marshmallow import Schema, fields

class EmployeeSchema(Schema):
    id = fields.Int(dump_only=True)
    employee_id = fields.Str(required=True)
    name = fields.Str(required=True)
    role = fields.Str(required=True)
    email = fields.Str(required=True)

class EmployeeUpdateSchema(Schema):
    employee_id = fields.Str()
    name = fields.Str()
    role = fields.Str()
    email = fields.Str()
