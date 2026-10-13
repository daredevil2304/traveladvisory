import logging
import requests
from config import settings

logger = logging.getLogger(__name__)


class SMSService:
    """Service to send OTP and transactional SMS to mobile numbers."""

    def send_otp(self, mobile: str, otp: str) -> bool:
        """
        Sends an OTP to the given mobile number.
        Supports Fast2SMS (India free/paid) or fallback logging.
        """
        message = f"Your Mumbai-Pune Travel Advisory OTP is: {otp}. Valid for 5 minutes."

        # 1. Fast2SMS Integration (Ideal for Indian mobile numbers)
        if getattr(settings, "fast2sms_api_key", None):
            try:
                # Fast2SMS requires 10-digit number without +91
                cleaned_mobile = mobile.replace("+91", "").strip()[-10:]
                url = "https://www.fast2sms.com/dev/bulkV2"
                headers = {"authorization": settings.fast2sms_api_key}
                payload = {
                    "variables_values": otp,
                    "route": "otp",
                    "numbers": cleaned_mobile,
                }
                response = requests.post(
                    url,
                    data=payload,
                    headers=headers,
                    timeout=5,
                )
                if response.status_code == 200:
                    logger.info("Fast2SMS OTP sent successfully to %s", mobile)
                    return True
                logger.warning(
                    "Fast2SMS failed with status %s: %s",
                    response.status_code,
                    response.text,
                )
            except Exception as e:
                logger.error("Error sending SMS via Fast2SMS: %s", e)

        # 2. Local / Development / Free Fallback
        print("\n" + "=" * 50)
        print("📱 SMS DISPATCH NOTIFICATION")
        print(f"Mobile:  {mobile}")
        print(f"Message: {message}")
        print("=" * 50 + "\n")
        return True


sms_service = SMSService()
