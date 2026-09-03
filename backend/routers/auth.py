import uuid
import time
import re
from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from fastapi import APIRouter, HTTPException, status
from backend.models import UserRegister, UserLogin, UserResponse, UserRole
from backend.database import get_connection
from backend.security import hash_password, verify_password, create_access_token

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

def normalize_phone(phone: str) -> str:
    """Extract last 10 digits of an Indian phone number."""
    digits = re.sub(r"\D", "", phone)
    if len(digits) >= 10:
        return digits[-10:]
    return digits

class SendOtpRequest(BaseModel):
    phone: str
    user_type: Optional[str] = "farmer"
    name: Optional[str] = None

class VerifyOtpRequest(BaseModel):
    phone: str
    otp: str
    user_type: Optional[str] = "farmer"
    name: Optional[str] = None

@router.post("/send-otp")
def send_otp(req: SendOtpRequest):
    phone_clean = normalize_phone(req.phone)
    if len(phone_clean) < 10:
        raise HTTPException(status_code=400, detail="Please enter a valid 10-digit mobile number")

    # Generate or use demo OTP
    otp = "123456"
    now = time.time()
    expires_at = now + 600 # 10 minutes

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """INSERT OR REPLACE INTO otps (phone, otp, user_type, name, created_at, expires_at)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (phone_clean, otp, req.user_type or "farmer", req.name or "", now, expires_at)
        )
        conn.commit()

    return {
        "status": "success",
        "message": f"OTP successfully sent to +91 {phone_clean}",
        "phone": phone_clean,
        "demo_otp": "123456"
    }

@router.post("/verify-otp", response_model=UserResponse)
def verify_otp(req: VerifyOtpRequest):
    phone_clean = normalize_phone(req.phone)
    if len(phone_clean) < 10:
        raise HTTPException(status_code=400, detail="Invalid mobile number format")

    with get_connection() as conn:
        cursor = conn.cursor()

        # Check OTP
        cursor.execute("SELECT * FROM otps WHERE phone = ?", (phone_clean,))
        otp_row = cursor.fetchone()

        # Allow 123456 as universal demo OTP or check database
        is_valid = False
        if req.otp.strip() == "123456":
            is_valid = True
        elif otp_row and otp_row["otp"] == req.otp.strip() and time.time() <= otp_row["expires_at"]:
            is_valid = True

        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired OTP. Please use demo OTP: 123456"
            )

        # Look up existing user by phone number
        cursor.execute(
            "SELECT * FROM users WHERE phone LIKE ? OR phone LIKE ?",
            (f"%{phone_clean}%", f"+91 {phone_clean[:5]} {phone_clean[5:]}")
        )
        user_row = cursor.fetchone()

        if user_row:
            # User exists
            user_id = user_row["id"]
            user_name = user_row["name"]
            email = user_row["email"]
            phone_fmt = user_row["phone"]
            role_str = user_row["user_type"]
            location = user_row["location"]
        else:
            # Auto-register new user verified by phone
            role_val = req.user_type if req.user_type in ["farmer", "buyer", "driver"] else "farmer"
            user_id = f"usr_{role_val}_{uuid.uuid4().hex[:6]}"
            default_name = req.name.strip() if req.name and req.name.strip() else f"Krishi {role_val.capitalize()} ({phone_clean[-4:]})"
            email = f"user_{phone_clean}@krishisetu.com"
            phone_fmt = f"+91 {phone_clean[:5]} {phone_clean[5:]}"
            location = "Nashik, Maharashtra"
            now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            pwd_hash, salt = hash_password("verified_phone_user")

            cursor.execute(
                """INSERT INTO users (id, name, email, password_hash, salt, phone, user_type, location, created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (user_id, default_name, email, pwd_hash, salt, phone_fmt, role_val, location, now_str)
            )
            conn.commit()

            user_name = default_name
            role_str = role_val

        # Clear used OTP
        cursor.execute("DELETE FROM otps WHERE phone = ?", (phone_clean,))
        conn.commit()

    token = create_access_token({"sub": user_id, "role": role_str, "phone": phone_clean})

    return UserResponse(
        id=user_id,
        name=user_name,
        email=email,
        phone=phone_fmt,
        user_type=UserRole(role_str),
        location=location,
        token=token
    )

@router.post("/register", response_model=UserResponse)
def register(user: UserRegister):
    email = user.email.lower().strip()
    phone_clean = normalize_phone(user.phone)
    
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="User with this email already exists")

        user_id = f"usr_{user.user_type.value}_{uuid.uuid4().hex[:6]}"
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        pwd_hash, salt = hash_password(user.password)
        loc = user.location or "Nashik, Maharashtra"

        cursor.execute(
            """INSERT INTO users (id, name, email, password_hash, salt, phone, user_type, location, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (user_id, user.name, email, pwd_hash, salt, user.phone, user.user_type.value, loc, now)
        )
        conn.commit()

    token = create_access_token({"sub": user_id, "role": user.user_type.value, "email": email})

    return UserResponse(
        id=user_id,
        name=user.name,
        email=email,
        phone=user.phone,
        user_type=user.user_type,
        location=loc,
        token=token
    )

@router.post("/login", response_model=UserResponse)
def login(credentials: UserLogin):
    email = credentials.email.lower().strip()
    
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
        row = cursor.fetchone()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password. Use farmer@krishisetu.com / pass123 or Mobile OTP for demo."
        )

    # Check password
    if not verify_password(credentials.password, row["password_hash"], row["salt"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password. Use farmer@krishisetu.com / pass123 or Mobile OTP for demo."
        )

    token = create_access_token({"sub": row["id"], "role": row["user_type"], "email": email})

    return UserResponse(
        id=row["id"],
        name=row["name"],
        email=row["email"],
        phone=row["phone"],
        user_type=UserRole(row["user_type"]),
        location=row["location"],
        token=token
    )
