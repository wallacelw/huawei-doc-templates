#!/usr/bin/env python3
"""Embed images as base64 data URIs in Markdown files.

Replaces ![caption](path) with ![caption](data:image/png;base64,...)
so the Markdown file is self-contained and images load without external files.

Usage:
    embed-images.py <file.md> [--resource-path <dir>[:<dir>...]]
"""

import sys
import os
import re
import base64
import argparse


def find_image(path, resource_paths):
    """Resolve an image path relative to resource paths."""
    # Try as-is (absolute or relative to cwd)
    if os.path.isfile(path):
        return path
    # Try relative to each resource path
    for rp in resource_paths:
        full = os.path.join(rp, path)
        if os.path.isfile(full):
            return full
    return None


def get_mime_type(path):
    """Guess MIME type from file extension."""
    ext = os.path.splitext(path)[1].lower()
    return {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".gif": "image/gif",
        ".svg": "image/svg+xml",
        ".webp": "image/webp",
        ".bmp": "image/bmp",
    }.get(ext, "image/png")


def embed_images(md_path, resource_paths):
    """Replace image paths in a Markdown file with base64 data URIs."""
    with open(md_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Match ![caption](path) — handle paths that don't start with data: or http
    pattern = re.compile(r'!\[([^\]]*)\]\(([^)]+)\)')

    def replace_match(m):
        caption = m.group(1)
        path = m.group(2).strip()
        # Skip already-embedded or remote URLs
        if path.startswith("data:") or path.startswith("http"):
            return m.group(0)
        # Find the image file
        img_path = find_image(path, resource_paths)
        if img_path is None:
            print(f"  ⚠ Image not found: {path}", file=sys.stderr)
            return m.group(0)
        # Read and encode
        with open(img_path, "rb") as f:
            data = base64.b64encode(f.read()).decode("ascii")
        mime = get_mime_type(img_path)
        data_uri = f"data:{mime};base64,{data}"
        print(f"  ✓ Embedded: {path} ({len(data)//1024}KB base64)")
        return f'![{caption}]({data_uri})'

    new_content = pattern.sub(replace_match, content)

    if new_content != content:
        with open(md_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"✓ Embedded images in {md_path}")
    else:
        print(f"  No images to embed in {md_path}")


def main():
    parser = argparse.ArgumentParser(description="Embed images as base64 in Markdown")
    parser.add_argument("md_file", help="Markdown file to process")
    parser.add_argument(
        "--resource-path",
        default=".",
        help="Colon-separated resource paths (default: .)",
    )
    args = parser.parse_args()

    resource_paths = args.resource_path.split(":")
    embed_images(args.md_file, resource_paths)


if __name__ == "__main__":
    main()
