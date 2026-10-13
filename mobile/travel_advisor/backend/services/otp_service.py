import secrets
from datetime import datetime, timedelta

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from models.otp import OTPVerification
from models.user import User


password_hash = PasswordHash.recommended()

OTP_LENGTH = 6
OTP_EXPIRY_MINUTES = 5
MAX_OTP_ATTEMPTS = 5

REGISTRATION_PURPOSE = "registration"
PASSWORD_RESET_PURPOSE = "password_reset"
LOGIN_PURPOSE = "login"


# ============================================================
# OTP GENERATION
# ============================================================

def generate_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


# ============================================================
# CREATE OTP
# ============================================================

def create_otp(
    db: Session,
    user: User,
    purpose: str = REGISTRATION_PURPOSE,
) -> str:

    # Invalidate any previous unused OTP
    # for the same user and purpose.
    db.query(OTPVerification).filter(
        OTPVerification.user_id == user.id,
        OTPVerification.purpose == purpose,
        OTPVerification.is_used.is_(False),
    ).update(
        {
            OTPVerification.is_used: True,
        },
        synchronize_session=False,
    )

    otp = generate_otp()

    otp_record = OTPVerification(
        user_id=user.id,
        otp_hash=password_hash.hash(otp),
        purpose=purpose,
        expires_at=(
            datetime.utcnow()
            + timedelta(minutes=OTP_EXPIRY_MINUTES)
        ),
        is_used=False,
        attempts=0,
    )

    db.add(otp_record)
    db.commit()
    db.refresh(otp_record)

    return otp


# ============================================================
# VERIFY OTP
# ============================================================

def verify_otp(
    db: Session,
    user: User,
    otp: str,
    purpose: str = REGISTRATION_PURPOSE,
) -> tuple[bool, str]:

    otp_record = (
        db.query(OTPVerification)
        .filter(
            OTPVerification.user_id == user.id,
            OTPVerification.purpose == purpose,
            OTPVerification.is_used.is_(False),
        )
        .order_by(
            OTPVerification.created_at.desc()
        )
        .first()
    )

    # --------------------------------------------------------
    # No active OTP
    # --------------------------------------------------------

    if otp_record is None:
        return False, "No active OTP found."

    # --------------------------------------------------------
    # OTP expired
    # --------------------------------------------------------

    if datetime.utcnow() > otp_record.expires_at:
        otp_record.is_used = True
        db.commit()

        return False, "OTP has expired."

    # --------------------------------------------------------
    # Maximum attempts
    # --------------------------------------------------------

    if otp_record.attempts >= MAX_OTP_ATTEMPTS:
        otp_record.is_used = True
        db.commit()

        return False, "Maximum OTP attempts exceeded."

    # --------------------------------------------------------
    # Count this attempt
    # --------------------------------------------------------

    otp_record.attempts += 1

    # --------------------------------------------------------
    # Verify OTP
    # --------------------------------------------------------

    if not password_hash.verify(
        otp,
        otp_record.otp_hash,
    ):
        db.commit()

        return False, "Invalid OTP."

    # --------------------------------------------------------
    # OTP successfully verified
    # --------------------------------------------------------

    otp_record.is_used = True

    db.commit()

    return True, "OTP verified successfully."