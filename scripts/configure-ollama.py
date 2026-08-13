#!/usr/bin/env python3
import json
import sys
from urllib.request import urlopen
from pathlib import Path

catalog_path, config_dir = map(Path, sys.argv[1:])
catalog = json.loads(catalog_path.read_text())
starter = {model["id"]: model["name"] for model in catalog["starterModels"]}
with urlopen("http://127.0.0.1:11434/api/tags", timeout=5) as response:
    installed = [model["name"] for model in json.load(response).get("models", []) if model.get("name")]
model_ids = list(dict.fromkeys([*starter, *installed]))
models = [{"id": model, "name": starter.get(model, model)} for model in model_ids]
default = catalog["defaultModel"] if catalog["defaultModel"] in model_ids else model_ids[0]
config_dir.mkdir(parents=True, exist_ok=True)
(config_dir / "models.json").write_text(json.dumps({"providers": {"ollama": {"baseUrl": "http://localhost:11434/v1", "api": "openai-completions", "apiKey": "ollama", "compat": {"supportsDeveloperRole": False, "supportsReasoningEffort": False}, "models": models}}}, indent=2) + "\n")
(config_dir / "settings.json").write_text(json.dumps({"defaultProvider": "ollama", "defaultModel": default, "recentModels": [f"ollama/{model}" for model in model_ids]}, indent=2) + "\n")
print(f"Ollama provider ready with {len(models)} selectable model(s).")
