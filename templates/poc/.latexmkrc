# latexmkrc — reference config for the template root.
# This file is NOT used during normal compilation (no .tex files live here).
# Project folders (e.g. examples/poc/pt/, examples/poc/en/) have their own .latexmkrc
# with TEXINPUTS pointing here. Copy this as a starting point and add TEXINPUTS.
$ENV{TEXINPUTS} = "../templates/_base/:../templates/poc/:" . ($ENV{TEXINPUTS} || "");
$ENV{TZ} = "America/Sao_Paulo";  # default TZ (GMT-3); projects can override
$pdf_mode = 5;    # 5 = xelatex
$xelatex = 'xelatex -interaction=nonstopmode %O %S';
$out_dir = '..';
$aux_dir = '.';
