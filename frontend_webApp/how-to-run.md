# Freela Marketplace — How to Run Locally

## Prerequisites

- Python **3.10+** installed on your machine  
- `pip` available (comes with Python)

---

## 1. Extract the project

Extract project to local directory and enter its folder

---

## 2. Create a virtual environment

```bash
python -m venv venv
```

Activate it:

| Platform | Command |
|---|---|
| **Windows (cmd)** | `venv\Scripts\activate` |
| **Windows (PowerShell)** | `venv\Scripts\Activate.ps1` |
| **macOS / Linux** | `source venv/bin/activate` |

---

## 3. Install dependencies

```bash
pip install -r requirements.txt
```

---

## 4. Configure environment variables

Edit .env file if needed


> For local development the defaults work fine. In production, set a strong `SECRET_KEY`.

---

## 5. Run the application

### Development mode

```bash
python run.py
```

Open your browser at: **http://localhost:5000**

### Production mode (Gunicorn — Linux / macOS)

```bash
gunicorn "app:create_app()" -w 4 -b 0.0.0.0:5000
```

> Windows users should use a WSL2 environment or a container for Gunicorn.

---

## Project structure

```
freela_marketplace/
├── run.py                  # Entry point
├── requirements.txt
├── .env.example
├── config/
│   ├── __init__.py
│   └── settings.py         # Dev / Prod / Test configs
└── app/
    ├── __init__.py          # App factory (create_app)
    ├── blueprints/
    │   ├── main.py          # "/" → All Services
    │   ├── services.py      # /service/my
    │   └── bookings.py      # /booking/my
    ├── data/
    │   └── services.py      # Static fake data
    ├── static/
    │   ├── css/main.css
    │   └── js/main.js
    └── templates/
        ├── base.html
        └── pages/
            ├── all_services.html
            ├── my_services.html
            └── my_bookings.html
```

---

## Pages

| URL | Tab |
|---|---|
| `/` | All Services (home) |
| `/service/my` | My Services |
| `/booking/my` | My Bookings |

---

## Notes

- The **Login** button is present in the header but does not implement authentication yet.
- **My Services** and **My Bookings** show an "Under Development" placeholder.
- The services table displays 5 rows of static fake data defined in `app/data/service.py`.
