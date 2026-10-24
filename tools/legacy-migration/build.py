#!/usr/bin/env python3
"""Build an additive exporter against a private copy of the decoded old APK.

The old APK, decoded tree, signing key and password are never placed in this repo.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ANDROID = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID)


def run(*arguments: str | Path) -> None:
    subprocess.run([str(value) for value in arguments], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--decoded", type=Path, required=True)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--jdk", type=Path, required=True)
    parser.add_argument("--apktool", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True, help="New directory; existing paths are never deleted")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--keystore", type=Path, required=True)
    parser.add_argument("--alias", required=True)
    args = parser.parse_args()
    if not os.environ.get("EASY_MIGRATION_KEYSTORE_PASS"):
        parser.error("Set EASY_MIGRATION_KEYSTORE_PASS in the process environment")
    if args.output.exists():
        parser.error("Output already exists; choose a new filename")
    source = args.decoded.resolve(strict=True)
    if not (source / "apktool.yml").is_file() or not (source / "AndroidManifest.xml").is_file():
        parser.error("--decoded must name the old Apktool project directory")
    work = args.work.resolve()
    if work == source or source in work.parents:
        parser.error("--work must be outside the original decoded directory")
    if work.exists():
        parser.error("--work must be a new directory")
    android_jar = args.sdk / "platforms/android-36/android.jar"
    tools = args.sdk / "build-tools/36.0.0"
    java = args.jdk / "bin/java"
    javac = args.jdk / "bin/javac"
    for required in [android_jar, tools / "d8", java, javac, args.apktool, args.keystore]:
        if not required.is_file():
            parser.error(f"Missing tool/input: {required}")
    work.mkdir(parents=True)
    decoded = work / "decoded"
    shutil.copytree(source, decoded, ignore=shutil.ignore_patterns("build"))
    metadata = decoded / "apktool.yml"
    text = metadata.read_text(encoding="utf-8")
    previous = re.search(r"(?m)^\s*versionCode:\s*(\d+)\s*$", text)
    if previous is None or int(previous.group(1)) != 56:
        raise ValueError("Migration builder expects the verified code56 baseline")
    text = re.sub(r"(?m)^(\s*versionCode:)\s*\d+\s*$", r"\g<1> 57", text)
    text = re.sub(r"(?m)^(\s*versionName:).*$", r"\g<1> 3.1.5-migration", text)
    metadata.write_text(text, encoding="utf-8")
    manifest_file = decoded / "AndroidManifest.xml"
    manifest = ET.parse(manifest_file)
    application = manifest.getroot().find("application")
    if application is None:
        raise ValueError("Old manifest has no application")
    activity = ET.SubElement(application, "activity", {
        f"{{{ANDROID}}}name": "com.sidutech.express.migration.ExportActivity",
        f"{{{ANDROID}}}label": "导出旧版数据",
        f"{{{ANDROID}}}exported": "true",
        f"{{{ANDROID}}}theme": "@android:style/Theme.Material.Light.NoActionBar",
    })
    intent_filter = ET.SubElement(activity, "intent-filter")
    ET.SubElement(intent_filter, "action", {f"{{{ANDROID}}}name": "android.intent.action.MAIN"})
    ET.SubElement(intent_filter, "category", {f"{{{ANDROID}}}name": "android.intent.category.LAUNCHER"})
    ET.indent(manifest, space="    ")
    manifest.write(manifest_file, encoding="utf-8", xml_declaration=True)
    classes, dex = work / "java-classes", work / "exporter-dex"
    classes.mkdir()
    dex.mkdir()
    java_source = Path(__file__).parent / "src/com/sidutech/express/migration/ExportActivity.java"
    run(javac, "-encoding", "UTF-8", "-source", "8", "-target", "8", "-cp", android_jar, "-d", classes, java_source)
    run(tools / "d8", "--min-api", "26", "--lib", android_jar, "--output", dex, *sorted(classes.rglob("*.class")))
    unsigned = work / "migration-unsigned.apk"
    run(java, "-jar", args.apktool, "b", "-f", decoded, "-o", unsigned)
    with zipfile.ZipFile(unsigned, "a", compression=zipfile.ZIP_DEFLATED) as archive:
        indexes = [int(match.group(1) or "1") for name in archive.namelist()
                   if (match := re.fullmatch(r"classes(\d*)\.dex", name))]
        archive.write(dex / "classes.dex", f"classes{max(indexes, default=0) + 1}.dex")
    aligned = work / "migration-aligned.apk"
    run(tools / "zipalign", "-P", "16", "-f", "4", unsigned, aligned)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    signing = [tools / "apksigner", "sign", "--ks", args.keystore, "--ks-key-alias", args.alias,
               "--ks-pass", "env:EASY_MIGRATION_KEYSTORE_PASS"]
    if os.environ.get("EASY_MIGRATION_KEY_PASS"):
        signing += ["--key-pass", "env:EASY_MIGRATION_KEY_PASS"]
    run(*signing, "--out", args.output, aligned)
    run(tools / "apksigner", "verify", "--verbose", "--print-certs", args.output)
    run(tools / "zipalign", "-c", "-P", "16", "4", args.output)
    print(f"Migration code57 APK: {args.output}")


if __name__ == "__main__":
    main()
