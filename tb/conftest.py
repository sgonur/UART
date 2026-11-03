import sys
from pathlib import Path

# Make tb/ importable (uart_params) for both pytest and cocotb test modules.
sys.path.insert(0, str(Path(__file__).resolve().parent))
