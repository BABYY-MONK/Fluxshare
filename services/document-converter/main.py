import base64
import io
import os
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path

from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from pypdf import PdfReader, PdfWriter

MAX_BYTES = 50 * 1024 * 1024
app = FastAPI(title="FluxShare document conversion service")
origins = [value.strip() for value in os.getenv("ALLOWED_ORIGINS", "").split(",") if value.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_methods=["POST", "GET"],
    allow_headers=["Content-Type"],
)


@app.middleware("http")
async def limit_request_size(request, call_next):
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > 75 * 1024 * 1024:
        return Response(status_code=413, content="Request exceeds 75 MB")
    return await call_next(request)


class ConvertRequest(BaseModel):
    operation: str = "convert"
    target: str | None = None
    fileName: str = "merged.pdf"
    bytesBase64: str = ""
    pageRanges: str | None = None
    files: list[dict[str, str]] | None = None


def decode(encoded: str) -> bytes:
    try:
        data = base64.b64decode(encoded, validate=True)
    except Exception as exc:
        raise HTTPException(400, "Invalid base64 file data") from exc
    if not data or len(data) > MAX_BYTES:
        raise HTTPException(413, "Each file must be between 1 byte and 50 MB")
    return data


def respond(data: bytes, filename: str) -> dict[str, str]:
    if len(data) > MAX_BYTES:
        raise HTTPException(413, "The converted file exceeds 50 MB")
    return {"bytesBase64": base64.b64encode(data).decode("ascii"), "fileName": filename}


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/convert")
def convert(request: ConvertRequest):
    operation = request.operation
    if operation == "convert":
        if Path(request.fileName).suffix.lower() != ".docx" or request.target != "pdf":
            raise HTTPException(400, "Only DOCX to PDF conversion is supported here")
        data = decode(request.bytesBase64)
        with tempfile.TemporaryDirectory(prefix="fluxshare-") as tmp:
            root = Path(tmp)
            source = root / "source.docx"
            source.write_bytes(data)
            try:
                subprocess.run(
                    ["libreoffice", "-env:UserInstallation=file://" + str(root / "profile"),
                     "--headless", "--convert-to", "pdf", "--outdir", str(root), str(source)],
                    check=True, capture_output=True, timeout=90,
                )
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
                raise HTTPException(422, "LibreOffice could not convert this DOCX file") from exc
            output = root / "source.pdf"
            if not output.exists():
                raise HTTPException(422, "LibreOffice did not produce a PDF")
            stem = Path(request.fileName).stem
            return respond(output.read_bytes(), f"{stem}.pdf")

    if operation == "merge":
        files = request.files or []
        if len(files) < 2 or len(files) > 20:
            raise HTTPException(400, "Choose between 2 and 20 PDF files")
        writer = PdfWriter()
        for item in files:
            reader = PdfReader(io.BytesIO(decode(item.get("bytesBase64", ""))))
            if reader.is_encrypted:
                raise HTTPException(400, "Password-protected PDFs are not supported")
            for page in reader.pages:
                writer.add_page(page)
        output = io.BytesIO()
        writer.write(output)
        return respond(output.getvalue(), "merged.pdf")

    if operation in {"compress", "split"}:
        data = decode(request.bytesBase64)
        reader = PdfReader(io.BytesIO(data))
        if reader.is_encrypted:
            raise HTTPException(400, "Password-protected PDFs are not supported")
        if operation == "compress":
            writer = PdfWriter()
            for page in reader.pages:
                writer.add_page(page)
                page.compress_content_streams()
            output = io.BytesIO()
            writer.write(output)
            return respond(output.getvalue(), f"{Path(request.fileName).stem}-compressed.pdf")

        ranges = request.pageRanges or ""
        if not re.fullmatch(r"\s*\d+(?:\s*-\s*\d+)?(?:\s*,\s*\d+(?:\s*-\s*\d+)?)*\s*", ranges):
            raise HTTPException(400, "Use page numbers such as 1-3,5")
        indexes: list[int] = []
        for part in ranges.split(","):
            ends = [int(v.strip()) for v in part.split("-")]
            start, end = (ends[0], ends[-1])
            if start < 1 or end < start or end > len(reader.pages):
                raise HTTPException(400, f"Page range is outside this PDF (1-{len(reader.pages)})")
            indexes.extend(range(start - 1, end))
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for part_number, index in enumerate(indexes, 1):
                writer = PdfWriter()
                writer.add_page(reader.pages[index])
                single = io.BytesIO()
                writer.write(single)
                bundle.writestr(f"page-{part_number}.pdf", single.getvalue())
        return respond(archive.getvalue(), f"{Path(request.fileName).stem}-split.zip")

    raise HTTPException(400, "Unknown operation")

