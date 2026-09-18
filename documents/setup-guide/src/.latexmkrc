# latexmkrc — project folder, template at ../../../templates/guide/ (from src/)
# TEXINPUTS: ../ for assets/ in parent, then ../../../ for templates from src/
$ENV{TEXINPUTS} = "../:../../../templates/_base/:../../../templates/guide/:" . ($ENV{TEXINPUTS} || "");
$ENV{TZ} = "America/Sao_Paulo";  # GMT-3 — so \today matches local date
$pdf_mode = 5;    # 5 = xelatex
$xelatex = 'xelatex -interaction=nonstopmode %O %S';
$out_dir = '..';  # Output PDF to parent directory
$aux_dir = '.';   # Keep aux files in src/
