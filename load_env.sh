#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
    echo "Environment variables loaded successfully!"
else
    echo "Warning: .env file not found. Using default values."
fi

# Start Xcode with environment variables
echo "Starting Xcode with environment variables..."
open AuthProject.xcodeproj 