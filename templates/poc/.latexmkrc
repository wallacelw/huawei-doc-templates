$ENV{TEXINPUTS} = "../templates/_base/:../templates/poc/:" . ($ENV{TEXINPUTS} || "");
$ENV{TZ} = "America/Sao_Paulo";
$pdf_mode = 5;
$xelatex = 'xelatex -interaction=nonstopmode %O %S';
$out_dir = '..';
$aux_dir = '.';
