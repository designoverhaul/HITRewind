# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the dependencies file to the working directory
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
# Also install gunicorn for running the Flask app
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# Copy the current directory contents into the container at /app
COPY simple_youtube_api.py .

# Make port 8080 available to the world outside this container
# Cloud Run will set the PORT environment variable, gunicorn will pick it up.
# Default for Cloud Run is 8080 if PORT is not set.
EXPOSE 8080

# Define environment variable for the port (though Cloud Run provides it)
ENV PORT 8080
ENV PYTHONUNBUFFERED TRUE

# Run simple_youtube_api.py when the container launches
# Use gunicorn as the WSGI server
# The [::]:$PORT binding makes it listen on all IPv4 and IPv6 interfaces.
# simple_youtube_api:app refers to the 'app' Flask object in your 'simple_youtube_api.py' file.
CMD exec gunicorn --bind [::]:${PORT} --workers 1 --threads 8 --timeout 0 simple_youtube_api:app 