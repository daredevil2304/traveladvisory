from services.observation_normalizer import ObservationNormalizer


class FakeLLMResponse:
    def __init__(self, content: str):
        self.content = content


class FakeLLMService:
    def __init__(self, response: str):
        self.response = response

    def generate(self, prompt: str, system_prompt: str):
        return FakeLLMResponse(self.response)


def make_normalizer(response: str) -> ObservationNormalizer:
    return ObservationNormalizer(
        llm_service_instance=FakeLLMService(response)
    )


def test_heavy_fog_and_low_visibility():
    normalizer = make_normalizer(
        """
        {
            "observations": {
                "rain": null,
                "visibility": "poor",
                "fog": "dense",
                "unusual_conditions": null,
                "traffic": null
            },
            "location_mentioned": null,
            "confidence": 0.95,
            "needs_clarification": false,
            "clarification_question": null
        }
        """
    )

    result = normalizer.normalize(
        "Bhai fog bahut hai, road barely dikh raha hai."
    )

    assert result.raw_text == (
        "Bhai fog bahut hai, road barely dikh raha hai."
    )
    assert result.fog == "dense"
    assert result.visibility == "poor"
    assert result.extraction_method == "llm"


def test_rockfall():
    normalizer = make_normalizer(
        """
        {
            "observations": {
                "rain": null,
                "visibility": null,
                "fog": null,
                "unusual_conditions": "landslide_rockfall",
                "traffic": null
            },
            "location_mentioned": "Khopoli",
            "confidence": 0.95,
            "needs_clarification": false,
            "clarification_question": null
        }
        """
    )

    result = normalizer.normalize(
        "There are rocks fallen on the road near Khopoli."
    )

    assert result.unusual_conditions == "landslide_rockfall"
    assert result.location_mentioned == "Khopoli"


def test_flooding():
    normalizer = make_normalizer(
        """
        {
            "observations": {
                "rain": null,
                "visibility": null,
                "fog": null,
                "unusual_conditions": "flooding",
                "traffic": null
            },
            "location_mentioned": null,
            "confidence": 0.94,
            "needs_clarification": false,
            "clarification_question": null
        }
        """
    )

    result = normalizer.normalize(
        "Water is covering part of the road."
    )

    assert result.unusual_conditions == "flooding"


def test_heavy_rain():
    normalizer = make_normalizer(
        """
        {
            "observations": {
                "rain": "heavy",
                "visibility": null,
                "fog": null,
                "unusual_conditions": null,
                "traffic": null
            },
            "location_mentioned": null,
            "confidence": 0.96,
            "needs_clarification": false,
            "clarification_question": null
        }
        """
    )

    result = normalizer.normalize(
        "It is raining heavily here."
    )

    assert result.rain == "heavy"


def test_clear_conditions():
    normalizer = make_normalizer(
        """
        {
            "observations": {
                "rain": null,
                "visibility": "clear",
                "fog": null,
                "unusual_conditions": null,
                "traffic": null
            },
            "location_mentioned": null,
            "confidence": 0.92,
            "needs_clarification": false,
            "clarification_question": null
        }
        """
    )

    result = normalizer.normalize(
        "Weather is clear and I can see the road clearly."
    )

    assert result.visibility == "clear"


def test_traffic():
    normalizer = make_normalizer(
        """
        {
            "observations": {
                "rain": null,
                "visibility": null,
                "fog": null,
                "unusual_conditions": null,
                "traffic": "standstill"
            },
            "location_mentioned": null,
            "confidence": 0.97,
            "needs_clarification": false,
            "clarification_question": null
        }
        """
    )

    result = normalizer.normalize(
        "Traffic is at a standstill."
    )

    assert result.traffic == "standstill"


def test_multiple_conditions():
    normalizer = make_normalizer(
        """
        {
            "observations": {
                "rain": "heavy",
                "visibility": "poor",
                "fog": "dense",
                "unusual_conditions": null,
                "traffic": null
            },
            "location_mentioned": null,
            "confidence": 0.96,
            "needs_clarification": false,
            "clarification_question": null
        }
        """
    )

    result = normalizer.normalize(
        "There is heavy rain and thick fog. "
        "The road is barely visible."
    )

    assert result.rain == "heavy"
    assert result.fog == "dense"
    assert result.visibility == "poor"


def test_empty_observation():
    normalizer = ObservationNormalizer()

    try:
        normalizer.normalize("")
        assert False, "Expected ValueError"
    except ValueError:
        pass


def test_to_dict():
    normalizer = make_normalizer(
        """
        {
            "observations": {
                "rain": "heavy",
                "visibility": "poor",
                "fog": null,
                "unusual_conditions": null,
                "traffic": null
            },
            "location_mentioned": null,
            "confidence": 0.94,
            "needs_clarification": false,
            "clarification_question": null
        }
        """
    )

    result = normalizer.normalize(
        "Heavy rain and poor visibility."
    )

    data = result.to_dict()

    assert data["raw_text"] == (
        "Heavy rain and poor visibility."
    )
    assert data["rain"] == "heavy"
    assert data["visibility"] == "poor"
    assert data["extraction_method"] == "llm"
