#!/bin/bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
