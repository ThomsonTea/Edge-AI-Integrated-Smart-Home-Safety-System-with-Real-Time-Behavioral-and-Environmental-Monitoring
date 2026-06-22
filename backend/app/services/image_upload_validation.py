from pathlib import Path

from fastapi import HTTPException, UploadFile, status

ALLOWED_IMAGE_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/heic",
    "image/heif",
}
OCTET_STREAM_CONTENT_TYPE = "application/octet-stream"
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".heic", ".heif"}
ALLOWED_PROFILE_PICTURE_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
}
ALLOWED_PROFILE_PICTURE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
HEIC_IMAGE_EXTENSIONS = {".heic", ".heif"}
MAX_IMAGE_UPLOAD_BYTES = 5 * 1024 * 1024
INVALID_IMAGE_TYPE_MESSAGE = (
    "Only JPG, JPEG, PNG, HEIC and HEIF images are allowed."
)
INVALID_PROFILE_PICTURE_TYPE_MESSAGE = (
    "Only JPG, JPEG, PNG and WebP images are allowed."
)
IMAGE_TOO_LARGE_MESSAGE = "Image must be smaller than 5 MB."
HEIC_FACE_ENGINE_UNSUPPORTED_MESSAGE = (
    "HEIC images are not supported by the face engine. Please use JPG or PNG."
)


async def read_validated_image_upload(image: UploadFile) -> tuple[bytes, str]:
    return await _read_validated_upload(
        image=image,
        allowed_content_types=ALLOWED_IMAGE_CONTENT_TYPES,
        allowed_extensions=ALLOWED_IMAGE_EXTENSIONS,
        invalid_type_message=INVALID_IMAGE_TYPE_MESSAGE,
    )


async def read_validated_profile_picture_upload(
    image: UploadFile,
) -> tuple[bytes, str]:
    return await _read_validated_upload(
        image=image,
        allowed_content_types=ALLOWED_PROFILE_PICTURE_CONTENT_TYPES,
        allowed_extensions=ALLOWED_PROFILE_PICTURE_EXTENSIONS,
        invalid_type_message=INVALID_PROFILE_PICTURE_TYPE_MESSAGE,
    )


async def _read_validated_upload(
    *,
    image: UploadFile,
    allowed_content_types: set[str],
    allowed_extensions: set[str],
    invalid_type_message: str,
) -> tuple[bytes, str]:
    content_type = (image.content_type or "").lower()
    extension = Path(image.filename or "").suffix.lower()
    image_bytes = await image.read()

    print(
        "[UPLOAD] image received: "
        f"filename={image.filename!r} "
        f"content_type={content_type!r} "
        f"size={len(image_bytes)}"
    )

    valid_content_type = content_type in allowed_content_types or (
        content_type == OCTET_STREAM_CONTENT_TYPE
        and extension in allowed_extensions
    )

    if not valid_content_type or extension not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=invalid_type_message,
        )

    if len(image_bytes) > MAX_IMAGE_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=IMAGE_TOO_LARGE_MESSAGE,
        )

    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=invalid_type_message,
        )

    return image_bytes, extension


def ensure_face_engine_supported_image(extension: str) -> None:
    if extension.lower() in HEIC_IMAGE_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=HEIC_FACE_ENGINE_UNSUPPORTED_MESSAGE,
        )
