from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import threading
import time
from typing import Any

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from config import settings


# Canonical municipal weather station coordinates for corridor cities.
# OpenWeather's generic 'q=City,IN' query can resolve to maritime/harbor stations
# with coastal cooling (e.g. South Bombay / Wadala 19.0144, 72.8479 returning 28-29°C),
# whereas official municipal station observations shown on openweathermap.org use the
# Santacruz IMD / city center coordinates (19.0760, 72.8777 returning 31-32°C).
MUNICIPAL_STATION_COORDINATES: dict[str, tuple[float, float]] = {
    "mumbai": (19.0760, 72.8777),
    "bombay": (19.0760, 72.8777),
    "sion": (19.0760, 72.8777),
    "kurla": (19.0760, 72.8777),
    "santacruz": (19.0760, 72.8777),
    "panvel": (18.9888, 73.1101),
    "khalapur": (18.8167, 73.2667),
    "khopoli": (18.7877, 73.3438),
    "khandala": (18.7607, 73.3768),
    "bhor ghat": (18.7607, 73.3768),
    "bhor": (18.7607, 73.3768),
    "bhorghat": (18.7607, 73.3768),
    "ghat": (18.7607, 73.3768),
    "khandala ghat": (18.7607, 73.3768),
    "lonavala": (18.7546, 73.4062),
    "kamshet": (18.7629, 73.5576),
    "pune": (18.5314, 73.8446),
    "shivajinagar": (18.5314, 73.8446),
}


@dataclass(frozen=True)
class WeatherData:
    """
    Standardized weather information used by the
    travel-intelligence system.

    This structure is provider-independent.
    """

    latitude: float
    longitude: float
    observed_at: datetime

    temperature_c: float | None = None
    humidity_percent: float | None = None
    rainfall_mm: float | None = None
    wind_speed_kmh: float | None = None
    visibility_km: float | None = None

    weather_condition: str | None = None
    pressure_hpa: float | None = None
    source: str = "openweather"

    def to_dict(self) -> dict:
        return {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "observed_at": self.observed_at.isoformat(),
            "temperature_c": self.temperature_c,
            "humidity_percent": self.humidity_percent,
            "rainfall_mm": self.rainfall_mm,
            "wind_speed_kmh": self.wind_speed_kmh,
            "visibility_km": self.visibility_km,
            "weather_condition": self.weather_condition,
            "pressure_hpa": self.pressure_hpa,
            "source": self.source,
        }


class WeatherServiceError(Exception):
    """
    Raised when OpenWeather cannot provide valid weather data.
    """

    pass


class WeatherService:
    """
    OpenWeather-backed weather service.

    Responsibilities:
    - Validate coordinates.
    - Call OpenWeather current-weather API.
    - Convert provider response into WeatherData.
    - Keep provider-specific response handling inside this layer.

    This service does NOT:
    - calculate Safety Score
    - perform 2-of-3 consensus
    - interpret whether weather is safe
    - access traveler reports
    - run ML models
    """

    REQUEST_TIMEOUT_SECONDS = 10

    def __init__(self) -> None:
        self.provider_name = "openweather"
        self._session = requests.Session()
        adapter = HTTPAdapter(
            pool_connections=25,
            pool_maxsize=25,
            max_retries=Retry(
                total=2,
                backoff_factor=0.2,
                status_forcelist=[500, 502, 503, 504],
            ),
        )
        self._session.mount("https://", adapter)
        self._session.mount("http://", adapter)
        self._lock = threading.Lock()
        self._current_cache: dict[str, tuple[float, WeatherData]] = {}
        self._raw_forecast_cache: dict[str, tuple[float, dict[str, Any]]] = {}
        self._cache_ttl_seconds = 180  # 3 minutes in-memory cache

    def validate_coordinates(
        self,
        latitude: float,
        longitude: float,
    ) -> None:
        """
        Validate geographic coordinates.
        """

        if not -90 <= latitude <= 90:
            raise ValueError(
                f"Invalid latitude: {latitude}"
            )

        if not -180 <= longitude <= 180:
            raise ValueError(
                f"Invalid longitude: {longitude}"
            )

    def create_weather_data(
        self,
        latitude: float,
        longitude: float,
        observed_at: datetime,
        temperature_c: float | None = None,
        humidity_percent: float | None = None,
        rainfall_mm: float | None = None,
        wind_speed_kmh: float | None = None,
        visibility_km: float | None = None,
        weather_condition: str | None = None,
        pressure_hpa: float | None = None,
    ) -> WeatherData:
        """
        Create standardized WeatherData.

        Useful for tests and as the normalization boundary
        for provider responses.
        """

        self.validate_coordinates(
            latitude=latitude,
            longitude=longitude,
        )

        return WeatherData(
            latitude=latitude,
            longitude=longitude,
            observed_at=observed_at,
            temperature_c=temperature_c,
            humidity_percent=humidity_percent,
            rainfall_mm=rainfall_mm,
            wind_speed_kmh=wind_speed_kmh,
            visibility_km=visibility_km,
            weather_condition=weather_condition,
            pressure_hpa=pressure_hpa,
            source=self.provider_name,
        )

    def get_current_weather(
        self,
        latitude: float,
        longitude: float,
        city_name: str | None = None,
    ) -> WeatherData:
        """
        Retrieve current weather from OpenWeather.
        Supports querying by canonical municipal station coordinates (e.g. Santacruz
        station for Mumbai matching openweathermap.org), or falling back to coordinates.
        """
        query_lat = latitude
        query_lon = longitude

        if city_name and isinstance(city_name, str) and city_name.strip():
            city_key = city_name.strip().lower()
            if city_key in MUNICIPAL_STATION_COORDINATES:
                query_lat, query_lon = MUNICIPAL_STATION_COORDINATES[city_key]
        else:
            for station_name, (s_lat, s_lon) in MUNICIPAL_STATION_COORDINATES.items():
                if abs(latitude - s_lat) < 0.05 and abs(longitude - s_lon) < 0.05:
                    query_lat, query_lon = s_lat, s_lon
                    break

        cache_key = f"curr:{city_name.strip().lower() if city_name else ''}:{query_lat:.4f},{query_lon:.4f}"
        now = time.time()
        with self._lock:
            if cache_key in self._current_cache:
                cached_time, cached_val = self._current_cache[cache_key]
                if now - cached_time < self._cache_ttl_seconds:
                    return cached_val

        self.validate_coordinates(
            latitude=query_lat,
            longitude=query_lon,
        )

        api_key = settings.openweather_api_key.strip()

        if not api_key:
            raise WeatherServiceError(
                "OPENWEATHER_API_KEY is not configured."
            )

        url = (
            f"{settings.openweather_base_url.rstrip('/')}"
            "/weather"
        )

        # For unmapped city names, attempt city lookup first
        if (
            city_name
            and isinstance(city_name, str)
            and city_name.strip()
            and city_name.strip().lower() not in MUNICIPAL_STATION_COORDINATES
        ):
            canonical_q = f"{city_name.strip()},IN"
            params_city = {
                "q": canonical_q,
                "appid": api_key,
                "units": "metric",
            }
            try:
                response = self._session.get(
                    url,
                    params=params_city,
                    timeout=self.REQUEST_TIMEOUT_SECONDS,
                )
                if response.status_code == 200:
                    payload = response.json()
                    parsed_res = self._parse_openweather_response(
                        payload=payload,
                        requested_latitude=query_lat,
                        requested_longitude=query_lon,
                    )
                    with self._lock:
                        self._current_cache[cache_key] = (now, parsed_res)
                    return parsed_res
            except Exception:
                pass

        params = {
            "lat": query_lat,
            "lon": query_lon,
            "appid": api_key,
            "units": "metric",
        }

        try:
            response = self._session.get(
                url,
                params=params,
                timeout=self.REQUEST_TIMEOUT_SECONDS,
            )
        except requests.RequestException as exc:
            raise WeatherServiceError(
                f"OpenWeather request failed: {exc}"
            ) from exc

        if response.status_code != 200:
            error_message = self._extract_error_message(
                response
            )

            raise WeatherServiceError(
                "OpenWeather returned HTTP "
                f"{response.status_code}: {error_message}"
            )

        try:
            payload = response.json()
        except ValueError as exc:
            raise WeatherServiceError(
                "OpenWeather returned invalid JSON."
            ) from exc

        parsed_res = self._parse_openweather_response(
            payload=payload,
            requested_latitude=query_lat,
            requested_longitude=query_lon,
        )
        with self._lock:
            self._current_cache[cache_key] = (now, parsed_res)
        return parsed_res

    def get_forecast_weather(
        self,
        latitude: float,
        longitude: float,
        target_time: datetime | None = None,
        city_name: str | None = None,
    ) -> WeatherData:
        """
        Retrieve 5-day / 3-hour forecast from OpenWeather and pick
        the forecast interval closest to target_time in IST.
        Supports querying by municipal station coordinates for exact city station forecast.
        """
        query_lat = latitude
        query_lon = longitude

        if city_name and isinstance(city_name, str) and city_name.strip():
            city_key = city_name.strip().lower()
            if city_key in MUNICIPAL_STATION_COORDINATES:
                query_lat, query_lon = MUNICIPAL_STATION_COORDINATES[city_key]
        else:
            for station_name, (s_lat, s_lon) in MUNICIPAL_STATION_COORDINATES.items():
                if abs(latitude - s_lat) < 0.05 and abs(longitude - s_lon) < 0.05:
                    query_lat, query_lon = s_lat, s_lon
                    break

        self.validate_coordinates(
            latitude=query_lat,
            longitude=query_lon,
        )

        fc_cache_key = f"fc:{city_name.strip().lower() if city_name else ''}:{query_lat:.4f},{query_lon:.4f}"
        now = time.time()
        payload = None
        with self._lock:
            if fc_cache_key in self._raw_forecast_cache:
                cached_time, cached_payload = self._raw_forecast_cache[fc_cache_key]
                if now - cached_time < self._cache_ttl_seconds:
                    payload = cached_payload

        if payload is None:
            api_key = settings.openweather_api_key.strip()
            if not api_key:
                return self.get_current_weather(query_lat, query_lon, city_name=city_name)

            url = f"{settings.openweather_base_url.rstrip('/')}/forecast"

            response = None
            # Try city query first if provided and not in municipal coordinates
            if (
                city_name
                and isinstance(city_name, str)
                and city_name.strip()
                and city_name.strip().lower() not in MUNICIPAL_STATION_COORDINATES
            ):
                try:
                    resp = self._session.get(
                        url,
                        params={
                            "q": f"{city_name.strip()},IN",
                            "appid": api_key,
                            "units": "metric",
                        },
                        timeout=self.REQUEST_TIMEOUT_SECONDS,
                    )
                    if resp.status_code == 200:
                        response = resp
                except Exception:
                    pass

            if response is None:
                params = {
                    "lat": query_lat,
                    "lon": query_lon,
                    "appid": api_key,
                    "units": "metric",
                }

                try:
                    response = self._session.get(
                        url,
                        params=params,
                        timeout=self.REQUEST_TIMEOUT_SECONDS,
                    )
                except requests.RequestException:
                    return self.get_current_weather(query_lat, query_lon, city_name=city_name)

            if response is None or response.status_code != 200:
                return self.get_current_weather(query_lat, query_lon, city_name=city_name)

            try:
                payload = response.json()
            except ValueError:
                return self.get_current_weather(query_lat, query_lon, city_name=city_name)

            with self._lock:
                self._raw_forecast_cache[fc_cache_key] = (now, payload)

        forecast_list = payload.get("list")
        if not isinstance(forecast_list, list) or not forecast_list:
            return self.get_current_weather(query_lat, query_lon, city_name=city_name)

        # If target_time is specified, select the entry with closest timestamp
        selected_entry = forecast_list[0]
        if target_time is not None:
            from services.timezone_service import to_ist
            target_ts = to_ist(target_time).timestamp()
            smallest_diff = float("inf")
            for item in forecast_list:
                item_ts = item.get("dt")
                if isinstance(item_ts, (int, float)):
                    diff = abs(item_ts - target_ts)
                    if diff < smallest_diff:
                        smallest_diff = diff
                        selected_entry = item

        parsed = self._parse_openweather_response(
            payload=selected_entry,
            requested_latitude=query_lat,
            requested_longitude=query_lon,
        )
        return WeatherData(
            latitude=parsed.latitude,
            longitude=parsed.longitude,
            observed_at=parsed.observed_at,
            temperature_c=parsed.temperature_c,
            humidity_percent=parsed.humidity_percent,
            rainfall_mm=parsed.rainfall_mm,
            wind_speed_kmh=parsed.wind_speed_kmh,
            visibility_km=parsed.visibility_km,
            weather_condition=parsed.weather_condition,
            pressure_hpa=parsed.pressure_hpa,
            source="openweather_forecast",
        )

    def _parse_openweather_response(
        self,
        payload: dict[str, Any],
        requested_latitude: float,
        requested_longitude: float,
    ) -> WeatherData:
        """
        Convert the OpenWeather response into our
        provider-independent WeatherData structure.
        """

        main = payload.get("main") or {}
        weather = payload.get("weather") or []
        wind = payload.get("wind") or {}
        rain = payload.get("rain") or {}

        temperature_c = self._to_float(
            main.get("temp")
        )

        humidity_percent = self._to_float(
            main.get("humidity")
        )

        pressure_hpa = self._to_float(
            main.get("pressure")
        )

        visibility_meters = self._to_float(
            payload.get("visibility")
        )

        visibility_km = (
            visibility_meters / 1000.0
            if visibility_meters is not None
            else None
        )

        wind_speed_mps = self._to_float(
            wind.get("speed")
        )

        wind_speed_kmh = (
            wind_speed_mps * 3.6
            if wind_speed_mps is not None
            else None
        )

        rainfall_mm = self._extract_rainfall(rain)

        weather_condition = None

        if weather:
            first_weather = weather[0]

            if isinstance(first_weather, dict):
                weather_condition = (
                    first_weather.get("main")
                    or first_weather.get("description")
                )

        observed_at = self._parse_observed_time(
            payload.get("dt")
        )

        latitude = requested_latitude
        longitude = requested_longitude

        coordinates = payload.get("coord")

        if isinstance(coordinates, dict):
            latitude = self._to_float(
                coordinates.get("lat")
            ) or requested_latitude

            longitude = self._to_float(
                coordinates.get("lon")
            ) or requested_longitude

        return self.create_weather_data(
            latitude=latitude,
            longitude=longitude,
            observed_at=observed_at,
            temperature_c=temperature_c,
            humidity_percent=humidity_percent,
            rainfall_mm=rainfall_mm,
            wind_speed_kmh=wind_speed_kmh,
            visibility_km=visibility_km,
            weather_condition=weather_condition,
            pressure_hpa=pressure_hpa,
        )

    @staticmethod
    def _extract_rainfall(
        rain: dict[str, Any],
    ) -> float | None:
        """
        Extract rainfall in mm from OpenWeather.

        OpenWeather current-weather provides rain.1h or rain.3h.
        OpenWeather 5-day / 3-hour forecast provides rain.3h.
        """
        if not isinstance(rain, dict):
            return None

        value = rain.get("1h")
        if value is None:
            value = rain.get("3h")

        return WeatherService._to_float(value)

    @staticmethod
    def _parse_observed_time(
        unix_timestamp: Any,
    ) -> datetime:
        """
        Convert OpenWeather's UTC Unix timestamp to an
        aware IST datetime.
        """

        timestamp = WeatherService._to_float(
            unix_timestamp
        )

        from services.timezone_service import IST

        if timestamp is None:
            return datetime.now(IST)

        return datetime.fromtimestamp(
            timestamp,
            tz=IST,
        )

    @staticmethod
    def _to_float(
        value: Any,
    ) -> float | None:
        """
        Safely convert a value to float.
        """

        if value is None:
            return None

        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _extract_error_message(
        response: requests.Response,
    ) -> str:
        """
        Extract a useful provider error message.
        """

        try:
            payload = response.json()

            if isinstance(payload, dict):
                message = payload.get("message")

                if message:
                    return str(message)

            return str(payload)

        except ValueError:
            return response.text.strip() or "Unknown error"


# Shared service instance.
weather_service = WeatherService()