from collections import deque
from datetime import datetime
import io
import logging
import sys
import threading

from rich.theme import Theme
from rich.logging import RichHandler
from rich.console import Console
from rich.pretty import install as pretty_install
from rich.traceback import install as traceback_install

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


def setup_logger(log_level: str = 'INFO', capacity: int = 300, use_stdout: bool = False):
    global logs, stdout_interceptor, stderr_interceptor, console  # pylint: disable=global-statement
    if logs:
        return

    # Override output streams and log to buffer
    logs = deque(maxlen=capacity)
    stdout_interceptor = sys.stdout = LogInterceptor(sys.stdout)
    stderr_interceptor = sys.stderr = LogInterceptor(sys.stderr)

    # Hacker-green theme: timestamps dim-green, levels in distinct terminal colors,
    # tracebacks in dark-red, strings/paths in bright cyan.
    _theme = Theme({
        "logging.level.debug":    "color(33)",         # bright blue/cyan
        "logging.level.info":     "color(46)",         # bright green
        "logging.level.warning":  "color(220)",        # amber
        "logging.level.error":    "bold color(196)",   # bright red bold
        "logging.level.critical": "bold reverse color(196)",
        "log.time":               "color(28)",         # dark forest green
        "repr.str":               "color(87)",         # light cyan
        "repr.path":              "color(36)",         # teal
        "repr.number":            "color(214)",        # orange
        "traceback.border":       "color(22)",
        "traceback.border.syntax_error": "color(124)",
    })

    level = getattr(logging, log_level.upper(), logging.INFO)

    console = Console(
        stderr=True,
        theme=_theme,
        highlight=True,
        soft_wrap=True,
        tab_size=4,
    )

    _rh = RichHandler(
        console=console,
        show_time=True,
        omit_repeated_times=False,
        show_level=True,
        show_path=False,
        markup=False,
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
        _stdout_rh = RichHandler(
            console=_stdout_console,
            show_time=True,
            omit_repeated_times=False,
            show_level=True,
            show_path=False,
            markup=False,
            rich_tracebacks=True,
            log_time_format="[%H:%M:%S]",
            level=level,
        )
        _stdout_rh.setFormatter(logging.Formatter("%(message)s"))
        _stdout_rh.addFilter(lambda record: record.levelno < logging.ERROR)
        _rh.addFilter(lambda record: record.levelno >= logging.ERROR)
        logger.addHandler(_stdout_rh)

    logger.addHandler(_rh)

    pretty_install(console=console)
    traceback_install(console=console, show_locals=False, max_frames=16, word_wrap=False)


STARTUP_WARNINGS = []


def log_startup_warning(msg):
    logging.warning(msg)
    STARTUP_WARNINGS.append(msg)


def print_startup_warnings():
    for s in STARTUP_WARNINGS:
        logging.warning(s)
    STARTUP_WARNINGS.clear()
