"""Shared model and image-preprocessing helpers for the offline pipeline.

Imports for PyTorch and Pillow are intentionally deferred to callers.  This
keeps manifest validation and its tests usable in a small standard-library
Python environment.
"""

from __future__ import annotations

import hashlib
import random
from pathlib import Path
from typing import Any, Iterable


CLASS_NAMES = tuple(str(value) for value in range(10)) + ("reject",)
MODEL_VERSION = "pipcount-digit-cnn-v1"
PREPROCESSING_VERSION = "ink-canvas-28-v1"
AUGMENTATION_VERSION = "pencilkit-small-affine-v1"
INPUT_SIZE = (28, 28)
MODEL_ARCHITECTURE = {
    "type": "small_cnn",
    "input_shape": [1, 28, 28],
    "layers": [
        "conv2d(1,8,3,padding=1)",
        "relu",
        "max_pool2d(2)",
        "conv2d(8,16,3,padding=1)",
        "relu",
        "max_pool2d(2)",
        "adaptive_avg_pool2d(1,1)",
        "linear(16,11)",
    ],
}


def manifest_digest(path: Path) -> str:
    """Return the SHA-256 digest of the exact manifest bytes."""

    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def artifact_digest(path: Path) -> str:
    """Hash a file or directory deterministically for provenance metadata."""

    path = Path(path)
    digest = hashlib.sha256()
    if path.is_file():
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()
    if not path.is_dir():
        raise FileNotFoundError(path)
    for child in sorted((item for item in path.rglob("*") if item.is_file())):
        relative = child.relative_to(path).as_posix().encode("utf-8")
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        with child.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    return digest.hexdigest()


def build_model(torch: Any) -> Any:
    """Build the classifier from scratch; no pretrained weights are loaded."""

    nn = torch.nn
    return nn.Sequential(
        nn.Conv2d(1, 8, kernel_size=3, padding=1),
        nn.ReLU(),
        nn.MaxPool2d(2),
        nn.Conv2d(8, 16, kernel_size=3, padding=1),
        nn.ReLU(),
        nn.MaxPool2d(2),
        nn.AdaptiveAvgPool2d((1, 1)),
        nn.Flatten(),
        nn.Linear(16, len(CLASS_NAMES)),
    )


def seed_everything(torch: Any, seed: int) -> None:
    """Set deterministic CPU/PyTorch seeds used by training and evaluation."""

    random.seed(seed)
    torch.manual_seed(seed)
    if hasattr(torch, "use_deterministic_algorithms"):
        torch.use_deterministic_algorithms(True)
    if hasattr(torch, "backends") and hasattr(torch.backends, "cudnn"):
        torch.backends.cudnn.benchmark = False
        torch.backends.cudnn.deterministic = True


def classifier_samples(manifest: dict[str, Any], split: str) -> list[dict[str, Any]]:
    """Return normalized digit/reject crops for one split.

    Full ``kind=score`` composition samples are retained for segmentation and
    corpus checks, but are not silently fed to this digit classifier because
    segmentation is a separate production component.
    """

    samples = []
    for sample in manifest.get("samples", []):
        if sample.get("split") != split:
            continue
        if sample.get("kind") == "digit" and sample.get("label") in CLASS_NAMES[:10]:
            samples.append(sample)
        elif sample.get("kind") == "reject" and sample.get("label") == "reject":
            samples.append(sample)
    return samples


def _resampling(image_module: Any) -> Any:
    return getattr(getattr(image_module, "Resampling", image_module), "LANCZOS")


def _composite_on_white(image_module: Any, image: Any) -> Any:
    rgba = image.convert("RGBA")
    background = image_module.new("RGBA", rgba.size, (255, 255, 255, 255))
    return image_module.alpha_composite(background, rgba).convert("L")


def _fit_to_canvas(image_module: Any, image: Any) -> Any:
    """Fit a cropped ink image into the same 28x28 canvas used by the app."""

    from PIL import ImageOps

    image = ImageOps.contain(image, (24, 24), method=_resampling(image_module))
    canvas = image_module.new("L", INPUT_SIZE, 255)
    left = (INPUT_SIZE[0] - image.width) // 2
    top = (INPUT_SIZE[1] - image.height) // 2
    canvas.paste(image, (left, top))
    return canvas


def _augment(image_module: Any, image: Any, rng: random.Random) -> Any:
    """Apply only small PencilKit-like affine/width changes."""

    from PIL import ImageFilter

    resampling = _resampling(image_module)
    angle = rng.uniform(-8.0, 8.0)
    scale = rng.uniform(0.92, 1.08)
    translation_x = rng.uniform(-2.0, 2.0)
    translation_y = rng.uniform(-2.0, 2.0)

    image = image.rotate(angle, resample=resampling, fillcolor=255)
    scaled_size = tuple(max(1, round(size * scale)) for size in INPUT_SIZE)
    scaled = image.resize(scaled_size, resample=resampling)
    image = image_module.new("L", INPUT_SIZE, 255)
    left = (INPUT_SIZE[0] - scaled.width) // 2
    top = (INPUT_SIZE[1] - scaled.height) // 2
    image.paste(scaled, (left, top))
    image = image.transform(
        INPUT_SIZE,
        image_module.Transform.AFFINE,
        (1, 0, -translation_x, 0, 1, -translation_y),
        resample=resampling,
        fillcolor=255,
    )
    # MinFilter thickens dark strokes and MaxFilter thins them.  The choice is
    # intentionally small and is not used as an arbitrary shape distortion.
    if rng.random() < 0.5:
        image = image.filter(ImageFilter.MinFilter(3))
    else:
        image = image.filter(ImageFilter.MaxFilter(3))
    return image


def image_to_tensor(
    path: Path,
    torch: Any,
    image_module: Any,
    *,
    training: bool = False,
    seed: int | None = None,
) -> Any:
    """Load a crop as a 1x28x28 tensor with black ink represented as 1."""

    with image_module.open(path) as source:
        image = _composite_on_white(image_module, source)
    image = _fit_to_canvas(image_module, image)
    if training:
        if seed is None:
            raise ValueError("a deterministic seed is required for training augmentation")
        image = _augment(image_module, image, random.Random(seed))
    values = list(image.getdata())
    tensor = torch.tensor(values, dtype=torch.float32).reshape(1, *INPUT_SIZE)
    return 1.0 - (tensor / 255.0)


def sample_seed(seed: int, sample_id: str) -> int:
    """Derive a stable per-sample augmentation seed without Python hash randomization."""

    digest = hashlib.sha256(f"{seed}:{sample_id}".encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big")


def make_dataset(
    torch: Any,
    image_module: Any,
    samples: Iterable[dict[str, Any]],
    data_root: Path,
    *,
    training: bool,
    seed: int,
) -> Any:
    """Construct a deterministic PyTorch dataset from manifest rows."""

    sample_list = list(samples)

    class ManifestDataset(torch.utils.data.Dataset):
        def __len__(self) -> int:
            return len(sample_list)

        def __getitem__(self, index: int) -> tuple[Any, int, str]:
            sample = sample_list[index]
            image_path = data_root / sample["path"]
            tensor = image_to_tensor(
                image_path,
                torch,
                image_module,
                training=training,
                seed=sample_seed(seed, sample["sample_id"]) if training else None,
            )
            label = CLASS_NAMES.index(sample["label"])
            return tensor, label, sample["sample_id"]

    return ManifestDataset()
