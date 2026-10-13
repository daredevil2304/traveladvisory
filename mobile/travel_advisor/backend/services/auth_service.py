from sqlalchemy.orm import Session
from pwdlib import PasswordHash

from models.user import User


password_hash = PasswordHash.recommended()


# ============================================================
# PASSWORD HASHING
# ============================================================

def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(
    plain_password: str,
    hashed_password: str,
) -> bool:
    return password_hash.verify(
        plain_password,
        hashed_password,
    )


# ============================================================
# USER LOOKUP
# ============================================================

def get_user_by_email(
    db: Session,
    email: str,
) -> User | None:
    return (
        db.query(User)
        .filter(
            User.email == email.lower(),
        )
        .first()
    )


def get_user_by_mobile(
    db: Session,
    mobile: str,
) -> User | None:
    return (
        db.query(User)
        .filter(
            User.mobile == mobile.strip(),
        )
        .first()
    )


def get_user_by_identifier(
    db: Session,
    identifier: str,
) -> User | None:

    identifier = identifier.strip()

    if "@" in identifier:
        return get_user_by_email(
            db=db,
            email=identifier,
        )

    return get_user_by_mobile(
        db=db,
        mobile=identifier,
    )


# ============================================================
# CREATE USER
# ============================================================

def create_user(
    db: Session,
    full_name: str,
    email: str,
    mobile: str,
    password: str,
) -> User:

    user = User(
        full_name=full_name.strip(),
        email=email.lower(),
        mobile=mobile.strip(),
        password_hash=hash_password(password),
        is_verified=False,
        is_active=True,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


# ============================================================
# AUTHENTICATION
# ============================================================

def authenticate_user(
    db: Session,
    identifier: str,
    password: str,
) -> User | None:

    user = get_user_by_identifier(
        db=db,
        identifier=identifier,
    )

    if user is None:
        return None

    if not user.is_active:
        return None

    if not verify_password(
        plain_password=password,
        hashed_password=user.password_hash,
    ):
        return None

    return user


# ============================================================
# PASSWORD RESET
# ============================================================

def update_password(
    db: Session,
    user: User,
    new_password: str,
) -> User:

    user.password_hash = hash_password(new_password)

    db.commit()
    db.refresh(user)

    return user