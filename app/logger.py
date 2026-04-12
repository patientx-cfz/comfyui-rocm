from collections import deque
from datetime import datetime
import io
import logging
import re
import sys
import threading
import warnings

# glog-style messages emitted directly to stderr by C++/DLL libraries:
# e.g. "W0406 21:17:17.167000 12636 utils.py:42] some warning"
_NATIVE_LOG_RE = re.compile(r'^[WIEF]\d{4} \d{2}:\d{2}:\d{2}')
_in_native_warn = threading.local()

from rich.theme import Theme
from rich.logging import RichHandler
from rich.highlighter import RegexHighlighter, ReprHighlighter
from rich.panel import Panel
from rich.text import Text
from rich.console import Console
from rich.pretty import install as pretty_install
from rich.traceback import install as traceback_install


class _ComfyHighlighter(ReprHighlighter):
    """ReprHighlighter extended with ComfyUI / ML domain keyword colors."""
    highlights = ReprHighlighter.highlights + [
        r"(?P<ml_latent>\blatents?\b)",
        r"(?P<ml_sampler>\bsamplers?\b)",
        r"(?P<ml_sigma>\bsigmas?\b)",
        r"(?P<ml_scheduler>\bschedulers?\b)",
        r"(?P<ml_model>\bmodel\b)",
        r"(?P<ml_checkpoint>\bcheckpoint\b)",
        r"(?P<ml_lora>\blora\b)",
        r"(?P<ml_vae>\bvae\b)",
        r"(?P<ml_clip>\bclip\b)",
        r"(?P<ml_unet>\bunet\b)",
        r"(?P<ml_cfg>\bcfg\b)",
        r"(?P<ml_denoise>\bdenoise(?:d|r)?\b)",
        r"(?P<ml_tensor>\btensor\b)",
        r"(?P<ml_device>\bdevice\b)",
        r"(?P<ml_node>\bnode\b)",
        r"(?P<ml_step>\bsteps?\b)",
        r"(?P<ml_cond>\bconds?\b)",
        r"(?P<ml_noise>\bnoise\b)",
        r"(?P<ml_seed>\bseed\b)",
    ]


class _BracketedRichHandler(RichHandler):
    """RichHandler that renders level names as [INFO], [WARNING] etc.
    Coordinates with active tqdm bars: clears them before emitting, redraws after."""
    def get_level_text(self, record: logging.LogRecord) -> Text:
        level_name = record.levelname
        return Text.styled(f"[{level_name}]".ljust(9), f"logging.level.{level_name.lower()}")

    def emit(self, record: logging.LogRecord) -> None:
        try:
            from tqdm import tqdm as _tqdm
            with _tqdm.get_lock():
                for bar in list(_tqdm._instances):
                    bar.clear(nolock=True)
                super().emit(record)
                for bar in list(_tqdm._instances):
                    bar.display(nolock=True)
        except Exception:
            super().emit(record)

logs = None
stdout_interceptor = None
stderr_interceptor = None
console = None


class LogInterceptor(io.TextIOWrapper):
    def __init__(self, stream, *args, **kwargs):
        buffer = stream.buffer
        encoding = stream.encoding
        super().__init__(buffer, *args, **kwargs, encoding=encoding, line_buffering=stream.line_buffering)
        self._lock = threading.Lock()
        self._flush_callbacks = []
        self._logs_since_flush = []

    def write(self, data):
        entry = {"t": datetime.now().isoformat(), "m": data}
        with self._lock:
            self._logs_since_flush.append(entry)

            # Simple handling for cr to overwrite the last output if it isnt a full line
            # else logs just get full of progress messages
            if isinstance(data, str) and data.startswith("\r") and not logs[-1]["m"].endswith("\n"):
                logs.pop()
            logs.append(entry)

        # Intercept raw glog-format warnings from C++/DLL libraries and render
        # them in a Rich panel so they stand out without polluting raw stderr.
        if isinstance(data, str) and _NATIVE_LOG_RE.match(data) and console is not None:
            if not getattr(_in_native_warn, 'active', False):
                _in_native_warn.active = True
                try:
                    console.print(Panel(
                        data.strip(),
                        title="[yellow]native warning[/yellow]",
                        border_style="yellow",
                        padding=(0, 1),
                    ))
                finally:
                    _in_native_warn.active = False
                return  # panel already rendered it; suppress raw output

        super().write(data)

    def flush(self):
        super().flush()
        for cb in self._flush_callbacks:
            cb(self._logs_since_flush)
            self._logs_since_flush = []

    def on_flush(self, callback):
        self._flush_callbacks.append(callback)


def get_logs():
    return logs


def on_flush(callback):
    if stdout_interceptor is not None:
        stdout_interceptor.on_flush(callback)
    if stderr_interceptor is not None:
        stderr_interceptor.on_flush(callback)


def setup_logger(log_level: str = '[INFO]', capacity: int = 300, use_stdout: bool = False):
    global logs, stdout_interceptor, stderr_interceptor, console  # pylint: disable=global-statement
    if logs:
        return

    # Override output streams and log to buffer
    logs = deque(maxlen=capacity)
    stdout_interceptor = sys.stdout = LogInterceptor(sys.stdout)
    stderr_interceptor = sys.stderr = LogInterceptor(sys.stderr)

    _theme = Theme({
        # Level labels
        "logging.level.debug":    "color(39)",          # steel blue
        "logging.level.info":     "color(46)",          # bright green
        "logging.level.warning":  "color(220)",         # amber
        "logging.level.error":    "bold color(196)",    # bright red bold
        "logging.level.critical": "bold reverse color(196)",
        # Timestamp bracket
        "log.time":               "color(28)",          # dark forest green
        # Message body — plain white so content stands out against coloured labels
        "logging.message":        "color(252)",         # near-white grey
        # Rich highlighter tokens
        "repr.str":               "color(87)",          # light cyan  — quoted strings
        "repr.path":              "color(73)",          # slate-cyan   — file paths
        "repr.filename":          "color(117)",         # sky blue     — bare filenames
        "repr.number":            "color(214)",         # orange       — numbers
        "repr.bool_true":         "color(83)",          # lime green
        "repr.bool_false":        "color(203)",         # salmon
        "repr.none":              "color(244)",         # mid-grey
        "repr.url":               "underline color(75)",# cornflower blue underlined
        "repr.tag_name":          "color(183)",         # lavender      — XML/HTML tags
        "repr.attrib_name":       "color(150)",         # pale green    — tag attributes
        "repr.attrib_value":      "color(222)",         # pale yellow
        "repr.call":              "color(147)",         # periwinkle    — function calls
        # ML domain keywords
        "ml_latent":     "color(141)",   # violet      — latent/latents
        "ml_sampler":    "color(87)",    # light cyan  — sampler/samplers
        "ml_sigma":      "color(80)",    # teal        — sigma/sigmas
        "ml_scheduler":  "color(147)",   # periwinkle  — scheduler
        "ml_model":      "color(214)",   # orange      — model
        "ml_checkpoint": "color(215)",   # gold        — checkpoint
        "ml_lora":       "color(213)",   # pink        — lora
        "ml_vae":        "color(83)",    # lime green  — vae
        "ml_clip":       "color(117)",   # sky blue    — clip
        "ml_unet":       "color(183)",   # lavender    — unet
        "ml_cfg":        "color(220)",   # amber       — cfg
        "ml_denoise":    "color(210)",   # coral       — denoise
        "ml_tensor":     "color(177)",   # plum        — tensor
        "ml_device":     "color(110)",   # slate blue  — device
        "ml_node":       "color(229)",   # pale yellow — node
        "ml_step":       "color(76)",    # forest green — step/steps
        "ml_cond":       "color(159)",   # powder blue  — cond/conds
        "ml_noise":      "color(246)",   # mid grey    — noise
        "ml_seed":       "color(222)",   # pale yellow — seed
        # Tracebacks
        "traceback.border":              "color(196)",
        "traceback.border.syntax_error": "bold color(196)",
        "traceback.exc_type":            "bold color(196)",
        "traceback.exc_value":           "color(203)",
    })

    level = getattr(logging, log_level.upper(), logging.INFO)

    console = Console(
        stderr=True,
        theme=_theme,
        highlight=True,
        soft_wrap=True,
        tab_size=4,
    )

    _rh = _BracketedRichHandler(
        console=console,
        show_time=True,
        omit_repeated_times=False,
        show_level=True,
        show_path=False,
        markup=False,
        highlighter=_ComfyHighlighter(),
        rich_tracebacks=True,
        tracebacks_show_locals=False,
        log_time_format="[%H:%M:%S]",
        level=level,
    )
    _rh.setFormatter(logging.Formatter("%(message)s"))

    logger = logging.getLogger()
    logger.setLevel(level)

    if use_stdout:
        _stdout_console = Console(theme=_theme, highlight=True, soft_wrap=True, tab_size=4)
        _stdout_rh = _BracketedRichHandler(
            console=_stdout_console,
            show_time=True,
            omit_repeated_times=False,
            show_level=True,
            show_path=False,
            markup=False,
            highlighter=_ComfyHighlighter(),
            rich_tracebacks=True,
            log_time_format="[%H:%M:%S]",
            level=level,
        )
        _stdout_rh.setFormatter(logging.Formatter("%(message)s"))
        _stdout_rh.addFilter(lambda record: record.levelno < logging.ERROR)
        _rh.addFilter(lambda record: record.levelno >= logging.ERROR)
        logger.addHandler(_stdout_rh)

    logger.addHandler(_rh)

    # Pre-configure third-party loggers that add their own StreamHandler and
    # set propagate=False (e.g. aiter).  By installing a redirect handler NOW
    # (before the package is imported), the package's own getLogger() call
    # finds logger.handlers non-empty and skips adding a raw StreamHandler,
    # so all their records flow through our RichHandler instead.
    class _RedirectToRootHandler(logging.Handler):
        def emit(self, record):
            logging.getLogger().handle(record)

    _redirect = _RedirectToRootHandler()
    for _name in ("aiter",):
        _tp_logger = logging.getLogger(_name)
        _tp_logger.handlers = [_redirect]
        _tp_logger.propagate = False
        _tp_logger.setLevel(logging.DEBUG)

    pretty_install(console=console)
    traceback_install(console=console, show_locals=False, max_frames=16, word_wrap=False)

    # Style tqdm progress bars to match the Rich theme.
    # color(28)=forest-green bar, color(46)=bright-green percentage, color(214)=orange rate.
    try:
        import tqdm as _tqdm_mod
        _tqdm_mod.tqdm.bar_format = (
            "\033[38;5;46m{percentage:3.0f}%\033[0m "
            "\033[38;5;28m|{bar}|\033[0m "
            "\033[38;5;214m{n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_fmt}{postfix}]\033[0m"
        )
    except Exception:
        pass

    # Route warnings.warn through logging so they appear as [WARNING] via RichHandler.
    # stacklevel=2 points the source location at the actual call site, not this shim.
    def _warnings_to_log(message, category, filename, lineno, file=None, line=None):
        logging.getLogger("py.warnings").warning(
            f"{filename}:{lineno}: {category.__name__}: {message}"
        )

    warnings.showwarning = _warnings_to_log
    logging.captureWarnings(False)  # we handle it ourselves above

    # Suppress torch._inductor noise about unsupported GPU arch (e.g. AMD RDNA2 + max_autotune_gemm).
    warnings.filterwarnings("ignore", message=".*max_autotune_gemm.*", module=r"torch\._inductor\.utils")


STARTUP_WARNINGS = []


def log_startup_warning(msg):
    logging.warning(msg)
    STARTUP_WARNINGS.append(msg)


def print_startup_warnings():
    for s in STARTUP_WARNINGS:
        logging.warning(s)
    STARTUP_WARNINGS.clear()
