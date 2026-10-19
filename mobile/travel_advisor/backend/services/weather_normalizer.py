from __future__ import annotations

from dataclasses import dataclass

from services.weather_service import WeatherData


@dataclass(frozen=True)
class NormalizedWeather:
    """
    Project-level representation of live weather.

    The values are derived from the live OpenWeather response.
    No safety decision is made here.
    """

    rain_condition: str | None = None
    visibility_condition: str | None = None
    fog_condition: str | None = None
    weather_condition: str | None = None

    temperature_c: float | None = None
    humidity_percent: float | None = None
    pressure_hpa: float | None = None
    rainfall_mm: float | None = None
    wind_speed_kmh: float | None = None
    visibility_km: float | None = None

    source: str = "openweather"

    def to_dict(self) -> dict:
        return {
            "rain_condition": self.rain_condition,
            "visibility_condition": self.visibility_condition,
            "fog_condition": self.fog_condition,
            "weather_condition": self.weather_condition,
            "temperature_c": self.temperature_c,
            "humidity_percent": self.humidity_percent,
            "pressure_hpa": self.pressure_hpa,
            "rainfall_mm": self.rainfall_mm,
            "wind_speed_kmh": self.wind_speed_kmh,
            "visibility_km": self.visibility_km,
            "source": self.source,
        }


class WeatherNormalizer:
    """
    Converts provider-level WeatherData into the project's
    controlled weather categories.

    This layer does NOT:
    - calculate Safety Score
    - determine whether travel is safe
    - perform majority voting
    - use traveler reports
    - use ML predictions

    It only standardizes live weather observations.
    """

    RAIN_CATEGORIES = {
        "No Rain",
        "Drizzle",
        "Light Rain",
        "Moderate Rain",
        "Heavy Rain",
        "Very Heavy Rain",
    }

    VISIBILITY_CATEGORIES = {
        "Very Clear",
        "Clear",
        "Slightly Reduced",
        "Moderately Reduced",
        "Poor",
        "Very Poor",
    }

    FOG_CATEGORIES = {
        "None",
        "Light Mist",
        "Moderate Mist",
        "Dense Fog",
        "Very Dense Fog",
    }

    def normalize(
        self,
        weather: WeatherData,
    ) -> NormalizedWeather:
        """
        Normalize a live WeatherData object.
        """

        if not isinstance(weather, WeatherData):
            raise TypeError(
                "weather must be a WeatherData instance."
            )

        rain_condition = self._normalize_rain(
            weather.rainfall_mm,
            weather.weather_condition,
        )

        visibility_condition = self._normalize_visibility(
            weather.visibility_km,
        )

        fog_condition = self._normalize_fog(
            weather.weather_condition,
            visibility_condition,
        )

        return NormalizedWeather(
            rain_condition=rain_condition,
            visibility_condition=visibility_condition,
            fog_condition=fog_condition,
            weather_condition=weather.weather_condition,
            temperature_c=weather.temperature_c,
            humidity_percent=weather.humidity_percent,
            pressure_hpa=weather.pressure_hpa,
            rainfall_mm=weather.rainfall_mm,
            wind_speed_kmh=weather.wind_speed_kmh,
            visibility_km=weather.visibility_km,
            source=weather.source,
        )

    def _normalize_rain(
        self,
        rainfall_mm: float | None,
        weather_condition: str | None,
    ) -> str | None:
        """
        Normalize precipitation into the project's rain categories.

        Rainfall thresholds are used only when OpenWeather provides
        precipitation data.

        If precipitation data is unavailable, the weather condition
        text is used only to distinguish rain/drizzle/thunderstorm
        from non-rain conditions.
        """

        if rainfall_mm is not None:
            if rainfall_mm <= 0:
                return "No Rain"

            if rainfall_mm <= 0.5:
                return "Drizzle"

            if rainfall_mm <= 2.5:
                return "Light Rain"

            if rainfall_mm <= 7.5:
                return "Moderate Rain"

            if rainfall_mm <= 15.0:
                return "Heavy Rain"

            return "Very Heavy Rain"

        condition = self._clean_condition(
            weather_condition
        )

        if condition is None:
            return None

        if "drizzle" in condition:
            return "Drizzle"

        if "rain" in condition:
            return "Moderate Rain"

        if "thunderstorm" in condition:
            return "Moderate Rain"

        return "No Rain"

    def _normalize_visibility(
        self,
        visibility_km: float | None,
    ) -> str | None:
        """
        Convert visibility in kilometres into the project's
        visibility categories.
        """

        if visibility_km is None:
            return None

        if visibility_km >= 10:
            return "Very Clear"

        if visibility_km >= 7:
            return "Clear"

        if visibility_km >= 5:
            return "Slightly Reduced"

        if visibility_km >= 3:
            return "Moderately Reduced"

        if visibility_km >= 1:
            return "Poor"

        return "Very Poor"

    def _normalize_fog(
        self,
        weather_condition: str | None,
        visibility_condition: str | None,
    ) -> str | None:
        """
        Identify fog/mist conditions using the live weather
        description and visibility observation.

        This does not infer a safety decision.
        """

        condition = self._clean_condition(
            weather_condition
        )

        if condition is None:
            if visibility_condition == "Very Poor":
                return "Very Dense Fog"
            elif visibility_condition == "Poor":
                return "Dense Fog"
            return "None"

        if "fog" in condition:
            if visibility_condition == "Very Poor":
                return "Very Dense Fog"
            if visibility_condition == "Poor":
                return "Dense Fog"
            return "Moderate Mist"

        if "mist" in condition or "haze" in condition:
            if visibility_condition in {"Poor", "Very Poor"}:
                return "Very Dense Fog" if visibility_condition == "Very Poor" else "Dense Fog"
            return "Light Mist"

        # When visibility is severely restricted (<1km), mountain mist/dense fog is physically present
        if visibility_condition == "Very Poor":
            return "Very Dense Fog"
        elif visibility_condition == "Poor" and ("rain" in condition or "cloud" in condition or "shower" in condition):
            return "Moderate Mist"

        return "None"

    @staticmethod
    def _clean_condition(
        condition: str | None,
    ) -> str | None:
        """
        Normalize provider weather text for comparison.
        """

        if not isinstance(condition, str):
            return None

        cleaned = condition.strip().lower()

        return cleaned if cleaned else None


weather_normalizer = WeatherNormalizer()