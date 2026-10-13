from __future__ import annotations

import pickle
from pathlib import Path
from typing import Any

from ml.model_registry import (
    get_registered_model,
)


class ModelLoadError(Exception):
    """
    Raised when a regional ML model cannot be loaded.
    """

    pass


class ModelLoader:
    """
    Loads and caches regional machine-learning models.

    The loader does not know anything about:
    - model features
    - training data
    - prediction logic
    - safety scoring

    Its responsibility is only to locate and load the correct
    regional model.
    """

    def __init__(self) -> None:
        self._model_cache: dict[str, Any] = {}

    def load_model(self, region: str) -> Any:
        """
        Load the model associated with a route region.

        If the model has already been loaded, return the cached
        instance instead of loading it again.
        """
        normalized_region = region.strip().upper()

        if normalized_region in self._model_cache:
            return self._model_cache[normalized_region]

        model_path = get_registered_model(normalized_region)

        if model_path is None:
            raise ModelLoadError(
                f"No ML model is currently available for "
                f"region {normalized_region}."
            )

        try:
            model = self._load_from_file(model_path)
        except Exception as exc:
            raise ModelLoadError(
                f"Failed to load model for {normalized_region} "
                f"from '{model_path.name}': {exc}"
            ) from exc

        self._model_cache[normalized_region] = model

        return model

    def _load_from_file(self, model_path: Path) -> Any:
        """
        Load a supported model file.

        Currently supported:
        - .pkl
        - .pickle
        - .joblib
        """
        extension = model_path.suffix.lower()

        if extension in {".pkl", ".pickle"}:
            with model_path.open("rb") as file:
                return pickle.load(file)

        if extension == ".joblib":
            try:
                import joblib
            except ImportError as exc:
                raise ModelLoadError(
                    "joblib is required to load .joblib models. "
                    "Install it with: pip install joblib"
                ) from exc

            return joblib.load(model_path)

        raise ModelLoadError(
            f"Unsupported model file extension: {extension}"
        )

    def is_model_available(self, region: str) -> bool:
        """
        Check whether a model is available for a region.
        """
        try:
            normalized_region = region.strip().upper()
            return get_registered_model(normalized_region) is not None
        except ValueError:
            return False

    def clear_cache(self) -> None:
        """
        Remove all loaded models from memory.

        Useful during development or model replacement.
        """
        self._model_cache.clear()

    def clear_region_cache(self, region: str) -> None:
        """
        Remove one region's model from the cache.
        """
        normalized_region = region.strip().upper()
        self._model_cache.pop(normalized_region, None)

    def get_cached_regions(self) -> list[str]:
        """
        Return regions whose models are currently loaded in memory.
        """
        return sorted(self._model_cache.keys())


# Shared loader instance for the backend application.
model_loader = ModelLoader()