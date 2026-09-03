import hashlib
import hmac
import base64
import json
import secrets
import time
from typing import Tuple, Dict, Any, Optional

SECRET_KEY = "krishisetu-sih2026-secure-jwt-secret-key-national-finals"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_SECONDS = 86400 * 7 # 7 days

def hash_password(password: str, salt: Optional[str] = None) -> Tuple[str, str]:
    """Generates a secure SHA-256 hash using a cryptographic salt."""
    if not salt:
        salt = secrets.token_hex(16)
    salted = f"{salt}:{password}".encode("utf-8")
    pwd_hash = hashlib.sha256(salted).hexdigest()
    return pwd_hash, salt

def verify_password(plain_password: str, password_hash: str, salt: str) -> bool:
    """Verifies a plain password against the stored salt and hash."""
    computed_hash, _ = hash_password(plain_password, salt)
    return hmac.compare_digest(computed_hash, password_hash)

def _base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")

def _base64url_decode(s: str) -> bytes:
    padding = '=' * (4 - (len(s) % 4)) if len(s) % 4 != 0 else ''
    return base64.urlsafe_b64decode((s + padding).encode("utf-8"))

def create_access_token(data: Dict[str, Any], expires_delta: Optional[int] = None) -> str:
    """Creates a signed HMAC-SHA256 JWT token with expiration and claims."""
    expire = int(time.time()) + (expires_delta or ACCESS_TOKEN_EXPIRE_SECONDS)
    payload = data.copy()
    payload["exp"] = expire

    header = {"alg": ALGORITHM, "typ": "JWT"}
    header_bytes = json.dumps(header, separators=(',', ':')).encode("utf-8")
    payload_bytes = json.dumps(payload, separators=(',', ':')).encode("utf-8")

    encoded_header = _base64url_encode(header_bytes)
    encoded_payload = _base64url_encode(payload_bytes)

    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    signature = hmac.new(SECRET_KEY.encode("utf-8"), signing_input, hashlib.sha256).digest()
    encoded_signature = _base64url_encode(signature)

    return f"{encoded_header}.{encoded_payload}.{encoded_signature}"

def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """Decodes and validates a JWT token signature and expiration."""
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        encoded_header, encoded_payload, encoded_signature = parts

        signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
        expected_sig = hmac.new(SECRET_KEY.encode("utf-8"), signing_input, hashlib.sha256).digest()

        actual_sig = _base64url_decode(encoded_signature)
        if not hmac.compare_digest(expected_sig, actual_sig):
            return None

        payload_bytes = _base64url_decode(encoded_payload)
        payload = json.loads(payload_bytes.decode("utf-8"))

        if payload.get("exp") and time.time() > payload["exp"]:
            return None

        return payload
    except Exception:
        return None
