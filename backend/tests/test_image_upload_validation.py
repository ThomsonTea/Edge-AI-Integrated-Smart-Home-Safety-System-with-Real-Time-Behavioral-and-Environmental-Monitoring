import asyncio
import unittest

from fastapi import HTTPException

from app.services.image_upload_validation import (
    IMAGE_TOO_LARGE_MESSAGE,
    INVALID_IMAGE_TYPE_MESSAGE,
    MAX_IMAGE_UPLOAD_BYTES,
    read_validated_image_upload,
)


class FakeUploadFile:
    def __init__(self, filename: str, content_type: str, content: bytes):
        self.filename = filename
        self.content_type = content_type
        self._content = content

    async def read(self) -> bytes:
        return self._content


def _upload(filename: str, content_type: str, content: bytes) -> FakeUploadFile:
    return FakeUploadFile(filename, content_type, content)


class ImageUploadValidationTests(unittest.TestCase):
    def test_accepts_jpg_jpeg_and_png(self):
        cases = [
            ("face.jpg", "image/jpeg", ".jpg"),
            ("face.jpeg", "image/jpeg", ".jpeg"),
            ("face.jpg", "image/jpg", ".jpg"),
            ("face.png", "image/png", ".png"),
        ]

        for filename, content_type, expected_extension in cases:
            with self.subTest(filename=filename, content_type=content_type):
                image_bytes, extension = asyncio.run(
                    read_validated_image_upload(
                        _upload(filename, content_type, b"image-bytes"),
                    ),
                )

                self.assertEqual(image_bytes, b"image-bytes")
                self.assertEqual(extension, expected_extension)

    def test_rejects_unsupported_formats(self):
        cases = [
            ("face.webp", "image/webp"),
            ("face.gif", "image/gif"),
            ("face.pdf", "application/pdf"),
            ("face.txt", "text/plain"),
            ("face.jpg", "application/pdf"),
            ("face.txt", "image/jpeg"),
        ]

        for filename, content_type in cases:
            with self.subTest(filename=filename, content_type=content_type):
                with self.assertRaises(HTTPException) as context:
                    asyncio.run(
                        read_validated_image_upload(
                            _upload(filename, content_type, b"content"),
                        ),
                    )

                self.assertEqual(context.exception.status_code, 400)
                self.assertEqual(context.exception.detail, INVALID_IMAGE_TYPE_MESSAGE)

    def test_rejects_files_larger_than_five_mb(self):
        with self.assertRaises(HTTPException) as context:
            asyncio.run(
                read_validated_image_upload(
                    _upload(
                        "large.jpg",
                        "image/jpeg",
                        b"x" * (MAX_IMAGE_UPLOAD_BYTES + 1),
                    ),
                ),
            )

        self.assertEqual(context.exception.status_code, 400)
        self.assertEqual(context.exception.detail, IMAGE_TOO_LARGE_MESSAGE)
