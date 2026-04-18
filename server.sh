#!/bin/bash

# Move to the directory where this script is located
cd "$(dirname "$0")"

# Go into the backend folder
cd backend

# Activate the virtual environment
source venv/bin/activate

# Run Uvicorn - pointing directly to the app
echo "🚀 Starting FastAPI from: $(pwd)"
uvicorn main:app --reload