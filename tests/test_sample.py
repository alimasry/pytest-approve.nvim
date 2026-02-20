from approvaltests import verify


def test_hello():
    result = "Hello, Worldddd!"
    verify(result)


def test_json_report():
    data = {
        "name": "Alice",
        "age": 30,
        "hobbies": ["reading", "hiking", "coding"],
    }
    result = "\n".join(f"{k}: {v}" for k, v in sorted(data.items()))
    verify(result)


def test_multiline():
    lines = [
        "First line",
        "Second line",
        "Third line",
    ]
    verify("\n".join(lines))
