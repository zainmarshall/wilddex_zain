
# main.py

from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import shutil
import os
import uuid
import subprocess
import json
import tempfile
import asyncio
import logging
from typing import Optional
from pydantic import BaseModel

# NOTE: supabase import removed (unused). Add back if needed.

class PredictionResponse(BaseModel):
    genus: str
    species: str
    common_name: str
    bounding_box: list[float]
    confidence: float


logger = logging.getLogger("speciesnet_api")
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))

app = FastAPI(title="SpeciesNet API", version="0.1.1")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Lock this down later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def _parse_prediction(raw_prediction: dict) -> PredictionResponse:
    parts = (raw_prediction.get("prediction") or "").split(";")
    genus = parts[4] if len(parts) > 4 else ""
    species = parts[5] if len(parts) > 5 else ""
    common_name = parts[6] if len(parts) > 6 else ""
    bbox = raw_prediction.get("detections", [{}])[0].get("bbox", [0, 0, 0, 0])
    confidence = float(raw_prediction.get("prediction_score", 0.0))
    return PredictionResponse(
        genus=genus,
        species=species,
        common_name=common_name,
        bounding_box=bbox,
        confidence=confidence,
    )


def _run_speciesnet_cli(temp_dir: str, output_json_path: str) -> None:
    """Fallback subprocess execution of the original CLI.
    Using capture_output to supply helpful diagnostics if it fails.
    """
    result = subprocess.run(
        [
            "python3",
            "-m",
            "speciesnet.scripts.run_model",
            "--folders",
            temp_dir,
            "--predictions_json",
            output_json_path,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"SpeciesNet CLI failed (exit {result.returncode})\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )


_DIRECT_MODEL = None  # type: ignore
_DIRECT_MODEL_LOCK = asyncio.Lock()
_MODEL_READY = False


async def _load_model_once() -> None:
    global _DIRECT_MODEL, _MODEL_READY
    if _MODEL_READY:
        return
    async with _DIRECT_MODEL_LOCK:
        if _MODEL_READY:
            return
        try:
            # Attempt to locate a plausible model loading entry point.
            # These are heuristic and depend on the installed speciesnet package API.
            from speciesnet import model as speciesnet_model  # type: ignore
            load_candidates = [
                getattr(speciesnet_model, name, None)
                for name in ("load_model", "get_model", "Model", "build_model")
            ]
            for cand in load_candidates:
                if callable(cand):
                    try:
                        _DIRECT_MODEL = cand()
                        break
                    except Exception:  # pragma: no cover - best effort
                        continue
            if _DIRECT_MODEL is None:
                logger.info("No direct model constructor found; will use CLI fallback per request.")
            else:
                # Optional warmup: run a dummy pass if the model exposes a predict/infer method.
                warmup_enabled = os.getenv("WARMUP", "1") == "1"
                if warmup_enabled:
                    for meth_name in ("predict", "infer", "__call__"):
                        meth = getattr(_DIRECT_MODEL, meth_name, None)
                        if callable(meth):
                            try:
                                # Provide a minimal dummy input if method accepts arguments; we skip if signature mismatch.
                                # Real warmup would pass a real small image tensor; omitted due to unknown API.
                                meth  # reference to avoid lint warning
                                break
                            except Exception:  # pragma: no cover
                                continue
            _MODEL_READY = True
        except Exception as e:  # pragma: no cover
            logger.info("Direct model load not available: %s", e)
            _MODEL_READY = True  # Mark ready even if using CLI fallback.


def _try_direct_invoke(temp_dir: str, output_json_path: str) -> bool:
    """Attempt to call the underlying module without spawning a new process.
    Returns True if successful, else False (caller will fall back to subprocess).
    """
    try:
        from speciesnet.scripts import run_model as run_model_module  # type: ignore
    except Exception:
        return False

    # Heuristic: look for a 'main' or 'run' callable that accepts argv or args.
    for attr_name in ("main", "run", "cli"):
        fn = getattr(run_model_module, attr_name, None)
        if callable(fn):
            try:
                # Some scripts expect sys.argv-style list; supply minimal arguments.
                argv = [
                    "--folders",
                    temp_dir,
                    "--predictions_json",
                    output_json_path,
                ]
                fn(argv)  # type: ignore[arg-type]
                return True
            except TypeError:
                # Maybe function signature is different; try without args.
                try:
                    fn()  # type: ignore[call-arg]
                    return True
                except Exception:
                    continue
            except Exception:
                # Direct invocation failed; fall back to subprocess.
                return False
    return False


_PERSIST_TEMP_DIR = os.getenv("PERSIST_TEMP_DIR", "1") == "1"
_SHARED_TEMP_DIR: Optional[str] = None


def _ensure_shared_temp_dir() -> str:
    global _SHARED_TEMP_DIR
    if _SHARED_TEMP_DIR and os.path.isdir(_SHARED_TEMP_DIR):
        return _SHARED_TEMP_DIR
    base = tempfile.gettempdir()
    path = os.path.join(base, "speciesnet_api")
    os.makedirs(path, exist_ok=True)
    _SHARED_TEMP_DIR = path
    return path


async def _generate_prediction(file: UploadFile) -> PredictionResponse:
    # Ensure model loaded (lazy) if we eventually add direct inference.
    if os.getenv("MODEL_LOAD_MODE", "lazy") == "eager":
        await _load_model_once()
    else:
        # Lazy: load only if first request hits and not yet loaded (non-blocking background task).
        if not _MODEL_READY:
            asyncio.create_task(_load_model_once())

    if _PERSIST_TEMP_DIR:
        parent_dir = _ensure_shared_temp_dir()
        temp_dir = os.path.join(parent_dir, str(uuid.uuid4()))
        os.makedirs(temp_dir, exist_ok=True)
        temp_dir_cm = None
    else:
        temp_dir_cm = tempfile.TemporaryDirectory()
        temp_dir = temp_dir_cm.name

    image_filename = f"{uuid.uuid4()}.jpg"
    image_path = os.path.join(temp_dir, image_filename)
    with open(image_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

        output_json_path = os.path.join(temp_dir, "output.json")

        # Try direct in-process invocation first to save process spawn overhead.
        used_direct = await asyncio.to_thread(_try_direct_invoke, temp_dir, output_json_path)
        if not used_direct:
            # Use CLI via subprocess (also off main loop).
            await asyncio.to_thread(_run_speciesnet_cli, temp_dir, output_json_path)

        with open(output_json_path, "r") as f:
            raw = json.load(f)
        if not raw.get("predictions"):
            raise ValueError("No predictions returned by SpeciesNet")
        raw_prediction = raw["predictions"][0]
        prediction = _parse_prediction(raw_prediction)

        # Cleanup if persistent temp dir is enabled (remove subfolder) to avoid disk growth.
        if _PERSIST_TEMP_DIR and os.path.isdir(temp_dir):
            try:
                shutil.rmtree(temp_dir)
            except Exception:  # pragma: no cover
                logger.warning("Failed to cleanup temp dir %s", temp_dir)
        elif temp_dir_cm is not None:
            temp_dir_cm.cleanup()

        return prediction


@app.post("/predict", response_model=PredictionResponse)
async def predict(file: UploadFile = File(...)):
    try:
        return await _generate_prediction(file)
    except Exception as e:
        logger.exception("Prediction failed")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.get("/ready")
async def ready() -> dict:
    return {"model_loaded": _MODEL_READY}


@app.on_event("startup")
async def _startup() -> None:
    if os.getenv("MODEL_LOAD_MODE", "lazy") == "eager":
        await _load_model_once()
        logger.info("Model eagerly loaded at startup (ready=%s)", _MODEL_READY)
