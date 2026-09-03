# latexmkrc — reference config for the template root.
# This file is NOT used during normal compilation (no .tex files live here).
# Project folders (e.g. examples/) have their own .latexmkrc
# with TEXINPUTS pointing here. Copy this as a starting point and add TEXINPUTS.
$pdf_mode = 5;    # 5 = xelatex
$ENV{TZ} = "America/Sao_Paulo";  # default TZ (GMT-3); projects can override
$xelatex = 'xelatex -interaction=nonstopmode %O %S';
