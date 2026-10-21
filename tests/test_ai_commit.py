"""Offline integration tests. Git, AI providers and the editor are test doubles."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CommitFlowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.scripts = self.base / "scripts"
        self.scripts.mkdir()
        for source in (ROOT / "lazygit/scripts").glob("*.sh"):
            code = source.read_text()
            if source.name == "ai-commit.sh":
                # Adapt only TTY I/O and countdowns for a noninteractive test runner.
                start = code.index("wait_and_exit() {")
                end = code.index('\ncase "$AI_COMMIT_PROVIDER"', start)
                code = code[:start] + 'wait_and_exit() { echo wait >> "$TEST_LOG"; exit "${2:-0}"; }\n' + code[end:]
                code = code.replace(' < /dev/tty > /dev/tty', '')
            (self.scripts / source.name).write_text(code)
        self.log = self.base / "calls"
        self.env = {"HOME": str(self.base), "PATH": f"{self.bin}:/usr/bin:/bin",
                    "TMPDIR": str(self.base), "TEST_LOG": str(self.log),
                    "EDITOR": str(self.bin / "editor"), "AI_COMMIT_PROVIDER": "codex"}
        self.write("zsh", 'exit 0')
        self.write("sleep", 'echo sleep >> "$TEST_LOG"; exit 0')
        self.write("git", '''printf 'git %s\\n' "$*" >> "$TEST_LOG"
if [ "$1" = diff ]; then
  [ "$TEST_NO_STAGE" = 1 ] && exit 0
  if [ "$3" = --name-only ]; then echo file.lua; else printf 'diff --git a/file.lua b/file.lua\\n+change\\n+last\\n'; fi
else
  cat "${@: -1}" > "$HOME/committed"
  exit "${TEST_COMMIT_EXIT:-0}"
fi''')
        self.write("codex", '''printf 'codex %s\\n' "$*" >> "$TEST_LOG"
[ "$1" = login ] && exit "${TEST_AUTH_EXIT:-0}"
cat > "$HOME/prompt"
printf 'diff --git a/file.lua b/file.lua\\n+change\\n' >&2
[ "$TEST_CODEX_FAIL" = 1 ] && exit 1
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output-last-message ]; then shift; printf '%s' "${TEST_MESSAGE-fix: update file}" > "$1"; fi
  shift
done''')
        self.write("agy", '''printf 'agy %s\\n' "$*" >> "$TEST_LOG"
[ -z "$GEMINI_API_KEY$GOOGLE_API_KEY" ] || exit 1
pwd > "$HOME/agy-cwd"
cat > "$HOME/agy-request"
if [ "$TEST_AGY_FAIL" = 1 ]; then echo 'authentication required' >&2; exit 1; fi
if [ "$TEST_AGY_MALFORMED" = 1 ]; then echo 'not json'; exit 0; fi
printf '%s\\n' '{"event":"init"}'
jq -nc --arg status "${TEST_AGY_STATUS:-SUCCESS}" --arg message "${TEST_MESSAGE-fix: update file}" '{event:"result",result:{status:$status,response:$message,error:"test diagnostic"}}'
[ "$TEST_AGY_DUPLICATE" != 1 ] || echo '{"event":"result","result":{"status":"SUCCESS","response":"fix: other"}}'
exit 0''')
        self.write("editor", '''echo editor >> "$TEST_LOG"
[ "$TEST_EDITOR_EMPTY" = 1 ] && printf '# comments only\\n' > "$1"
exit "${TEST_EDITOR_EXIT:-0}"''')
        self.write("curl", '''echo curl >> "$TEST_LOG"
printf '%s' '{"candidates":[{"content":{"parts":[{"text":"fix: update file"}]}}]}' ''')
        # Use the installed jq only for the Gemini response/payload, with no network.
        jq = shutil.which("jq")
        self.jq = jq
        if jq:
            (self.bin / "jq").symlink_to(jq)

    def write(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def run_flow(self, entry="ai-commit.sh", **settings):
        env = dict(self.env, **settings)
        result = subprocess.run(["/bin/bash", str(self.scripts / entry)], env=env,
                                capture_output=True, text=True, timeout=10)
        code = result.returncode
        self.output = result.stdout + result.stderr
        calls = self.log.read_text() if self.log.exists() else ""
        self.assertFalse(list(self.base.glob("ai_commit_*")), "temporary files leaked")
        return code, calls

    def test_codex_without_gemini_key_and_model_override(self):
        code, calls = self.run_flow(CODEX_COMMIT_MODEL="test-model", AI_COMMIT_MAX_DIFF_LINES="2")
        self.assertEqual(code, 0)
        self.assertIn("--sandbox read-only", calls)
        self.assertIn("--model test-model", calls)
        self.assertIn("--ephemeral", calls)
        self.assertIn("git commit --cleanup=strip -F", calls)
        self.assertNotIn("curl", calls)
        self.assertNotIn("+last", (self.base / "prompt").read_text())
        self.assertTrue((self.base / "committed").read_text().startswith("fix: update file\n"))
        self.assertNotIn("diff --git", self.output)
        self.assertNotIn("wait", calls)

    def test_codex_failure_shows_diagnostics(self):
        code, calls = self.run_flow(TEST_CODEX_FAIL="1")
        self.assertEqual(code, 1)
        self.assertIn("diff --git", self.output)
        self.assertNotIn("editor", calls)
        self.assertNotIn("git commit", calls)

    def test_antigravity_session_model_and_isolated_workspace(self):
        if not self.jq:
            self.skipTest("jq is required for Antigravity tests")
        code, calls = self.run_flow(
            AI_COMMIT_PROVIDER="antigravity", ANTIGRAVITY_COMMIT_MODEL="test-model",
            ANTIGRAVITY_COMMIT_BIN=str(self.bin / "agy"),
            AI_COMMIT_MAX_DIFF_LINES="2", GEMINI_API_KEY="existing-key")
        self.assertEqual(code, 0, self.output)
        self.assertIn("--model test-model", calls)
        self.assertIn("--sandbox", calls)
        self.assertIn("--print-timeout 60s", calls)
        self.assertIn("--disable-slash-commands", calls)
        self.assertNotIn("--dangerously-skip-permissions", calls)
        self.assertNotIn("curl", calls)
        self.assertNotIn("codex", calls)
        self.assertIn("git commit --cleanup=strip -F", calls)
        request = (self.base / "agy-request").read_text()
        self.assertNotIn("+last", request)
        self.assertIn("diff --git", request)
        self.assertNotIn("diff --git", self.output)
        workspace = Path((self.base / "agy-cwd").read_text().strip())
        self.assertEqual(workspace.parent.resolve(), self.base.resolve())
        self.assertFalse(workspace.exists())

    def test_antigravity_failures_never_commit_or_switch_provider(self):
        if not self.jq:
            self.skipTest("jq is required for Antigravity tests")
        for settings in ({"TEST_AGY_FAIL": "1"}, {"TEST_AGY_STATUS": "ERROR"},
                         {"TEST_AGY_MALFORMED": "1"}, {"TEST_AGY_DUPLICATE": "1"},
                         {"TEST_MESSAGE": ""}, {"TEST_MESSAGE": "fix: first\nextra"},
                         {"ANTIGRAVITY_COMMIT_BIN": "missing-agy"},
                         {"ANTIGRAVITY_COMMIT_TIMEOUT": "0s"}):
            with self.subTest(settings=settings):
                self.log.write_text("")
                code, calls = self.run_flow(AI_COMMIT_PROVIDER="antigravity", **settings)
                self.assertEqual(code, 1, self.output)
                self.assertNotIn("editor", calls)
                self.assertNotIn("git commit", calls)
                self.assertNotIn("curl", calls)
                self.assertNotIn("codex", calls)

    def test_gemini_retries_and_fallbacks_are_preserved(self):
        if not self.jq:
            self.skipTest("jq is required for Gemini tests")
        self.write("curl", '''printf 'curl %s\\n' "$*" >> "$TEST_LOG"
count=0
[ ! -f "$HOME/curl-count" ] || read -r count < "$HOME/curl-count"
count=$((count + 1))
echo "$count" > "$HOME/curl-count"
if [ "$count" -lt 4 ]; then
  echo '{"error":{"code":429,"message":"busy"}}'
else
  echo '{"candidates":[{"content":{"parts":[{"text":"fix: update file"}]}}]}'
fi''')
        code, calls = self.run_flow(
            AI_COMMIT_PROVIDER="gemini", GEMINI_API_KEY="test-key",
            GEMINI_MODEL="primary", GEMINI_FALLBACK_MODELS="secondary", GEMINI_MAX_RETRIES="2")
        self.assertEqual(code, 0, self.output)
        models = [line.split("/models/")[1].split(":")[0]
                  for line in calls.splitlines() if line.startswith("curl ")]
        self.assertEqual(models, ["primary", "secondary", "primary", "secondary"])
        self.assertIn("sleep", calls)
        self.assertIn("git commit", calls)

    def test_exit_timeout_does_not_sleep_again(self):
        source = (ROOT / "lazygit/scripts/ai-commit.sh").read_text()
        start = source.index("wait_and_exit() {")
        end = source.index('\ncase "$AI_COMMIT_PROVIDER"', start)
        helper = source[start:end].replace("/dev/tty", "/dev/null")
        # Simulate read timing out after its own wait, without a real terminal.
        result = subprocess.run(
            ["/bin/bash", "-c", 'read() { return 142; }\n' + helper + '\nwait_and_exit 1 7'],
            env=self.env, capture_output=True, text=True, timeout=2)
        self.assertEqual(result.returncode, 7)
        self.assertFalse(self.log.exists())

    def test_abort_and_failures_never_commit(self):
        for settings in ({"TEST_EDITOR_EXIT": "1"}, {"TEST_EDITOR_EMPTY": "1"},
                         {"TEST_CODEX_FAIL": "1"}, {"TEST_AUTH_EXIT": "1"},
                         {"TEST_MESSAGE": ""}, {"TEST_MESSAGE": "fix: first\nextra"},
                         {"AI_COMMIT_PROVIDER": "unknown"}, {"AI_COMMIT_MAX_DIFF_LINES": "00"},
                         {"TEST_NO_STAGE": "1"}):
            with self.subTest(settings=settings):
                self.log.write_text("")
                _, calls = self.run_flow(**settings)
                self.assertNotIn("git commit", calls)
                self.assertNotIn("curl", calls)

    def test_commit_failure_propagates(self):
        code, _ = self.run_flow(TEST_COMMIT_EXIT="3")
        self.assertEqual(code, 3)

    def test_gemini_default_and_legacy_entry(self):
        if not self.jq:
            self.skipTest("jq is required for Gemini tests")
        self.env.pop("AI_COMMIT_PROVIDER")
        code, calls = self.run_flow(GEMINI_API_KEY="test-key")
        self.assertEqual(code, 0)
        self.assertIn("curl", calls)
        self.assertNotIn("codex", calls)
        self.log.write_text("")
        code, calls = self.run_flow("gemini-commit.sh", AI_COMMIT_PROVIDER="codex", GEMINI_API_KEY="test-key")
        self.assertEqual(code, 0)
        self.assertIn("curl", calls)
        self.assertNotIn("codex", calls)

    def test_codex_installer_preserves_shell_config(self):
        repo = self.base / "repo"
        repo.mkdir()
        shutil.copytree(ROOT / "lazygit", repo / "lazygit")
        shutil.copy(ROOT / "setup_lazygit.sh", repo / "setup_lazygit.sh")
        self.write("lazygit", "exit 0")
        rc = self.base / ".zshrc"
        rc.write_text('export AI_COMMIT_PROVIDER="codex"\n')
        before = rc.read_text()
        result = subprocess.run(["/bin/bash", str(repo / "setup_lazygit.sh")],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(rc.read_text(), before)
        self.assertEqual((repo / "lazygit/config.yml").read_text(), (ROOT / "lazygit/config.yml").read_text())
        self.assertTrue((self.base / ".config/lazygit").is_symlink())

    def test_real_zsh_settings_and_inherited_precedence(self):
        # Real Zsh parses Zsh-only syntax. No real user startup files are loaded.
        (self.bin / "zsh").unlink()
        (self.base / ".zshrc").write_text('typeset -a values=(codex gemini)\nexport AI_COMMIT_PROVIDER=$values[1]\nexport CODEX_COMMIT_MODEL="shell-model"\nexport PATH="$HOME/bin:$PATH"\n')
        self.env.pop("AI_COMMIT_PROVIDER")
        code, calls = self.run_flow()
        self.assertEqual(code, 0)
        self.assertIn("--model shell-model", calls)
        self.log.write_text("")
        code, calls = self.run_flow(AI_COMMIT_PROVIDER="unknown", CODEX_COMMIT_MODEL="inherited-model")
        self.assertNotEqual(code, 0)
        self.assertNotIn("codex", calls)

    def test_antigravity_shell_settings_and_installer(self):
        if not self.jq:
            self.skipTest("jq is required for Antigravity tests")
        (self.bin / "zsh").unlink()
        rc = self.base / ".zshrc"
        rc.write_text('export AI_COMMIT_PROVIDER="antigravity"\n'
                      'export ANTIGRAVITY_COMMIT_MODEL="shell-model"\n'
                      'export ANTIGRAVITY_COMMIT_TIMEOUT="30s"\n')
        self.env.pop("AI_COMMIT_PROVIDER")
        code, calls = self.run_flow()
        self.assertEqual(code, 0, self.output)
        self.assertIn("--model shell-model", calls)
        self.assertIn("--print-timeout 30s", calls)
        repo = self.base / "repo"
        repo.mkdir()
        shutil.copytree(ROOT / "lazygit", repo / "lazygit")
        shutil.copy(ROOT / "setup_lazygit.sh", repo / "setup_lazygit.sh")
        self.write("lazygit", "exit 0")
        before = rc.read_text()
        self.log.write_text("")
        result = subprocess.run(["/bin/bash", str(repo / "setup_lazygit.sh")],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(rc.read_text(), before)
        self.assertTrue((self.base / ".config/lazygit").is_symlink())
        self.assertEqual(self.log.read_text(), "")


if __name__ == "__main__":
    unittest.main()
