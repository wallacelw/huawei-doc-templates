#!/usr/bin/env python3
"""DOCX post-processing for the Huawei guide template.

Usage:
    python3 create-guide-reference-docx.py --fix <file.docx>     # Fix heading styles
    python3 create-guide-reference-docx.py guide-reference.docx  # Regenerate reference DOCX
"""
import sys
import os

# Add _base to path and import shared logic
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '_base'))
from docx_fix import main

if __name__ == "__main__":
    main(sys.argv[1:] + ['--template', 'guide'], reference_name="guide-reference.docx")
