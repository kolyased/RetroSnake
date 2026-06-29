# RetroSnake Web

Standalone web/PWA version of RetroSnake.

## Run Locally

```bash
python3 -m http.server 5173 -d web
```

Open:

```text
http://localhost:5173
```

## Deploy

Upload the contents of `web/` to a HTTPS-enabled static server. PWA installation on iPhone requires Safari and HTTPS, except for local development.

## Notes

- The iOS project is not required to run the web version.
- Audio and app icons are copied into `web/public/`.
- Best score, sound, volume, and language are stored in browser `localStorage`.
