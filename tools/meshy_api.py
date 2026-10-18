"""
meshy_api.py - thin REST wrapper around the Meshy API for the Home prop batch (2026-10-18).

The Meshy MCP server only reads MESHY_API_KEY at start-up, so while a session is already running the
same calls go through this script instead. The key is read from the MESHY_API_KEY environment
variable (Windows user scope); it is never passed on the command line and never written to disk.

Everything landed by a task is saved under meshy_output/<stamp>_<name>/ (Godot-ignored, git-ignored):
  model.glb        the mesh + baked textures, as Meshy returns it
  base_color.png   the base colour map on its own, when the task reports one
  task.json        the full task record, including consumed_credits

Run:
  python tools/meshy_api.py balance
  python tools/meshy_api.py image-to-3d --name store --image source_art/reference/home_crops/store.png
  python tools/meshy_api.py text-to-3d --name tricycle --prompt "..." [--no-refine]
  python tools/meshy_api.py retexture --name tricycle_right --id <task> --prompt "..."
  python tools/meshy_api.py text-to-image --name street_decal --prompt "..."
  python tools/meshy_api.py status --id <task> [--kind K]
  python tools/meshy_api.py wait --id <task> [--kind K] [--timeout 900]
  python tools/meshy_api.py download --id <task> --name store [--kind K]
  python tools/meshy_api.py animations            # the whole animation library, free
  python tools/meshy_api.py list --kind rigging   # this account's own tasks, free
  python tools/meshy_api.py animate --name sit --rig <rig task> --actions 12 34 56

Kinds (endpoint name, default "image-to-3d"): image-to-3d, text-to-3d, retexture, text-to-image,
  image-to-image, remesh, convert, resize, rigging, animation, text-to-motion, multi-image-to-3d
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "https://api.meshy.ai/openapi/v1"
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(PROJ, "meshy_output")
POLL = 10  # seconds between status checks


def log(msg):
    print(f"[meshy] {msg}", flush=True)


def key():
    k = os.environ.get("MESHY_API_KEY", "").strip()
    if not k:
        raise SystemExit("MESHY_API_KEY is not set in this shell's environment")
    return k


def call(method, path, body=None, kind=None):
    """One API round trip; `path` is relative to /openapi/v1 unless it already is a full id path."""
    url = f"{BASE}/{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + key())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise SystemExit(f"{method} {url} -> HTTP {e.code}: {detail}")
    except urllib.error.URLError as e:
        raise SystemExit(f"{method} {url} -> {e.reason}")


def data_uri(path):
    """A local image as a data URI (Meshy takes them for every image input)."""
    ext = os.path.splitext(path)[1].lower().lstrip(".")
    mime = {"jpg": "jpeg", "jpeg": "jpeg", "png": "png", "webp": "webp"}.get(ext)
    if mime is None:
        raise SystemExit(f"unsupported image type .{ext} (jpg, png, webp)")
    with open(path, "rb") as f:
        blob = base64.b64encode(f.read()).decode()
    log(f"{os.path.relpath(path, PROJ)}  {len(blob) // 1024} KB base64")
    return f"data:image/{mime};base64,{blob}"


def task_path(kind, task_id=None):
    return kind if task_id is None else f"{kind}/{task_id}"


def cmd_balance(_args):
    b = call("GET", "balance")
    log(f"balance {b.get('balance')}  (monthly {b.get('monthly_credits')}, "
        f"permanent {b.get('permanent_credits')})")
    return b


def cmd_image_to_3d(args):
    body = {
        "image_url": data_uri(args.image),
        "ai_model": args.model,
        "should_texture": not args.no_texture,
        "should_remesh": False,
        "target_formats": ["glb"],
    }
    if args.resolution != "standard":
        body["geometry_resolution"] = args.resolution
    if args.texture_resolution:
        body["texture_resolution"] = args.texture_resolution
    if args.topology:
        body["topology"] = args.topology
    r = call("POST", "image-to-3d", body)
    log(f"image-to-3d  {args.name}  ->  {r['result']}")
    return r["result"]


def cmd_text_to_3d(args):
    body = {
        "mode": "preview",
        "prompt": args.prompt,
        "ai_model": args.model,
        "should_remesh": False,
        "target_formats": ["glb"],
    }
    if args.resolution != "standard":
        body["geometry_resolution"] = args.resolution
    r = call("POST", "text-to-3d", body)
    preview = r["result"]
    log(f"text-to-3d preview  {args.name}  ->  {preview}   (20 credits)")
    if args.no_refine:
        return preview
    cmd_wait(argparse.Namespace(id=preview, kind="text-to-3d", timeout=args.timeout))
    r = call("POST", "text-to-3d", {"mode": "refine", "preview_task_id": preview})
    log(f"text-to-3d refine   {args.name}  ->  {r['result']}   (10 credits)")
    return r["result"]


def cmd_retexture(args):
    body = {"input_task_id": args.id, "target_formats": ["glb"]}
    if args.prompt:
        body["text_style_prompt"] = args.prompt
    if args.image:
        body["image_style_url"] = data_uri(args.image)
    r = call("POST", "retexture", body)
    log(f"retexture  {args.name}  ->  {r['result']}")
    return r["result"]


def cmd_text_to_image(args):
    body = {"prompt": args.prompt, "ai_model": args.model}
    r = call("POST", "text-to-image", body)
    log(f"text-to-image  {args.name}  ->  {r['result']}")
    return r["result"]


def cmd_status(args):
    t = call("GET", task_path(args.kind, args.id))
    log(f"{args.kind} {args.id}  status {t.get('status')}  progress {t.get('progress')}  "
        f"credits {t.get('consumed_credits')}")
    return t


def cmd_wait(args):
    t0 = time.time()
    while True:
        t = call("GET", task_path(args.kind, args.id))
        p = t.get("progress", 0)
        log(f"{t.get('status'):11s} {p:3d}%  {int(time.time() - t0):4d}s")
        if t.get("status") in ("SUCCEEDED", "FAILED", "CANCELED"):
            if t.get("status") != "SUCCEEDED":
                raise SystemExit(f"task {args.id} {t.get('status')}: {t.get('task_error')}")
            return t
        if time.time() - t0 > args.timeout:
            raise SystemExit(f"task {args.id} still running after {args.timeout}s (keep polling)")
        time.sleep(POLL)


def stamp():
    return time.strftime("%Y%m%d_%H%M%S", time.localtime())


def fetch(url, path):
    with urllib.request.urlopen(url, timeout=300) as r, open(path, "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    log(f"saved {os.path.relpath(path, PROJ)}  {os.path.getsize(path) // 1024} KB")


def cmd_download(args):
    t = call("GET", task_path(args.kind, args.id))
    name = args.name or args.id
    folder = os.path.join(OUT, f"{stamp()}_{name}")
    os.makedirs(folder, exist_ok=True)
    got = []
    for fmt, url in sorted((t.get("model_urls") or {}).items()):
        if fmt in ("glb", "gltf", "obj", "fbx"):
            fetch(url, os.path.join(folder, "model." + fmt))
            got.append(fmt)
    for i, tex in enumerate(t.get("texture_urls") or []):
        for slot, url in sorted(tex.items()):
            if url:
                fetch(url, os.path.join(folder, f"{slot}_{i}.png"))
    for i, url in enumerate(t.get("image_urls") or []):
        if url:
            fetch(url, os.path.join(folder, f"image_{i}.png"))
    with open(os.path.join(folder, "task.json"), "w", encoding="utf-8") as f:
        json.dump(t, f, indent=2)
    log(f"{os.path.relpath(folder, PROJ)}  formats {got or '(none)'}")
    return folder


def cmd_list(args):
    """The account's own tasks of one kind, newest last (free)."""
    tasks = call("GET", args.kind)
    for t in tasks:
        log(f"{t.get('id')}  {t.get('status'):10s} {t.get('type') or args.kind:8s} "
            f"{t.get('name') or '-':24s} {time.strftime('%Y-%m-%d %H:%M', time.localtime(t.get('created_at', 0) / 1000))}")
    return tasks


def cmd_animations(args):
    """The preset animation library (free). `--grep` filters name / key / category."""
    lib = call("GET", "animations/library")
    needle = (args.grep or "").lower()
    hits = [a for a in lib if not needle or needle in " ".join(
        str(a.get(k, "")) for k in ("name", "key", "category", "sub_category")).lower()]
    for a in hits:
        log(f"{a.get('action_id'):4}  {a.get('key'):34s} {a.get('category'):14s} "
            f"{a.get('sub_category'):16s} {a.get('name')}")
    log(f"{len(hits)} of {len(lib)} actions")
    return hits


def cmd_animate(args):
    """Preset actions on a rigged task (3 credits per action); up to 10 share one download."""
    body = {"rig_task_id": args.rig}
    if args.action:
        body["action_id"] = args.action[0]
    else:
        body["action_ids"] = args.actions
    r = call("POST", "animations", body)
    task = r["result"]
    n = 1 if args.action else len(args.actions)
    log(f"animations  {args.name}  ->  {task}   ({n * 3} credits)")
    if args.no_wait:
        return task
    t = cmd_wait(argparse.Namespace(id=task, kind="animations", timeout=args.timeout))
    res = t.get("result") or {}
    for slot, url in sorted(res.items()):
        if not url:
            continue
        folder = os.path.join(OUT, f"{stamp()}_{args.name}")
        os.makedirs(folder, exist_ok=True)
        ext = os.path.splitext(url.split("?")[0])[1] or ".bin"
        fetch(url, os.path.join(folder, slot + ext))
        with open(os.path.join(folder, "task.json"), "w", encoding="utf-8") as f:
            json.dump(t, f, indent=2)
    return task


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("balance", help="credits left").set_defaults(func=cmd_balance)

    a = sub.add_parser("image-to-3d", help="one crop -> one textured GLB (30 credits)")
    a.add_argument("--name", required=True)
    a.add_argument("--image", required=True)
    a.add_argument("--model", default="meshy-7.1")
    a.add_argument("--resolution", default="standard", choices=["standard", "2k", "4k"])
    a.add_argument("--texture-resolution", default="")
    a.add_argument("--topology", default="")
    a.add_argument("--no-texture", action="store_true")
    a.set_defaults(func=cmd_image_to_3d)

    a = sub.add_parser("text-to-3d", help="prompt -> GLB (preview 20 + refine 10)")
    a.add_argument("--name", required=True)
    a.add_argument("--prompt", required=True)
    a.add_argument("--model", default="meshy-7.1")
    a.add_argument("--resolution", default="standard", choices=["standard", "2k", "4k"])
    a.add_argument("--timeout", type=int, default=900)
    a.add_argument("--no-refine", action="store_true")
    a.set_defaults(func=cmd_text_to_3d)

    a = sub.add_parser("retexture", help="new texture on an existing task (10 credits)")
    a.add_argument("--name", required=True)
    a.add_argument("--id", required=True)
    a.add_argument("--prompt", default="")
    a.add_argument("--image", default="")
    a.set_defaults(func=cmd_retexture)

    a = sub.add_parser("text-to-image", help="nano-banana image, e.g. a ground decal (3-9 credits)")
    a.add_argument("--name", required=True)
    a.add_argument("--prompt", required=True)
    a.add_argument("--model", default="nano-banana-2")
    a.set_defaults(func=cmd_text_to_image)

    for name, func in (("status", cmd_status),):
        a = sub.add_parser(name)
        a.add_argument("--id", required=True)
        a.add_argument("--kind", default="image-to-3d")
        a.set_defaults(func=func)

    a = sub.add_parser("wait")
    a.add_argument("--id", required=True)
    a.add_argument("--kind", default="image-to-3d")
    a.add_argument("--timeout", type=int, default=900)
    a.set_defaults(func=cmd_wait)

    a = sub.add_parser("download")
    a.add_argument("--id", required=True)
    a.add_argument("--name", default="")
    a.add_argument("--kind", default="image-to-3d")
    a.set_defaults(func=cmd_download)

    a = sub.add_parser("animations", help="the preset animation library, free")
    a.add_argument("--grep", default="")
    a.set_defaults(func=cmd_animations)

    a = sub.add_parser("list", help="this account's tasks of one kind, free")
    a.add_argument("--kind", default="image-to-3d")
    a.set_defaults(func=cmd_list)

    a = sub.add_parser("animate", help="preset actions on a rigged task (3 credits each)")
    a.add_argument("--name", required=True)
    a.add_argument("--rig", required=True, help="rig_task_id")
    a.add_argument("--action", type=int, action="append", help="one action id (repeatable)")
    a.add_argument("--actions", nargs="+", type=int, default=[], help="up to 10 ids, one file")
    a.add_argument("--timeout", type=int, default=900)
    a.add_argument("--no-wait", action="store_true")
    a.set_defaults(func=cmd_animate)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
