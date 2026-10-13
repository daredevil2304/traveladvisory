from services.observation_normalizer import observation_normalizer


TEST_MESSAGES = [
    "Heavy rain near Khopoli and visibility is low.",
    "Bhai Lonavala mein fog bahut hai, kuch clear nahi dikh raha.",
    "Ghat mein rocks road pe aa gaye hain.",
    "Road pe kuch problem hai.",
    "Khandala mein halki baarish hai aur road thoda slippery lag raha hai.",
]


for index, message in enumerate(TEST_MESSAGES, start=1):
    print("=" * 70)
    print(f"TEST {index}")
    print(f"INPUT: {message}")

    try:
        result = observation_normalizer.normalize(message)

        print("\nOUTPUT:")
        print(result.to_dict())

    except Exception as exc:
        print("\nERROR:")
        print(type(exc).__name__, str(exc))


print("=" * 70)
print("Live observation extraction test completed.")