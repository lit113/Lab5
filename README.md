
# Environment Setup Guide

This guide explains how to set up the environment for the project hosted on [GitHub - SMU-MSLC/tornado_bare (fastapi branch)](https://github.com/SMU-MSLC/tornado_bare/tree/fastapi).

## Requirements

- Anaconda Python 3.8
- MongoDB (Install Compass for a convenient GUI)

## Steps to Run the Python File

1. **Ensure MongoDB is Running**

   Before running the backend, ensure that the MongoDB database is up and running by executing:

   ```bash
   ps aux | grep mongod
   ```

2. **Navigate to Your Python File Directory**

   Place the Python file in a simpler path for easy navigation, then change to the directory:

   ```bash
   cd <your_file_path>
   ```

3. **Run the Backend with Uvicorn**

   Execute the following command to run the backend using Uvicorn:

   ```bash
   uvicorn fastapi_turicreate:app --host 0.0.0.0 --port 8000
   ```



