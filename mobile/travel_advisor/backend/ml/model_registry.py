from pathlib import Path


# Root directory containing all regional ML models.
MODEL_ROOT = Path(__file__).resolve().parent / "models"


# Supported route regions.
SUPPORTED_REGIONS = (
    "R1",
    "R2",
    "R3",
    "R4",
    "R5",
    "R6",
    "R7",
)


# Model file extensions that the application can recognize.
SUPPORTED_MODEL_EXTENSIONS = (
    ".pkl",
    ".pickle",
    ".joblib",
)


def get_region_model_directory(region: str) -> Path:
    """
    Return the model directory for a specific route region.

    Example:
        R4 -> backend/ml/models/R4/
    """
    normalized_region = region.strip().upper()

    if normalized_region not in SUPPORTED_REGIONS:
        raise ValueError(
            f"Unsupported region '{region}'. "
            f"Supported regions are: {', '.join(SUPPORTED_REGIONS)}."
        )

    return MODEL_ROOT / normalized_region


def get_available_model_files(region: str) -> list[Path]:
    """
    Find supported model files available for a route region.

    The function does not load the model.
    It only discovers files.
    """
    model_directory = get_region_model_directory(region)

    if not model_directory.exists():
        return []

    model_files = []

    for file_path in model_directory.iterdir():
        if (
            file_path.is_file()
            and file_path.suffix.lower()
            in SUPPORTED_MODEL_EXTENSIONS
        ):
            model_files.append(file_path)

    return sorted(
        model_files,
        key=lambda path: path.name.lower(),
    )


def get_registered_model(region: str) -> Path | None:
    """
    Return the model file registered for a region.

    Currently the first supported model file found alphabetically
    is returned.

    Later, this registry can be extended with explicit metadata
    such as model version, algorithm, feature schema, and training date.
    """
    model_files = get_available_model_files(region)

    if not model_files:
        return None

    return model_files[0]


def get_model_status() -> dict[str, dict]:
    """
    Return the current model availability status for R1-R7.

    This is useful for checking which regional models have already
    been supplied by the ML team.
    """
    status = {}

    for region in SUPPORTED_REGIONS:
        model_files = get_available_model_files(region)

        status[region] = {
            "available": bool(model_files),
            "model_count": len(model_files),
            "models": [
                file_path.name
                for file_path in model_files
            ],
        }

    return status