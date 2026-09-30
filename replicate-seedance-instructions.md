# Generating video with Seedance 2.5 (Replicate)

Model: `bytedance/seedance-2.5`. Auth: `REPLICATE_API_TOKEN`, stored in the repo root `.env.local` (gitignored; never commit it). Load it with `set -a; source .env.local; set +a`.

## Run

```bash
curl -s -X POST \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d '{"input": {"prompt": "...", "duration": 8, "resolution": "1080p", "aspect_ratio": "9:16", "generate_audio": false, "watermark": false}}' \
  https://api.replicate.com/v1/models/bytedance/seedance-2.5/predictions
```

- `Prefer: wait` holds the request up to 60s. If `status` isn't `succeeded` yet, poll `urls.get` from the response (`GET` with the same auth header) every few seconds until `succeeded` or `failed`.
- `output` is a URL to the video. Download it right away: output URLs expire after about an hour.
- Save raw outputs outside the repo (e.g. a scratch folder). Only the final, optimized asset gets committed.

## Inputs

| Param | Type | Default | Notes |
|---|---|---|---|
| `prompt` | string | | Works best as a detailed "production brief": subject, action, camera, lighting, mood, framing, what to avoid. Optional if media inputs are given. |
| `duration` | int | `5` | Seconds, 1–30. `-1` lets the model choose (required for editing mode). |
| `resolution` | string | `"720p"` | Use the highest available for app assets; we downscale when encoding. |
| `aspect_ratio` | string | `"16:9"` | e.g. `"9:16"` for full-screen phone. `"adaptive"` = match inputs (required for first/last-frame, editing, extension). |
| `generate_audio` | bool | `true` | Set `false` for app backgrounds. When true, dialogue goes in double quotes in the prompt. |
| `watermark` | bool | | Always `false`. |
| `seed` | int | | Set to reproduce or iterate on a result (not guaranteed). |
| `output_format` | string | `"mp4"` | |
| `image` | uri | | First frame (image-to-video). Can't combine with `reference_*`. |
| `last_frame_image` | uri | | Last frame; requires `image`. Useful for seamless loops (same image as first and last). |
| `reference_images` | uri[] | `[]` | Up to 30, for character/style/composition. Refer to them in the prompt as `[Image1]`, `[Image2]`… |
| `reference_videos` | uri[] | `[]` | Up to 10, 30s total, for motion transfer, style, editing, extension. `[Video1]`… |
| `reference_audios` | uri[] | `[]` | Up to 10, 30s total, for audio-driven/lip-sync. Needs a reference image or video. `[Audio1]`… |

Modes: text-to-video (prompt only), image-to-video (`image`), first/last frame (`image` + `last_frame_image`), reference-guided (`reference_*`). First/last frame and `reference_*` are mutually exclusive.

## Kiki conventions

- Brand is black/white: generate muted, desaturated footage and grade to B&W when encoding.
- No logos, brand marks, text or identifiable real people.
- Full-screen app backgrounds: `9:16`, highest resolution, generate 8s and trim to the best ~6s loop, no audio.
- Ship as HEVC (H.265), ~720×1280, no audio track, target 1–2 MB, plus a JPEG poster frame (shown instantly and when Reduce Motion is on). Encode with `ffmpeg -c:v libx265 -tag:v hvc1 -an`.
