#!/bin/bash

# Move to the directory where this script is located
cd "$(dirname "$0")"

# Go into the backend folder
cd backend

# Activate the virtual environment
source venv/bin/activate

# Run Uvicorn from the backend folder
echo "🚀 Starting FastAPI from: $(pwd)"

# Use the module path (app.main) instead of entering the folder
python -m uvicorn app.main:app --reload