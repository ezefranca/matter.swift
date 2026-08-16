from __future__ import annotations

import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]
MODULE_PATH = REPOSITORY / "Scripts" / "check_privacy_manifests.py"
SPEC = importlib.util.spec_from_file_location("check_privacy_manifests", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
privacy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(privacy)


class PrivacyManifestTests(unittest.TestCase):
    def write_manifest(self, payload: dict[str, object]) -> Path:
        temporary = tempfile.NamedTemporaryFile(suffix=".xcprivacy", delete=False)
        self.addCleanup(Path(temporary.name).unlink, missing_ok=True)
        with temporary:
            plistlib.dump(payload, temporary)
        return Path(temporary.name)

    def test_accepts_minimal_manifest_and_required_reason(self) -> None:
        path = self.write_manifest(
            {
                "NSPrivacyAccessedAPITypes": [
                    {
                        "NSPrivacyAccessedAPIType": "system-time",
                        "NSPrivacyAccessedAPITypeReasons": ["reason"],
                    }
                ],
                "NSPrivacyCollectedDataTypes": [],
                "NSPrivacyTracking": False,
            }
        )
        privacy.validate_manifest(path, {"system-time": {"reason"}})

    def test_rejects_invalid_top_level_and_access_entries(self) -> None:
        invalid_payloads = [
            {},
            {
                "NSPrivacyAccessedAPITypes": [],
                "NSPrivacyCollectedDataTypes": [],
                "NSPrivacyTracking": True,
            },
            {
                "NSPrivacyAccessedAPITypes": [],
                "NSPrivacyCollectedDataTypes": ["unexpected"],
                "NSPrivacyTracking": False,
            },
            {
                "NSPrivacyAccessedAPITypes": [{}],
                "NSPrivacyCollectedDataTypes": [],
                "NSPrivacyTracking": False,
            },
            {
                "NSPrivacyAccessedAPITypes": [
                    {
                        "NSPrivacyAccessedAPIType": 1,
                        "NSPrivacyAccessedAPITypeReasons": [],
                    }
                ],
                "NSPrivacyCollectedDataTypes": [],
                "NSPrivacyTracking": False,
            },
            {
                "NSPrivacyAccessedAPITypes": [
                    {
                        "NSPrivacyAccessedAPIType": "duplicate",
                        "NSPrivacyAccessedAPITypeReasons": ["one"],
                    },
                    {
                        "NSPrivacyAccessedAPIType": "duplicate",
                        "NSPrivacyAccessedAPITypeReasons": ["two"],
                    },
                ],
                "NSPrivacyCollectedDataTypes": [],
                "NSPrivacyTracking": False,
            },
        ]
        for payload in invalid_payloads:
            with self.subTest(payload=payload):
                with self.assertRaises(ValueError):
                    privacy.validate_manifest(self.write_manifest(payload), {})

        valid = self.write_manifest(
            {
                "NSPrivacyAccessedAPITypes": [],
                "NSPrivacyCollectedDataTypes": [],
                "NSPrivacyTracking": False,
            }
        )
        with self.assertRaises(ValueError):
            privacy.validate_manifest(valid, {"missing": {"reason"}})


if __name__ == "__main__":
    unittest.main()
