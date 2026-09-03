# Contributing to KrishiSetu 🌾

Thank you for your interest in contributing to **KrishiSetu**! This project was created for the **Smart India Hackathon 2026** (Problem Statement 26033) to bridge the gap between smallholder farmers, direct buyers, and smart agricultural logistics using AI demand forecasting and route optimization.

---

## Code of Conduct

All contributors are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md). Please be respectful and considerate in all communications.

---

## Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.24.0`
- **Python**: `>= 3.10` (compatible with 3.13)
- **Git**

### Repository Setup
1. **Fork & Clone**:
   ```bash
   git clone https://github.com/Raghib6289/krishisetu.git
   cd krishisetu
   ```

2. **Backend Setup**:
   ```bash
   python -m venv venv
   # On Windows:
   .\venv\Scripts\activate
   # On Linux/macOS:
   source venv/bin/activate

   pip install -r backend/requirements.txt
   python run_backend.py
   ```
   *The backend API will start at `http://127.0.0.1:8000` with interactive docs at `/docs`.*

3. **Flutter App Setup**:
   ```bash
   cd krishisetu
   flutter pub get
   flutter run -d chrome
   ```

---

## Development Guidelines

### Architecture
- **Mobile (`/krishisetu`)**:
  - `lib/core`: Global networking, themes, and `go_router` routing.
  - `lib/features/auth`: Mobile OTP verification, JWT session management.
  - `lib/features/farmer`: Produce inventory management & `fl_chart` AI forecasting.
  - `lib/features/buyer`: Produce catalog, Razorpay checkout, live shipment tracking.
  - `lib/features/driver`: Pickup task dashboard, OR-Tools routing, WebSocket GPS streaming.
- **Backend (`/backend`)**:
  - `main.py`: FastAPI server entry point.
  - `database.py`: Thread-safe SQLite persistence layer (`krishisetu.db`).
  - `security.py`: Salted SHA-256 password hashing & HMAC-SHA256 JWT tokens.
  - `services/forecaster.py`: ARIMA agricultural price forecasting.
  - `services/route_optimizer.py`: Google OR-Tools / 2-Opt Vehicle Routing solver.
  - `services/tracking_ws.py`: Real-time WebSocket hub for driver telemetry.

### Submitting Pull Requests
1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Run code validation:
   ```bash
   # Dart checks
   cd krishisetu
   dart analyze lib

   # Python checks
   cd ..
   python -m backend.test_backend
   ```
3. Commit with descriptive messages:
   ```bash
   git commit -m "feat(farmer): add photo compression before crop upload"
   ```
4. Push to your fork and open a Pull Request against the `main` branch.
