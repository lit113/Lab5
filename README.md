
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

4. **Find Your Local IP Address on Mac or Linux**

   On Mac or Linux, open Terminal and type:

   ```bash
   ifconfig
   ```

   In the results, find the network interface you are connected to (typically `en0` or `wlan0`), and look for something like `inet 192.168.x.x`. The `192.168.x.x` part is your local network IP address. Ensure all backend ports are using your own IP address to enable proper interaction between the frontend and backend.




