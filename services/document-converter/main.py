import base64
import io
import os
import re
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path

from collections import defaultdict, deque

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
_request_times: dict[str, deque[float]] = defaultdict(deque)
_RATE_WINDOW_SECONDS = 60
_RATE_LIMIT = 20


@app.middleware("http")
async def limit_request_size(request, call_next):
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > 75 * 1024 * 1024:
        return Response(status_code=413, content="Request exceeds 75 MB")
    if request.url.path == "/convert" and request.method == "POST":
        # Vercel overwrites x-real-ip. In other deployments, set ingress to
        # overwrite this header before trusting it as a client identifier.
        address = request.headers.get("x-real-ip") or (request.client.host if request.client else "unknown")
        now = time.monotonic()
        recent = _request_times[address]
        while recent and now - recent[0] > _RATE_WINDOW_SECONDS:
            recent.popleft()
        if len(recent) >= _RATE_LIMIT:
            return Response(
                status_code=429,
                content="Conversion rate limit exceeded. Try again in one minute.",
                headers={"Retry-After": str(_RATE_WINDOW_SECONDS)},
            )
        recent.append(now)
        if len(_request_times) > 10_000:
            expired = [
                client for client, timestamps in _request_times.items()
                if not timestamps or now - timestamps[-1] > _RATE_WINDOW_SECONDS
            ]
            for client in expired:
                _request_times.pop(client, None)
    return await call_next(request)


class ConvertRequest(BaseModel):
    operation: str = "convert"
    target: str | None = None
    fileName: str = "merged.pdf"
    bytesBase64: str = ""
    pageRanges: str | None = None
    files: list[dict[str, str]] | None = None
    degrees: int = 90


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


def safe_stem(filename: str) -> str:
    leaf = filename.replace("\\", "/").rsplit("/", 1)[-1]
    stem = Path(leaf).stem.strip(" .")
    cleaned = re.sub(r"[^\w .()-]", "_", stem, flags=re.UNICODE)[:120]
    return cleaned or "converted"


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
            return respond(output.read_bytes(), f"{safe_stem(request.fileName)}.pdf")

    if operation == "merge":
        files = request.files or []
        if len(files) < 2 or len(files) > 20:
            raise HTTPException(400, "Choose between 2 and 20 PDF files")
        writer = PdfWriter()
        total_pages = 0
        for item in files:
            reader = PdfReader(io.BytesIO(decode(item.get("bytesBase64", ""))))
            if reader.is_encrypted:
                raise HTTPException(400, "Password-protected PDFs are not supported")
            total_pages += len(reader.pages)
            if total_pages > 200:
                raise HTTPException(413, "PDF tools are limited to 200 pages")
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
        if not reader.pages:
            raise HTTPException(400, "This PDF does not contain any pages")
        if len(reader.pages) > 200:
            raise HTTPException(413, "PDF tools are limited to 200 pages")
        if operation == "compress":
            writer = PdfWriter()
            for page in reader.pages:
                writer.add_page(page)
                page.compress_content_streams()
            output = io.BytesIO()
            writer.write(output)
            return respond(output.getvalue(), f"{safe_stem(request.fileName)}-compressed.pdf")

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
            if len(indexes) > 200:
                raise HTTPException(413, "PDF tools are limited to 200 output pages")
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for part_number, index in enumerate(indexes, 1):
                writer = PdfWriter()
                writer.add_page(reader.pages[index])
                single = io.BytesIO()
                writer.write(single)
                bundle.writestr(f"page-{part_number}.pdf", single.getvalue())
        return respond(archive.getvalue(), f"{safe_stem(request.fileName)}-split.zip")

    if operation == "rotate":
        if request.degrees not in {90, 180, 270}:
            raise HTTPException(400, "Rotation must be 90, 180, or 270 degrees")
        data = decode(request.bytesBase64)
        reader = PdfReader(io.BytesIO(data))
        if reader.is_encrypted:
            raise HTTPException(400, "Password-protected PDFs are not supported")
        if not reader.pages:
            raise HTTPException(400, "This PDF does not contain any pages")
        if len(reader.pages) > 200:
            raise HTTPException(413, "PDF tools are limited to 200 pages")
        writer = PdfWriter()
        for page in reader.pages:
            page.rotate(request.degrees)
            writer.add_page(page)
        output = io.BytesIO()
        writer.write(output)
        return respond(output.getvalue(), f"{safe_stem(request.fileName)}-rotated.pdf")

    if operation == "ocr":
        data = decode(request.bytesBase64)
        reader = PdfReader(io.BytesIO(data))
        if reader.is_encrypted:
            raise HTTPException(400, "Password-protected PDFs are not supported")
        if not reader.pages:
            raise HTTPException(400, "This PDF does not contain any pages")
        if len(reader.pages) > 20:
            raise HTTPException(413, "OCR is limited to 20-page PDFs")
        pixels_per_point = 120 / 72
        for page_number, page in enumerate(reader.pages, 1):
            box = page.mediabox
            width = float(box.width)
            height = float(box.height)
            if width <= 0 or height <= 0 or width * height * pixels_per_point**2 > 12_000_000:
                raise HTTPException(413, f"OCR page {page_number} exceeds the safe page dimensions")
        with tempfile.TemporaryDirectory(prefix="fluxshare-ocr-") as tmp:
            root = Path(tmp)
            source = root / "source.pdf"
            source.write_bytes(data)
            sections: list[str] = []
            for page_number in range(1, len(reader.pages) + 1):
                prefix = root / f"page-{page_number:03d}"
                try:
                    subprocess.run(
                        ["pdftoppm", "-f", str(page_number), "-l", str(page_number),
                         "-singlefile", "-r", "120", "-png", str(source), str(prefix)],
                        check=True, capture_output=True, timeout=20,
                    )
                    recognized = subprocess.run(
                        ["tesseract", str(prefix) + ".png", "stdout", "-l", "eng", "--psm", "3"],
                        check=True, capture_output=True, timeout=20,
                    )
                except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
                    raise HTTPException(422, f"OCR failed on page {page_number}") from exc
                sections.append(f"--- Page {page_number} ---\n{recognized.stdout.decode('utf-8', errors='replace').strip()}")
            text = "\n\n".join(sections).encode("utf-8")
            return respond(text, f"{safe_stem(request.fileName)}-ocr.txt")

    if operation == "media":
        input_ext = Path(request.fileName).suffix.lower()
        if input_ext not in {".mp4", ".m4v", ".mov", ".webm", ".mkv", ".avi", ".ogv",
                              ".mp3", ".wav", ".m4a", ".aac", ".flac", ".ogg"}:
            raise HTTPException(400, "Unsupported audio/video input type")
        target = (request.target or "").lower().lstrip(".")
        if target not in {"mp4", "webm", "mp3", "wav", "gif"}:
            raise HTTPException(400, "Unsupported audio/video output type")
        if target == "gif" and input_ext in {".mp3", ".wav", ".m4a", ".aac", ".flac", ".ogg"}:
            raise HTTPException(400, "GIF output requires a video input")
        data = decode(request.bytesBase64)
        with tempfile.TemporaryDirectory(prefix="fluxshare-media-") as tmp:
            root = Path(tmp)
            source = root / ("source" + input_ext)
            output = root / ("converted." + target)
            source.write_bytes(data)
            command = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source)]
            if target == "mp3":
                command += ["-vn", "-codec:a", "libmp3lame", "-q:a", "4"]
            elif target == "wav":
                command += ["-vn", "-codec:a", "pcm_s16le"]
            elif target == "gif":
                command += ["-vf", "fps=12,scale=640:-1:flags=lanczos", "-loop", "0"]
            elif target == "webm":
                command += ["-c:v", "libvpx-vp9", "-c:a", "libopus"]
            else:
                command += ["-c:v", "libx264", "-preset", "veryfast", "-c:a", "aac", "-movflags", "+faststart"]
            command.append(str(output))
            try:
                subprocess.run(command, check=True, capture_output=True, timeout=120)
            except subprocess.TimeoutExpired as exc:
                raise HTTPException(422, "Media conversion timed out after 120 seconds") from exc
            except subprocess.CalledProcessError as exc:
                detail = exc.stderr.decode("utf-8", errors="replace")[-1000:]
                raise HTTPException(422, "FFmpeg could not convert this file: " + detail) from exc
            if not output.exists():
                raise HTTPException(422, "FFmpeg did not produce an output file")
            if output.stat().st_size > MAX_BYTES:
                raise HTTPException(413, "The converted media exceeds 50 MB")
            return respond(output.read_bytes(), f"{safe_stem(request.fileName)}.{target}")

    raise HTTPException(400, "Unknown operation")
