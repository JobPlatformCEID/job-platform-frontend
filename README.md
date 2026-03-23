# Job Platform — Flutter + Django REST API

A mobile job platform app built with Flutter (Android) and Django REST Framework, using PostgreSQL as the database and Docker for the backend.

---

## Project Structure

```
project/
├── backend/                        # Django project
│   ├── core/                       # Project config
│   │   ├── settings.py
│   │   ├── urls.py
│   │   ├── wsgi.py
│   │   └── asgi.py
│   ├── users/                      # Auth + profiles app
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   └── urls.py
│   ├── jobs/                       # Jobs app
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   └── urls.py
│   └── manage.py
│
└── frontend/                       # Flutter project
    └── lib/
        ├── main.dart
        ├── services/
        │   └── api_service.dart    # Central HTTP service
        └── screens/
            ├── auth_check.dart     # Token check on app open
            ├── login_screen.dart
            ├── reg_screen.dart
            ├── cand_setup.dart     # Candidate profile setup
            ├── emp_setup.dart      # Employer profile setup
            ├── candidate_home.dart
            └── employer_home.dart
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter (Android) |
| Backend | Django 6 + Django REST Framework |
| Authentication | DRF Token Authentication |
| Database | PostgreSQL (via Docker) |
| Secure Storage | flutter_secure_storage |
| HTTP Client | http (Dart package) |

---

## API Endpoints

### Auth (no token required)
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/register/` | Register a new user |
| POST | `/api/auth/login/` | Login and receive token + role |

### Candidates (token required)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/candidates/me/` | Get candidate profile |
| PUT | `/api/candidates/me/` | Update candidate profile |

### Employers (token required)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/employers/me/` | Get employer profile |
| PUT | `/api/employers/me/` | Update employer profile |

### Jobs (token required)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/jobs/` | List all active job postings |
| POST | `/api/jobs/` | Create a job posting (employer only) |
| GET | `/api/jobs/<id>/` | Get job posting details |
| PUT | `/api/jobs/<id>/` | Update a job posting (employer only) |
| DELETE | `/api/jobs/<id>/` | Delete a job posting (employer only) |
| POST | `/api/jobs/<id>/apply/` | Apply for a job (candidate only) |
| GET | `/api/jobs/applications/` | List applications (employer only) |
| PATCH | `/api/jobs/applications/<id>/status/` | Accept/reject an application |

---

## Data Models

### User
- `username`, `password` (from AbstractUser)
- `role` — `"candidate"` or `"employer"`

### CandidateProfile (auto-created on register)
- `phone`, `location`, `bio`, `cv`, `score`
- Related: `WorkExperience`, `Education`, `Skill`

### EmployerProfile (auto-created on register)
- `company_name`, `description`, `location`, `website`

### WorkExperience
- `title`, `company`, `start_date`, `end_date`, `description`

### Education
- `institution`, `degree`, `level`, `graduation_date`
- Levels: `high_school`, `bachelor`, `master`, `phd`

### Skill
- `name`

---

## Request / Response Reference

### Register
```json
// POST /api/auth/register/
// Request
{ "username": "john", "password": "pass123", "role": "candidate" }

// Response 201
{ "id": 1, "username": "john", "role": "candidate" }
```

### Login
```json
// POST /api/auth/login/
// Request
{ "username": "john", "password": "pass123" }

// Response 200
{ "token": "abc123...", "role": "candidate" }
```

### Update Candidate Profile
```json
// PUT /api/candidates/me/
// Headers: Authorization: Token abc123...
{ "phone": "6912345678", "location": "Athens", "bio": "Flutter developer" }
```

### Update Employer Profile
```json
// PUT /api/employers/me/
// Headers: Authorization: Token abc123...
{ "company_name": "Acme SA", "description": "...", "location": "Athens", "website": "https://acme.gr" }
```

---

## App Flow

```
App opens
    ↓
AuthCheckScreen
    ↓                    ↓
Token found          No token
    ↓                    ↓
role check          LoginScreen
    ↓         ↓              ↓
employer  candidate      RegisterScreen
    ↓         ↓              ↓
Employer  Candidate     role check
  Home      Home            ↓            ↓
                      emp_setup    cand_setup
                            ↓            ↓
                       Employer    Candidate
                         Home        Home
```

---

## Running the Project

### Backend (Django + Docker)
```bash
# Start containers
docker compose up

# Run migrations (first time)
docker exec -it <django_container> python manage.py migrate

# Create superuser (optional, for admin panel)
docker exec -it <django_container> python manage.py createsuperuser
```

### Frontend (Flutter)
```bash
# Install dependencies
flutter pub get

# Run on Android emulator
flutter run
```

> **Note:** The Android emulator reaches the host machine at `10.0.2.2`.
> The base URL in `api_service.dart` is set to `http://10.0.2.2:8000`.

### AndroidManifest.xml requirement
The following must be set in `android/app/src/main/AndroidManifest.xml`
to allow plain HTTP traffic to the local dev server:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application android:usesCleartextTraffic="true" ...>
```

---

## Checking Users in Docker

```bash
# Option 1 — Django shell
docker exec -it <django_container> python manage.py shell
>>> from users.models import User
>>> User.objects.all().values('username', 'role')

# Option 2 — Direct SQL
docker exec -it <postgres_container> psql -U jobplatform -d jobplatform
=# SELECT username, role, date_joined FROM users_user;

# Option 3 — Django Admin UI
# http://localhost:8000/admin
```

---

## Django Settings — Key Configuration

```python
AUTH_USER_MODEL = "users.User"          # Custom user model with role field

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ],
}

INSTALLED_APPS = [
    ...
    'rest_framework',
    'rest_framework.authtoken',
    'users.apps.UsersConfig',
    'jobs.apps.JobsConfig',
]
```

---

## Flutter Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  flutter_secure_storage: ^9.0.0
```

---

## TODO / Next Steps

- [ ] Add WorkExperience / Education / Skill endpoints in Django
- [ ] Build Jobs list UI for candidates
- [ ] Build job posting creation UI for employers
- [ ] Build applications management UI for employers
- [ ] Add CV upload support
- [ ] Add candidate scoring logic
- [ ] Production deployment (HTTPS, real domain, remove `usesCleartextTraffic`)
