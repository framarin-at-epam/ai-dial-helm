import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _render(chart_path: Path) -> str:
    result = subprocess.run(
        ["helm", "template", "dial", str(chart_path)],
        capture_output=True,
        check=True,
        cwd=REPO_ROOT,
        text=True,
    )
    return result.stdout


def test_default_rendering_does_not_set_fixed_replicas():
    chart_paths = [
        REPO_ROOT / "charts/dial",
        REPO_ROOT / "charts/dial-core",
        REPO_ROOT / "charts/dial-extension",
        #REPO_ROOT / "charts/dial-admin",
        REPO_ROOT / "charts/dial-ollama/ollama",
    ]

    for chart_path in chart_paths:
        rendered = _render(chart_path)
        assert "replicas:" not in rendered, f"{chart_path.relative_to(REPO_ROOT)} still renders a fixed replica count"


def test_ollama_model_pull_hook_is_best_effort():
    job_template = (REPO_ROOT / "charts/dial-ollama/ollama/templates/model-job.yaml").read_text(encoding="utf-8")
    assert "ollama pull" in job_template
    hook_text = job_template.lower()
    assert "continuing without blocking" in hook_text or "|| true" in job_template or "continue on error" in hook_text


def test_valkey_uses_openshift_safe_security_context():
    rendered = _render(REPO_ROOT / "charts/dial-core")
    assert "hostUsers: false" not in rendered
    assert "seccompProfile:" in rendered
    assert "fsGroup: 1000" not in rendered
    assert "runAsUser: 1000" not in rendered
    assert "runAsGroup: 1000" not in rendered


def test_ollama_uses_writable_home_directory():
    rendered = _render(REPO_ROOT / "charts/dial-ollama/ollama")
    assert "OLLAMA_HOME" in rendered
    assert "/tmp/ollama" in rendered
    assert "/root/.ollama" not in rendered


def test_ollama_pvc_name_matches_release_name():
    static_manifest = (REPO_ROOT / "charts/dial-ollama/ollama/ollama.yaml").read_text(encoding="utf-8")
    assert "claimName: ollama-data" not in static_manifest
    assert "claimName: {{ .Release.Name }}-ollama-data" in static_manifest
    assert "name: {{ .Release.Name }}-ollama-data" in static_manifest
