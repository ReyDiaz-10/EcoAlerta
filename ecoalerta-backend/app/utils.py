import random
import unicodedata
from datetime import datetime


def generate_tracking_number() -> str:
    date_prefix = datetime.now().strftime("%Y%m%d")
    random_suffix = random.randint(10000, 99999)
    return f"RAD-{date_prefix}-{random_suffix}"


def normalize_to_ascii(text: str) -> str:
    return "".join(
        c for c in unicodedata.normalize('NFD', text)
        if unicodedata.category(c) != 'Mn'
    )
