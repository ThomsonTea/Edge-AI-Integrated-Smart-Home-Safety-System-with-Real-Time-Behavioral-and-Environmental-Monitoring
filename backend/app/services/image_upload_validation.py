from pathlib import Path

from fastapi import HTTPException, UploadFile, status

ALLOWED_IMAGE_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
}
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}
MAX_IMAGE_UPLOAD_BYTES = 5 * 1024 * 1024
INVALID_IMAGE_TYPE_MESSAGE = "Only JPG, JPEG and PNG images are allowed."
IMAGE_TOO_LARGE_MESSAGE = "Image must be smaller than 5 MB."


async def read_validated_image_upload(image: UploadFile) -> tuple[bytes, str]:
    content_type = (image.content_type or "").lower()
    extension = Path(image.filename or "").suffix.lower()

    if (
        content_type not in ALLOWED_IMAGE_CONTENT_TYPES
        or extension not in ALLOWED_IMAGE_EXTENSIONS
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=INVALID_IMAGE_TYPE_MESSAGE,
        )

    image_bytes = await image.read()

    if len(image_bytes) > MAX_IMAGE_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=IMAGE_TOO_LARGE_MESSAGE,
        )

    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=INVALID_IMAGE_TYPE_MESSAGE,
        )

    return image_bytes, extension
