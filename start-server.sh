#!/bin/bash
# Start development server - kills any existing server on port 3000/3001 first

echo "Checking for existing dev servers..."

# Kill any process on port 3000 or 3001
lsof -ti :3000 2>/dev/null && echo "Killing server on port 3000" && kill -9 $(lsof -ti :3000) 2>/dev/null
lsof -ti :3001 2>/dev/null && echo "Killing server on port 3001" && kill -9 $(lsof -ti :3001) 2>/dev/null

sleep 1

echo "Starting development server..."
npm run dev