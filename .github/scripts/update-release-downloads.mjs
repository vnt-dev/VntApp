import { execFileSync } from "node:child_process";
import {
  existsSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const START_MARKER = "<!-- vnt-android-downloads:start -->";
const END_MARKER = "<!-- vnt-android-downloads:end -->";

const APK_TARGETS = [
  ["通用（ARM64 / ARMv7 / x86_64）", "universal"],
  ["ARM64", "arm64-v8a"],
  ["ARMv7", "armeabi-v7a"],
  ["x86_64", "x86_64"],
];

export function buildDownloadSection({ tag, releaseUrl, assetNames }) {
  const rows = APK_TARGETS.flatMap(([architecture, abi]) => {
    const filename = `VNT-Android-${tag}-${abi}.apk`;
    if (!assetNames.has(filename)) return [];
    const url = `${releaseUrl}/${encodeURIComponent(filename)}`;
    return [`| VNT Android | Android | ${architecture} (${abi}) | [APK](${url}) |`];
  });

  if (rows.length === 0) return undefined;

  return [
    START_MARKER,
    "## 下载",
    "",
    "| 产品 | 平台 | 架构 | 下载 |",
    "|---|---|---|---|",
    ...rows,
    END_MARKER,
  ].join("\n");
}

export function mergeDownloadSection(notes, section) {
  const start = notes.indexOf(START_MARKER);
  if (start === -1) {
    const existing = notes.trimEnd();
    return existing.length === 0 ? `${section}\n` : `${existing}\n\n${section}\n`;
  }

  const end = notes.indexOf(END_MARKER, start);
  if (end === -1) {
    throw new Error("release notes contain an incomplete download section");
  }

  return `${notes.slice(0, start)}${section}${notes.slice(end + END_MARKER.length)}`;
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function main() {
  const repository = requiredEnv("GITHUB_REPOSITORY");
  const tag = requiredEnv("APP_TAG");
  const serverUrl = requiredEnv("GITHUB_SERVER_URL").replace(/\/$/, "");
  const release = JSON.parse(
    execFileSync(
      "gh",
      ["api", `repos/${repository}/releases/tags/${tag}`],
      { encoding: "utf8", env: process.env, windowsHide: true },
    ),
  );

  const assetNames = new Set(release.assets.map((asset) => asset.name));
  const releaseUrl = `${serverUrl}/${repository}/releases/download/${tag}`;
  const section = buildDownloadSection({ tag, releaseUrl, assetNames });
  if (!section) throw new Error(`release ${tag} does not contain recognized APKs`);

  const notes = release.body || "";
  const updatedNotes = mergeDownloadSection(notes, section);
  if (updatedNotes === notes) return;

  const notesFile = join(
    process.env.RUNNER_TEMP || tmpdir(),
    `vnt-android-release-notes-${process.pid}.md`,
  );
  try {
    writeFileSync(notesFile, updatedNotes);
    execFileSync(
      "gh",
      ["release", "edit", tag, "--repo", repository, "--notes-file", notesFile],
      { stdio: "inherit", env: process.env, windowsHide: true },
    );
  } finally {
    if (existsSync(notesFile)) unlinkSync(notesFile);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main();
}
