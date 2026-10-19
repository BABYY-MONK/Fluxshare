"""Small synthetic end-to-end checks for the deployed converter."""

import base64
import io
import json
import math
import os
import struct
import urllib.request
import wave
import zipfile

from pypdf import PdfReader, PdfWriter


ENDPOINT = os.environ.get(
    "FLUXSHARE_CONVERTER_URL",
    "https://fluxshare-converter-monks-projects-8f76cf4b.vercel.app/convert",
)


def post(payload: dict) -> dict:
    request = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.loads(response.read())


def encoded(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def minimal_docx() -> bytes:
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as docx:
        docx.writestr(
            "[Content_Types].xml",
            '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
            "</Types>",
        )
        docx.writestr(
            "_rels/.rels",
            '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
            "</Relationships>",
        )
        docx.writestr(
            "word/document.xml",
            '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            "<w:body><w:p><w:r><w:t>FluxShare live smoke test</w:t></w:r></w:p><w:sectPr/></w:body>"
            "</w:document>",
        )
    return archive.getvalue()


def tiny_wav() -> bytes:
    sample_rate = 8000
    frames = [
        struct.pack("<h", int(6000 * math.sin(2 * math.pi * 440 * i / sample_rate)))
        for i in range(sample_rate // 4)
    ]
    audio = io.BytesIO()
    with wave.open(audio, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(b"".join(frames))
    return audio.getvalue()


def main() -> None:
    with urllib.request.urlopen(ENDPOINT.removesuffix("/convert") + "/health", timeout=30) as response:
        assert json.loads(response.read()) == {"ok": True}

    converted = post(
        {
            "operation": "convert",
            "fileName": "smoke.docx",
            "target": "pdf",
            "bytesBase64": encoded(minimal_docx()),
        }
    )
    assert base64.b64decode(converted["bytesBase64"]).startswith(b"%PDF")

    media = post(
        {
            "operation": "media",
            "fileName": "tone.wav",
            "target": "mp3",
            "bytesBase64": encoded(tiny_wav()),
        }
    )
    assert len(base64.b64decode(media["bytesBase64"])) > 100

    pdf = PdfWriter()
    pdf.add_blank_page(width=612, height=792)
    source = io.BytesIO()
    pdf.write(source)
    rotated = post(
        {
            "operation": "rotate",
            "fileName": "blank.pdf",
            "degrees": 90,
            "bytesBase64": encoded(source.getvalue()),
        }
    )
    result = PdfReader(io.BytesIO(base64.b64decode(rotated["bytesBase64"])))
    assert result.pages[0].rotation == 90
    print("Live converter smoke checks passed: health, DOCX/PDF, WAV/MP3, PDF rotation")


if __name__ == "__main__":
    main()
