import base64
import io
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient
from pypdf import PdfReader, PdfWriter

from main import _request_times, app


def pdf_bytes() -> bytes:
    writer = PdfWriter()
    writer.add_blank_page(width=200, height=300)
    result = io.BytesIO()
    writer.write(result)
    return result.getvalue()


class ConverterTests(unittest.TestCase):
    def setUp(self):
        _request_times.clear()
        self.client = TestClient(app)
        self.encoded_pdf = base64.b64encode(pdf_bytes()).decode("ascii")

    def test_rotate_pdf_returns_rotated_pdf(self):
        response = self.client.post("/convert", json={
            "operation": "rotate",
            "fileName": "../../scan.pdf",
            "bytesBase64": self.encoded_pdf,
            "degrees": 90,
        })
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["fileName"], "scan-rotated.pdf")
        result = PdfReader(io.BytesIO(base64.b64decode(payload["bytesBase64"])))
        self.assertEqual(result.pages[0].rotation, 90)

    def test_ocr_pdf_returns_text_and_uses_local_tools(self):
        def fake_process(args, **kwargs):
            if args[0] == "pdftoppm":
                Path(str(args[-1]) + ".png").write_bytes(b"image")
                return type("Result", (), {"stdout": b"", "stderr": b""})()
            return type("Result", (), {"stdout": b"recognized words", "stderr": b""})()

        with patch("main.subprocess.run", side_effect=fake_process):
            response = self.client.post("/convert", json={
                "operation": "ocr",
                "fileName": "scan.pdf",
                "bytesBase64": self.encoded_pdf,
            })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["fileName"], "scan-ocr.txt")
        output = base64.b64decode(response.json()["bytesBase64"]).decode()
        self.assertIn("recognized words", output)

    def test_media_conversion_is_bounded_and_returns_target_file(self):
        def fake_process(args, **kwargs):
            Path(args[-1]).write_bytes(b"converted media")
            return type("Result", (), {"stdout": b"", "stderr": b""})()

        with patch("main.subprocess.run", side_effect=fake_process):
            response = self.client.post("/convert", json={
                "operation": "media",
                "fileName": "clip.mp4",
                "target": "mp3",
                "bytesBase64": base64.b64encode(b"input").decode(),
            })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["fileName"], "clip.mp3")
        self.assertEqual(base64.b64decode(response.json()["bytesBase64"]), b"converted media")

    def test_media_conversion_rejects_unsupported_target(self):
        response = self.client.post("/convert", json={
            "operation": "media",
            "fileName": "clip.mp4",
            "target": "exe",
            "bytesBase64": base64.b64encode(b"input").decode(),
        })
        self.assertEqual(response.status_code, 400)

    def test_converter_limits_requests_per_ip(self):
        headers = {"x-real-ip": "203.0.113.99"}
        body = {"operation": "not-real"}
        for _ in range(20):
            self.assertEqual(self.client.post("/convert", json=body, headers=headers).status_code, 400)
        limited = self.client.post("/convert", json=body, headers=headers)
        self.assertEqual(limited.status_code, 429)
        self.assertEqual(limited.headers["retry-after"], "60")


if __name__ == "__main__":
    unittest.main()
