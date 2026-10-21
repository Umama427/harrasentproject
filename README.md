# University Harassment Complaint System

## Backend (folder: backend)
1. cd backend, npm install
2. copy .env.example to .env and set JWT_SECRET (32+ chars)
3. npm run db:inspect, npm run db:init, npm run db:seed, npm run admin:create
4. npm start   (http://localhost:4000/api/health)

`npm run db:init` also removes an obsolete unique index on `complaints.referenceNumber` from older database setups. Complaint references are stored as `referenceNo`; run initialization once against an existing database before creating complaints.

## Frontend (folder: frontend)
1. cd frontend
2. flutter create . --platforms web      (one time, generates the web/ folder; keeps lib/ and pubspec.yaml)
3. flutter pub get
4. flutter run -d chrome
Different API address: flutter run -d chrome --dart-define=API_URL=https://your-server/api
