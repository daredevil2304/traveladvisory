from services.observation_normalizer import observation_normalizer


tests = [
    "Bhai ghat ke paas visibility ekdum kharab hai, kuch door tak road samajh hi nahi aa raha.",
    "Paani itna jama hai ki gaadi nikalna mushkil lag raha hai.",
    "Khandala side pathar gir ke road pe pade hain.",
    "Barish halki hai but road grip nahi de raha.",
    "Sab normal hai, road properly visible hai.",
]


for i, text in enumerate(tests, 1):
    print("=" * 70)
    print(f"TEST {i}")
    print(f"INPUT: {text}")

    try:
        result = observation_normalizer.normalize(text)

        print(f"Rain:        {result.rain}")
        print(f"Visibility:  {result.visibility}")
        print(f"Fog:         {result.fog}")
        print(f"Unusual:     {result.unusual_conditions}")
        print(f"Traffic:     {result.traffic}")
        print(f"Location:    {result.location_mentioned}")
        print(f"Confidence:  {result.confidence}")
        print(f"Clarify:     {result.needs_clarification}")
        print(f"Method:      {result.extraction_method}")

    except Exception as e:
        print(f"ERROR: {e}")

print("=" * 70)