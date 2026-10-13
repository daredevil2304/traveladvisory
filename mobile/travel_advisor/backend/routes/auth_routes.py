from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db

from schemas.auth import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    RegisterResponse,
    ResetPasswordRequest,
    ResetPasswordResponse,
    ResendVerificationOTPRequest,
    ResendVerificationOTPResponse,
    VerifyOTPRequest,
    VerifyOTPResponse,
)

from services.auth_service import (
    authenticate_user,
    create_user,
    get_user_by_email,
    get_user_by_identifier,
    get_user_by_mobile,
    update_password,
)

from services.otp_service import (
    PASSWORD_RESET_PURPOSE,
    REGISTRATION_PURPOSE,
    create_otp,
    verify_otp,
)


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


# ============================================================
# REGISTER
# ============================================================

@router.post(
    "/register",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    request: RegisterRequest,
    db: Session = Depends(get_db),
):
    existing_email = get_user_by_email(
        db=db,
        email=request.email,
    )

    if existing_email is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists.",
        )

    existing_mobile = get_user_by_mobile(
        db=db,
        mobile=request.mobile,
    )

    if existing_mobile is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this mobile number already exists.",
        )

    user = create_user(
        db=db,
        full_name=request.full_name,
        email=request.email,
        mobile=request.mobile,
        password=request.password,
    )

    otp = create_otp(
        db=db,
        user=user,
        purpose=REGISTRATION_PURPOSE,
    )

    print()
    print("=" * 50)
    print("DEVELOPMENT OTP")
    print(f"Email: {user.email}")
    print(f"OTP: {otp}")
    print("=" * 50)
    print()

    return RegisterResponse(
        message=(
            "Account created successfully. "
            "OTP verification is required."
        ),
        user_id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_verified=user.is_verified,
        development_otp=otp,
    )


# ============================================================
# VERIFY REGISTRATION OTP
# ============================================================

@router.post(
    "/verify-otp",
    response_model=VerifyOTPResponse,
)
def verify_registration_otp(
    request: VerifyOTPRequest,
    db: Session = Depends(get_db),
):
    user = get_user_by_identifier(
        db=db,
        identifier=request.identifier,
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found.",
        )

    if user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is already verified.",
        )

    verified, message = verify_otp(
        db=db,
        user=user,
        otp=request.otp,
        purpose=REGISTRATION_PURPOSE,
    )

    if not verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        )

    user.is_verified = True
    db.commit()
    db.refresh(user)

    return VerifyOTPResponse(
        message="Account verified successfully.",
        user_id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_verified=user.is_verified,
    )


# ============================================================
# RESEND VERIFICATION OTP
# ============================================================

@router.post(
    "/resend-verification-otp",
    response_model=ResendVerificationOTPResponse,
)
def resend_verification_otp(
    request: ResendVerificationOTPRequest,
    db: Session = Depends(get_db),
):
    user = get_user_by_identifier(
        db=db,
        identifier=request.identifier,
    )

    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found.",
        )

    if user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is already verified.",
        )

    otp = create_otp(
        db=db,
        user=user,
        purpose=REGISTRATION_PURPOSE,
    )

    print()
    print("=" * 50)
    print("VERIFICATION OTP")
    print(f"Email: {user.email}")
    print(f"OTP: {otp}")
    print("=" * 50)
    print()

    return ResendVerificationOTPResponse(
        message="A new verification OTP has been generated.",
        development_otp=otp,
    )


# ============================================================
# LOGIN
# ============================================================

@router.post(
    "/login",
    response_model=LoginResponse,
)
def login(
    request: LoginRequest,
    db: Session = Depends(get_db),
):
    user = authenticate_user(
        db=db,
        identifier=request.identifier,
        password=request.password,
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email/mobile or password.",
        )

    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is not verified.",
        )

    return LoginResponse(
        message="Login successful.",
        user_id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_verified=user.is_verified,
    )


# ============================================================
# FORGOT PASSWORD
# ============================================================

@router.post(
    "/forgot-password",
    response_model=ForgotPasswordResponse,
)
def forgot_password(
    request: ForgotPasswordRequest,
    db: Session = Depends(get_db),
):
    user = get_user_by_identifier(
        db=db,
        identifier=request.identifier,
    )

    if user is None or not user.is_active:
        return ForgotPasswordResponse(
            message=(
                "If an account exists for this "
                "identifier, a password reset OTP "
                "has been generated."
            ),
            development_otp=None,
        )

    otp = create_otp(
        db=db,
        user=user,
        purpose=PASSWORD_RESET_PURPOSE,
    )

    print()
    print("=" * 50)
    print("PASSWORD RESET DEVELOPMENT OTP")
    print(f"Email: {user.email}")
    print(f"OTP: {otp}")
    print("=" * 50)
    print()

    return ForgotPasswordResponse(
        message=(
            "If an account exists for this "
            "identifier, a password reset OTP "
            "has been generated."
        ),
        development_otp=otp,
    )


# ============================================================
# RESET PASSWORD
# ============================================================

@router.post(
    "/reset-password",
    response_model=ResetPasswordResponse,
)
def reset_password(
    request: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    user = get_user_by_identifier(
        db=db,
        identifier=request.identifier,
    )

    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid password reset request.",
        )

    verified, message = verify_otp(
        db=db,
        user=user,
        otp=request.otp,
        purpose=PASSWORD_RESET_PURPOSE,
    )

    if not verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        )

    update_password(
        db=db,
        user=user,
        new_password=request.new_password,
    )

    return ResetPasswordResponse(
        message="Password reset successfully.",
    )