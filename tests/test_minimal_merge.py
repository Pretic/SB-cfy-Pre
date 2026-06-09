from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "sing-box.sh"


def script_text() -> str:
    if not SCRIPT.exists():
        raise AssertionError("sing-box.sh should exist at the project root")
    return SCRIPT.read_text(encoding="utf-8")


class MinimalMergeTests(unittest.TestCase):
    def test_cloudflare_optimizer_is_embedded_and_menu_accessible(self):
        text = script_text()

        self.assertIn("sb_cfy_check_deps()", text)
        self.assertIn("sb_cfy_update_vless_url()", text)
        self.assertIn("sb_cfy_update_vmess_url()", text)
        self.assertIn("run_cfy_generator()", text)
        self.assertIn("Cloudflare优选", text)
        self.assertTrue("11)  run_cfy_generator" in text or "11) run_cfy_generator" in text)
        self.assertIn("请输入选择(0-11)", text)

    def test_cloudflare_optimizer_uses_local_subscription_files_safely(self):
        text = script_text()

        self.assertIn('local cfy_output="${work_dir}/cfy.txt"', text)
        self.assertIn("append_unique_generated_urls", text)
        self.assertIn("backup_file=", text)
        self.assertIn('base64 -w0 "$client_dir" > "${work_dir}/sub.txt"', text)
        self.assertIn('chmod 644 "${work_dir}/sub.txt"', text)

    def test_cloudflare_optimizer_is_not_a_remote_cfy_wrapper(self):
        text = script_text()

        self.assertNotIn("/usr/local/bin/cfy", text)
        self.assertNotIn("INSTALL_PATH", text)
        self.assertNotIn("raw.githubusercontent.com/Pretic/Pre-cfy", text)
        self.assertNotIn("curl -Ls https://raw.githubusercontent.com/Pretic/Pre-cfy", text)

    def test_cloudflare_optimizer_has_stable_quality_controls(self):
        text = script_text()

        self.assertIn("sb_cfy_select_wetest_category()", text)
        self.assertIn("sb_cfy_match_isp_category()", text)
        self.assertIn("sb_cfy_select_generate_count()", text)
        self.assertIn("sb_cfy_load_imported_edges()", text)
        self.assertIn("导入本地测速结果", text)
        self.assertIn("默认20", text)

    def test_local_speedtest_helpers_and_ci_are_present(self):
        self.assertTrue((ROOT / "tools" / "cfst-local.sh").exists())
        self.assertTrue((ROOT / "tools" / "cfst-local.ps1").exists())
        self.assertTrue((ROOT / ".github" / "workflows" / "ci.yml").exists())


if __name__ == "__main__":
    unittest.main()
