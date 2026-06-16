# job-platform-frontend

![Job Bless Logo](images/logo-with-background-and-text.png)

The Flutter frontend app for JobBless, a job seeking platform built in 2026 for the Software Engineering course at CEID, University of Patras.

Το διάγραμμα κλάσεων (class diagram) του έργου βρίσκεται σε πλήρη ανάλυση στο αποθετήριο για το [ClassDiagramMaker](https://raw.githubusercontent.com/JobPlatformCEID/Job-platform-ClassDiagramMaker/refs/heads/main/diagram_edited.svg)

## Team Members

- **ΑΔΑΜΟΠΟΥΛΟΣ ΘΕΟΔΩΡΟΣ / vortex3964** - ΑΜ:1108389 - 6ο εξαμηνο
- **ΑΛΕΞΑΝΔΡΟΠΟΥΛΟΣ ΘΕΟΔΩΡΟΣ / teettt1** - ΑΜ: 1108347 - 6ο εξαμηνο
- **ΔΗΜΟΠΟΥΛΟΣ ΗΛΙΑΣ / LinkBoi00** - ΑΜ:1108376 - 6ο εξαμηνο
- **ΧΑΪΔΟΓΙΑΝΝΟΣ ΜΑΡΙΟΣ-ΔΗΜΗΤΡΙΟΣ / Dimitris34** - ΑΜ:1112101 - 6ο εξαμηνο
- **ΧΑΤΖΗΔΗΜΗΤΡΙΟΥ ΣΤΥΛΙΑΝΟΣ / Stelios-Chatzid** - ΑΜ:1112144 - 6ο εξαμηνο

## Technologies

- Flutter 3.11+, Dart
- LiveKit (video calls)
- WebSockets (real-time messaging and AI interviews)

## Features

- **Job Search & Applications**: Browse active postings, apply, and track application status
- **Employer Tools**: Create and manage job postings, review applicants, accept or reject applications
- **Candidate Profiles**: Skills, work experience, education, CV upload and download
- **CV Builder**: Build a professional CV from your profile with multiple templates, export as PDF
- **Mock AI Interviews**: AI-powered interview sessions tied to specific job postings
- **Real-time Messaging**: WebSocket-based chat between candidates and employers
- **Video Calls**: LiveKit-powered call rooms, schedulable via the in-app calendar
- **Social Feed**: Posts, comments, likes, and image uploads
- **Company Reviews**: Candidates can rate and review employers
- **Market Statistics**: Charts and CSV export of job market data
- **Responsive UI**: Sidebar layout on desktop, bottom navigation on mobile

## Supported Platforms

Android, Windows, and Linux. iOS and macOS are untested.

## Running the app

### Prerequisites

- Flutter SDK 3.11.4 or higher
- A running instance of the backend for JobBless

### Installation

1. Clone the repository:
```bash
git clone <repo-url>
cd job-platform-frontend
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

4. On first launch, tap the settings icon and enter your backend server URL (e.g. `http://192.168.1.10:8000`). Use the Test Connection button to verify before saving.


### Building for Production

**Android APK:**
```bash
flutter build apk --release
```

**Windows:**
```bash
flutter build windows --release
```

**Linux:**
```bash
flutter build linux --release
```
