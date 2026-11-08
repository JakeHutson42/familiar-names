"""Run the addon in Lua 5.1 against a small, strict WoW API fixture.

Install the test-only runtime with: python -m pip install --target .tools lupa
Then run: python tests/run.py
"""
from pathlib import Path
import os
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools"))
from lupa.lua51 import LuaRuntime

os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True)
for source in (ROOT / "FamiliarNames").glob("*.lua"):
    lua.execute("assert(loadstring(...))", source.read_text(encoding="utf-8"))
lua.execute((ROOT / "tests" / "addon_test.lua").read_text(encoding="utf-8"))
