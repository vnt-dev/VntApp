import assert from "node:assert/strict";
import test from "node:test";

import {
  buildDownloadSection,
  mergeDownloadSection,
} from "./update-release-downloads.mjs";

test("builds links only for APKs present in the release", () => {
  const section = buildDownloadSection({
    tag: "v1.0.0",
    releaseUrl: "https://github.com/vnt-dev/VntApp/releases/download/v1.0.0",
    assetNames: new Set([
      "VNT-Android-v1.0.0-universal.apk",
      "VNT-Android-v1.0.0-arm64-v8a.apk",
      "VNT-Android-v1.0.0-x86_64.apk",
    ]),
  });

  assert.match(section, /VNT-Android-v1\.0\.0-universal\.apk/);
  assert.match(section, /VNT-Android-v1\.0\.0-arm64-v8a\.apk/);
  assert.match(section, /VNT-Android-v1\.0\.0-x86_64\.apk/);
  assert.doesNotMatch(section, /VNT-Android-v1\.0\.0-armeabi-v7a\.apk/);
});

test("replaces an existing Android download section", () => {
  const oldSection = [
    "<!-- vnt-android-downloads:start -->",
    "old links",
    "<!-- vnt-android-downloads:end -->",
  ].join("\n");
  const merged = mergeDownloadSection(`Release notes\n\n${oldSection}\n`, "new links");

  assert.equal(merged, "Release notes\n\nnew links\n");
});

test("rejects an incomplete Android download section", () => {
  assert.throws(
    () =>
      mergeDownloadSection(
        "<!-- vnt-android-downloads:start -->\nold links",
        "new links",
      ),
    /incomplete download section/,
  );
});
