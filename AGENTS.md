# Working on this fork

Read `CONTRIBUTING.md` before changing code and `CONTEXT.md` for fork-specific decisions.

- Keep the upstream SwiftPM layout. This is a native macOS app, so the usual web project layout does not apply. Add repo-specific skills only when a recurring workflow needs one.
- Use `./build.sh debug` for development and `./build.sh` for a local release bundle.
- For text sizing changes, run `--smoke-font-size`, `--smoke-typing`, `--smoke-scroll`, `--smoke-find`, and `--smoke-reasoning` through `.build/debug/PopChat`, one at a time.
- Preserve local chats, credentials and preferences when replacing an installed app. Back up the existing app first.
- Commit to this fork. Sending changes upstream is a separate decision.
