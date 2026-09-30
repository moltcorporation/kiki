# Generating images with Nano Banana Pro (Replicate)

Model: `google/nano-banana-pro`. Auth: `REPLICATE_API_TOKEN`, stored in the repo root `.env.local` (gitignored; never commit it). Load it with `set -a; source .env.local; set +a`.

## Run

```bash
curl -s -X POST \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d '{"input": {"prompt": "...", "resolution": "4K", "aspect_ratio": "1:1", "output_format": "png"}}' \
  https://api.replicate.com/v1/models/google/nano-banana-pro/predictions
```

- `Prefer: wait` holds the request up to 60s. If `status` isn't `succeeded` yet, poll `urls.get` from the response (`GET` with the same auth header) until `succeeded` or `failed`.
- `output` is a URL to the image. Download it right away: output URLs expire after about an hour.
- Save raw outputs outside the repo (e.g. a scratch folder). Only commit final assets.

## Inputs

| Param | Type | Default | Notes |
|---|---|---|---|
| `prompt` | string | | Describe subject, style, lighting, composition and what to avoid. |
| `resolution` | string | `"2K"` | `"1K"`, `"2K"` or `"4K"`. |
| `aspect_ratio` | string | `"match_input_image"` | `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`, or `match_input_image`. Set it explicitly when there's no input image. |
| `output_format` | string | `"jpg"` | `"jpg"` or `"png"`. Use `png` for assets you'll edit or composite. |
| `image_input` | uri[] | `[]` | Up to 14 images to edit or use as reference. Public URLs, or small local files as `data:image/png;base64,...` URIs (keep them under ~1 MB; upload larger files via `POST https://api.replicate.com/v1/files`). |
| `safety_filter_level` | string | `"block_only_high"` | `block_low_and_above` (strictest), `block_medium_and_above`, `block_only_high` (most permissive). |
| `allow_fallback_model` | bool | `false` | Falls back to `bytedance/seedream-5` if Nano Banana Pro is at capacity. |

## Tips

- AI models don't reproduce exact typefaces. For logos or text, generate the artwork without text and composite the exact lettering yourself (e.g. rendered with SwiftUI `ImageRenderer` or Pillow).
