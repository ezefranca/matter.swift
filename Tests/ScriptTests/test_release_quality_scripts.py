from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]


def load_script(name: str):
    path = REPOSITORY / "Scripts" / f"{name}.py"
    specification = importlib.util.spec_from_file_location(name, path)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


dependencies = load_script("check_dependency_policy")
links = load_script("check_links")
release_manifest = load_script("create_release_manifest")
workflow_security = load_script("check_workflow_security")


class DependencyPolicyTests(unittest.TestCase):
    def test_flattens_transitive_dependencies(self) -> None:
        graph = {
            "dependencies": [
                {
                    "identity": "testing",
                    "dependencies": [
                        {"identity": "syntax", "dependencies": []}
                    ],
                }
            ]
        }
        self.assertEqual(
            list(dependencies.flatten_dependencies(graph)),
            ["testing", "syntax"],
        )

    def test_rejects_missing_and_duplicate_identities(self) -> None:
        with self.assertRaises(ValueError):
            dependencies.flatten_dependencies({"dependencies": [{}]})
        with self.assertRaises(ValueError):
            dependencies.flatten_dependencies(
                {
                    "dependencies": [
                        {"identity": "same", "dependencies": []},
                        {"identity": "same", "dependencies": []},
                    ]
                }
            )

    def test_recognizes_only_an_apache_2_license(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            with self.assertRaises(ValueError):
                dependencies.license_identifier(root)
            (root / "LICENSE").write_text(
                "Apache License\nVersion 2.0, January 2004\n",
                encoding="utf-8",
            )
            self.assertEqual(dependencies.license_identifier(root), "Apache-2.0")
            (root / "LICENSE").write_text("MIT License\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                dependencies.license_identifier(root)


class LinkTests(unittest.TestCase):
    def test_normalizes_github_style_heading_anchors(self) -> None:
        self.assertEqual(links.anchor("`Metal` & Core ML"), "metal-core-ml")
        self.assertEqual(links.anchor("  First--Sketch!  "), "first-sketch")

    def test_reports_missing_files_and_anchors_and_collects_urls(self) -> None:
        original_repository = links.REPOSITORY
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            links.REPOSITORY = root
            self.addCleanup(setattr, links, "REPOSITORY", original_repository)
            (root / "target.md").write_text("# Existing heading\n", encoding="utf-8")
            (root / "source.md").write_text(
                "[ok](target.md#existing-heading)\n"
                "[bad anchor](target.md#absent)\n"
                "[bad file](missing.md)\n"
                "[web](https://example.com/reference)\n",
                encoding="utf-8",
            )
            failures, external = links.local_failures()

        self.assertEqual(len(failures), 2)
        self.assertTrue(any("missing anchor" in failure for failure in failures))
        self.assertTrue(any("missing missing.md" in failure for failure in failures))
        self.assertEqual(external, {"https://example.com/reference"})


class ReleaseManifestTests(unittest.TestCase):
    def test_sha256_streams_file_contents(self) -> None:
        with tempfile.NamedTemporaryFile() as temporary:
            temporary.write(b"p5.swift\n")
            temporary.flush()
            self.assertEqual(
                release_manifest.sha256(Path(temporary.name)),
                "b12463ab89430b558c2d6519f93ada15306f3a191b2cc4b6f37401e3683195db",
            )


class WorkflowSecurityTests(unittest.TestCase):
    def test_accepts_commit_pins_and_rejects_tags_or_missing_permissions(self) -> None:
        commit = "a" * 40
        self.assertEqual(
            workflow_security.failures_for(
                f"permissions:\n  contents: read\nsteps:\n  - uses: actions/example@{commit}\n",
                "safe.yml",
            ),
            [],
        )
        failures = workflow_security.failures_for(
            "steps:\n  - name: Unsafe\n    uses: actions/example@v1\n",
            "unsafe.yml",
        )
        self.assertEqual(len(failures), 2)
        self.assertTrue(any("not pinned" in failure for failure in failures))
        self.assertTrue(any("permissions" in failure for failure in failures))


if __name__ == "__main__":
    unittest.main()
