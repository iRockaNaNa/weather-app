# tooling/

`binary-assets.tar.gz.b64` holds the repo's binary files (Android launcher
icons, splash images, iOS app icons, and the Gradle wrapper jar), packed as a
base64 tarball. They live here because the upload path used for the first
push only accepts text files.

`restore-binary-assets.sh` unpacks them back into place. GitHub Actions runs
it before building the APK.

If you ever push from a machine with real git (WSL), you can add the actual
binary files to the repo with `git add`, delete this tarball, and drop the
restore step from `.github/workflows/build-apk.yml`.
