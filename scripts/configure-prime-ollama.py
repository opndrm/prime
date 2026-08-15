#!/usr/bin/env python3
"""Merge local Ollama discovery into Prime Agent without changing defaults."""
import json, sys
from pathlib import Path
from urllib.request import urlopen

config_dir = Path(sys.argv[1]).expanduser()
with urlopen("http://127.0.0.1:11434/api/tags", timeout=5) as response:
    models = [item["name"] for item in json.load(response).get("models", []) if item.get("name")]
if not models:
    raise SystemExit("Ollama is reachable but has no available models. Sign in/configure Ollama, then rerun this installer; no model was downloaded.")
models_path = config_dir / "models.json"
settings_path = config_dir / "settings.json"
existing = json.loads(models_path.read_text()) if models_path.exists() else {"providers": {}}
existing.setdefault("providers", {})["ollama"] = {
    "name": "Ollama (local)", "baseUrl": "http://127.0.0.1:11434/v1",
    "api": "openai-completions", "apiKey": "ollama",
    "compat": {"supportsDeveloperRole": False, "supportsReasoningEffort": False},
    "models": [{"id": model, "name": model, "contextWindow": 32768, "maxTokens": 4096} for model in models],
}
config_dir.mkdir(parents=True, exist_ok=True)
models_path.write_text(json.dumps(existing, indent=2) + "\n")
settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
enabled = settings.setdefault("enabledModels", [])
for model in models:
    item = f"ollama/{model}"
    if item not in enabled: enabled.append(item)
settings_path.write_text(json.dumps(settings, indent=2) + "\n")
print(f"Registered {len(models)} existing Ollama model(s) with Prime Agent; existing default unchanged.")
