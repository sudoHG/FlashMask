#!/usr/bin/env python3
"""Validate complete local resources and package only their paired Bundle localizations."""

import argparse
import json
from pathlib import Path
import re
import shutil
import sys


METADATA = {
    "en": ("English", "en", "en"),
    "zh": ("简体中文", "zh-Hans", "zh-Hans"),
    "ja": ("日本語", "ja", "ja"),
    "de": ("Deutsch", "de", "de"),
    "fr": ("Français", "fr", "fr"),
    "es": ("Español", "es", "es"),
    "zh-Hant": ("繁體中文", "zh-Hant", "zh-Hant"),
}
ROOT_KEYS = {"schema_version", "locale", "native_name", "html_lang", "bundle_localization", "strings"}
TOKENS = {
    "dynamic.regionCount.one": ["count"],
    "dynamic.regionCount.other": ["count"],
    "dynamic.regionLabel": ["id"],
    "native.paste.chooseLocationBody": ["error"],
    "native.update.available": ["version"],
    "native.update.incompatible": ["minimum_os", "version"],
    "native.version.withBuild": ["build", "version"],
    "native.version.withoutBuild": ["version"],
}
HTML_KEYS = {"editor.guideTitle", "editor.guideSubtitle"}
TOKEN = re.compile(r"\{([a-z_]+)\}")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate key: {key}")
        result[key] = value
    return result


def read_resource(file):
    with file.open(encoding="utf-8") as stream:
        resource = json.load(stream, object_pairs_hook=unique_object)
    if not isinstance(resource, dict) or set(resource) != ROOT_KEYS:
        raise ValueError(f"{file.name}: invalid resource fields")
    locale = resource["locale"]
    if not isinstance(locale, str) or locale not in METADATA or file.stem != locale:
        raise ValueError(f"{file.name}: invalid locale")
    name, language, bundle = METADATA[locale]
    if type(resource["schema_version"]) is not int or resource["schema_version"] != 1:
        raise ValueError(f"{file.name}: invalid schema version")
    if (resource["native_name"], resource["html_lang"], resource["bundle_localization"]) != (name, language, bundle):
        raise ValueError(f"{file.name}: invalid locale metadata")
    strings = resource["strings"]
    if not isinstance(strings, dict) or len(strings) != 132:
        raise ValueError(f"{file.name}: expected 132 strings")
    required = set(TOKENS) | HTML_KEYS | {
        "editor.aria.areaTabs", "editor.aria.chooseLanguage", "native.language.system", "native.panel.open", "native.panel.save"
    }
    if not required <= set(strings):
        raise ValueError(f"{file.name}: missing required keys")
    for key, value in strings.items():
        if not key.startswith(("native.", "editor.", "dynamic.")) or not isinstance(value, str) or not value.strip():
            raise ValueError(f"{file.name}: invalid string {key}")
        if sorted(TOKEN.findall(value)) != sorted(TOKENS.get(key, [])):
            raise ValueError(f"{file.name}: placeholder mismatch {key}")
        without_tokens = TOKEN.sub("", value)
        if "{" in without_tokens or "}" in without_tokens:
            raise ValueError(f"{file.name}: invalid placeholder {key}")
        if key in HTML_KEYS and value.count("<br>") != 1:
            raise ValueError(f"{file.name}: expected one line break in {key}")
        plain = value.replace("<br>", "") if key in HTML_KEYS else value
        if "<" in plain or ">" in plain:
            raise ValueError(f"{file.name}: unexpected markup {key}")
    return resource


def validated_resources(repo):
    sources = repo / "src" / "localizations"
    resources = {file.stem: read_resource(file) for file in sorted(sources.glob("*.json"))}
    if not {"en", "zh"} <= resources.keys():
        raise ValueError("complete English and Simplified Chinese resources are required")
    expected = set(resources["en"]["strings"])
    for locale, resource in resources.items():
        if set(resource["strings"]) != expected:
            raise ValueError(f"{locale}.json: key set differs from English")
        bundle = resource["bundle_localization"]
        if not (repo / "macos" / f"{bundle}.lproj" / "InfoPlist.strings").is_file():
            raise ValueError(f"{locale}.json: missing {bundle}.lproj/InfoPlist.strings")
    paired = {f'{resource["bundle_localization"]}.lproj' for resource in resources.values()}
    unpaired = {directory.name for directory in (repo / "macos").glob("*.lproj")} - paired
    if unpaired:
        raise ValueError(f"localization directories without complete JSON: {', '.join(sorted(unpaired))}")
    return resources


def package(repo, destination, resources):
    # This directory belongs to the generated bundle; remove stale locale files after a language is removed.
    target = destination / "src" / "localizations"
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)
    for locale in resources:
        shutil.copy2(repo / "src" / "localizations" / f"{locale}.json", target / f"{locale}.json")
    paired = {f'{resource["bundle_localization"]}.lproj' for resource in resources.values()}
    for directory in destination.glob("*.lproj"):
        if directory.name not in paired:
            shutil.rmtree(directory)
    for name in paired:
        target = destination / name
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(repo / "macos" / name, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--resources", type=Path, help="generated bundle Resources directory; omit to validate only")
    args = parser.parse_args()
    try:
        repo = args.repo_root.resolve()
        resources = validated_resources(repo)
        if args.resources:
            destination = args.resources.resolve()
            if destination.name != "Resources" or destination.parent.name != "Contents" or destination.parent.parent.suffix != ".app":
                raise ValueError("destination must be a generated .app/Contents/Resources directory")
            package(repo, destination, resources)
        print(json.dumps({
            "locales": sorted(resources),
            "bundle_localizations": sorted(resource["bundle_localization"] for resource in resources.values()),
            "keys_per_locale": 132,
        }, ensure_ascii=False))
    except (OSError, ValueError, TypeError) as error:
        print(f"localization validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
