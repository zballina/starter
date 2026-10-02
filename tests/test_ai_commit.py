"""Offline integration tests. Git, Codex, curl and the editor are test doubles."""
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
                code = code[:start] + 'wait_and_exit() { exit "${2:-0}"; }\n' + code[end:]
                code = code.replace(' < /dev/tty > /dev/tty', '')
            (self.scripts / source.name).write_text(code)
        self.log = self.base / "calls"
        self.env = {"HOME": str(self.base), "PATH": f"{self.bin}:/usr/bin:/bin",
                    "TMPDIR": str(self.base), "TEST_LOG": str(self.log),
                    "EDITOR": str(self.bin / "editor"), "AI_COMMIT_PROVIDER": "codex"}
        self.write("zsh", 'exit 0')
        self.write("sleep", 'exit 0')
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
[ "$TEST_CODEX_FAIL" = 1 ] && exit 1
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output-last-message ]; then shift; printf '%s' "${TEST_MESSAGE-fix: update file}" > "$1"; fi
  shift
done''')
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


if __name__ == "__main__":
    unittest.main()
