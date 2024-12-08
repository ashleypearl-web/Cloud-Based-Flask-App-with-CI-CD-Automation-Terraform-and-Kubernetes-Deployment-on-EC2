FROM python:3.10

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container
COPY requirements.txt .

# Install the required Python packages
RUN pip install --no-cache-dir --upgrade -r requirements.txt
# You only need one MySQL connector, not both. Using pymysql is sufficient for Flask-SQLAlchemy.
RUN pip install pymysql

# Copy the rest of the application code into the container
COPY . .

# Expose the port that Flask will run on
EXPOSE 5000

# Set the default command to run your application
CMD ["flask", "run", "--host", "0.0.0.0"]