# Builds the OddSockets Flutter SDK straight from the repo and runs the
# two-client round-trip as a `flutter test` against the live platform.
#
# Build from the SDK repo root so the SDK source is in context:
#   docker build -f demo/Dockerfile -t oddsockets-flutter-demo .
#   docker run --rm -e ODDSOCKETS_API_KEY="ak_your_key_here" oddsockets-flutter-demo
#
# The json_serializable code (*.g.dart) is generated at build time and the SDK
# is compiled by `flutter test`, so a broken SDK fails the build - only a
# genuinely-compiling SDK produces a runnable image.
FROM ghcr.io/cirruslabs/flutter:stable

# Avoid git "dubious ownership" noise when tooling inspects the copied repo.
RUN git config --global --add safe.directory '*'

WORKDIR /sdk
COPY . .

# Resolve the SDK deps and generate the json_serializable code that is not
# checked in. This is the compile gate for the SDK itself.
RUN flutter pub get
RUN dart run build_runner build --delete-conflicting-outputs

# Resolve the demo (path dependency on the SDK just built).
WORKDIR /sdk/demo
RUN flutter pub get

# Run the two-client round-trip; a stalled or fake transport exits non-zero.
CMD ["flutter", "test", "--reporter", "expanded"]
