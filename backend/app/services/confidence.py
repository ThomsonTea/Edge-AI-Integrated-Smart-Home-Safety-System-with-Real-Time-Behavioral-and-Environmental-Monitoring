from decimal import Decimal


def normalize_confidence_score(value: float | Decimal | None) -> float | None:
    """Normalize legacy percentage inputs to the database's 0..1 scale."""
    if value is None:
        return None

    confidence = float(value)
    if confidence > 1:
        confidence /= 100
    return round(min(max(confidence, 0), 1), 3)


def confidence_score_for_api(value: float | Decimal | None) -> float | None:
    """Keep the existing API contract, which exposes confidence as percent."""
    if value is None:
        return None
    confidence = float(value)
    return confidence * 100 if confidence <= 1 else confidence
