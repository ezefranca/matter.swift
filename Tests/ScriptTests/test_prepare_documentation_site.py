from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[2]
MODULE_PATH = REPOSITORY / "Scripts" / "prepare_documentation_site.py"
SPEC = importlib.util.spec_from_file_location("prepare_documentation_site", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
prepare = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(prepare)


class DocumentationSiteTests(unittest.TestCase):
    def test_builds_product_routes_and_agent_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            site = Path(temporary_directory) / "site"
            data = site / "data" / "documentation"
            data.mkdir(parents=True)
            (site / "index.html").write_text(
                "<html><head><title>Documentation</title></head></html>",
                encoding="utf-8",
            )
            slugs = [module["slug"] for module in prepare.MODULES]
            names = [module["name"] for module in prepare.MODULES]
            for module in slugs:
                document = {
                    "abstract": [{"type": "text", "text": f"{module} summary"}],
                    "kind": "article",
                    "metadata": {"title": module.upper()},
                    "variants": [{"paths": [f"/documentation/{module}"]}],
                }
                (data / f"{module}.json").write_text(
                    json.dumps(document),
                    encoding="utf-8",
                )

            arguments = [
                str(MODULE_PATH),
                "--site",
                str(site),
                "--base-url",
                "https://example.com/p5.swift",
                "--version",
                "1.2.3",
                "--repository-root",
                str(REPOSITORY),
                "--repository-url",
                "https://github.com/example/p5.swift",
            ]
            with mock.patch.object(sys, "argv", arguments):
                prepare.main()

            landing = (site / "index.html").read_text(encoding="utf-8")
            for module in names:
                self.assertIn(f">{module}</h2>", landing)
            for module in slugs:
                route = site / "documentation" / module / "index.html"
                self.assertTrue(route.is_file())
                self.assertIn("rel=\"canonical\"", route.read_text(encoding="utf-8"))

            context = json.loads(
                (site / "agent-context.json").read_text(encoding="utf-8")
            )
            self.assertEqual(context["schemaVersion"], 2)
            self.assertEqual(
                [product["name"] for product in context["products"]],
                names,
            )
            llms = (site / "llms.txt").read_text(encoding="utf-8")
            for module in slugs:
                self.assertIn(f"/documentation/{module}/", llms)
            sitemap = (site / "sitemap.xml").read_text(encoding="utf-8")
            self.assertEqual(sitemap.count("<url>"), len(slugs))
            self.assertTrue((site / ".nojekyll").is_file())
            self.assertTrue((site / "404.html").is_file())


if __name__ == "__main__":
    unittest.main()
