from pydantic import BaseModel, EmailStr, Field


# ============================================================
# REGISTER
# ============================================================

class RegisterRequest(BaseModel):
    full_name: str = Field(
        min_length=2,
        max_length=100,
    )

    email: EmailStr

    mobile: str = Field(
        min_length=10,
        max_length=20,
    )

    password: str = Field(
        min_length=8,
        max_length=128,
    )


class RegisterResponse(BaseModel):
    message: str
    user_id: int
    email: EmailStr
    full_name: str
    is_verified: bool
    development_otp: str | None = None


# ============================================================
# REGISTRATION OTP
# ============================================================

class VerifyOTPRequest(BaseModel):
    identifier: str = Field(
        min_length=1,
        max_length=255,
    )

    otp: str = Field(
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
    )


class VerifyOTPResponse(BaseModel):
    message: str
    user_id: int
    email: EmailStr
    full_name: str
    is_verified: bool


# ============================================================
# RESEND VERIFICATION OTP
# ============================================================

class ResendVerificationOTPRequest(BaseModel):
    identifier: str = Field(
        min_length=1,
        max_length=255,
    )


class ResendVerificationOTPResponse(BaseModel):
    message: str
    development_otp: str | None = None


# ============================================================
# LOGIN
# ============================================================

class LoginRequest(BaseModel):
    identifier: str = Field(
        min_length=1,
        max_length=255,
    )

    password: str = Field(
        min_length=8,
        max_length=128,
    )


class LoginResponse(BaseModel):
    message: str
    user_id: int
    email: EmailStr
    full_name: str
    is_verified: bool


# ============================================================
# FORGOT PASSWORD
# ============================================================

class ForgotPasswordRequest(BaseModel):
    identifier: str = Field(
        min_length=1,
        max_length=255,
    )


class ForgotPasswordResponse(BaseModel):
    message: str
    development_otp: str | None = None


# ============================================================
# RESET PASSWORD
# ============================================================

class ResetPasswordRequest(BaseModel):
    identifier: str = Field(
        min_length=1,
        max_length=255,
    )

    otp: str = Field(
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
    )

    new_password: str = Field(
        min_length=8,
        max_length=128,
    )


class ResetPasswordResponse(BaseModel):
    message: str


# ============================================================
# LOGIN VIA OTP
# ============================================================

class SendLoginOTPRequest(BaseModel):
    mobile: str = Field(
        min_length=10,
        max_length=20,
    )


class SendLoginOTPResponse(BaseModel):
    message: str
    mobile: str
    development_otp: str | None = None


class LoginWithOTPRequest(BaseModel):
    mobile: str = Field(
        min_length=10,
        max_length=20,
    )
    otp: str = Field(
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
    )


class VerifyPhoneSessionRequest(BaseModel):
    mobile: str = Field(
        min_length=10,
        max_length=20,
    )
    is_login: bool = False