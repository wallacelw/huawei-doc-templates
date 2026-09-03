# latexmkrc — use XeLaTeX by default (the class loads fontspec, so pdflatex won't work)
# TEXINPUTS: ../ for assets/ in parent, then ../../../../ for templates from src/
$ENV{TEXINPUTS} = "../:../../../../templates/_base/:../../../../templates/technical/:" . ($ENV{TEXINPUTS} || "");
$ENV{TZ} = "America/Sao_Paulo";  # default TZ (GMT-3); projects can override
$pdf_mode = 5;    # 5 = xelatex
$xelatex = 'xelatex -interaction=nonstopmode %O %S';
$out_dir = '..';  # Output PDF to parent directory
$aux_dir = '.';   # Keep aux files in src/
