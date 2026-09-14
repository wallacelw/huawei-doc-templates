%% guide.cls
%% =====================================================================
%%  LaTeX class for Huawei Cloud guides
%%  Requires XeLaTeX or LuaLaTeX (due to fontspec).
%%
%%  Decomposed into shared modules (templates/_base/huawei-*.sty):
%%    huawei-colors, huawei-fonts, huawei-lang, huawei-page, huawei-tables,
%%    huawei-code, huawei-callouts, huawei-images, huawei-changelog,
%%    huawei-titles, huawei-toc, huawei-cover, huawei-shared.
%%  This class loads all packages, then all modules, then applies
%%  template-specific formatting.
%%
%%  Fonts:
%%    - Body : HarmonyOS Sans (fallback: Liberation Sans)
%%    - Code : Cascadia Code (fallback: DejaVu Sans Mono)
%%
%%  Class options:
%%    portuguese  -> uses Portuguese for predefined labels and babel.
%%                   (default: English)
%%    indentbody  -> indents all running text by \contentindent.
%%                   (default: off)
%%    notime      -> hides the compilation time on the cover.
%%                   (default: show time)
%%    nochangelog -> suppresses the changelog section entirely
%%                   and hides version/date/time on the cover page.
%%                   (default: show changelog)
%%    noauthors   -> hides the authors on the cover page.
%%                   (default: show authors if set)
%%    <any>       -> passed to the article class.
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{guide}[2026/09/13 Huawei Guide template v5.0.0]

% ---- Options --------------------------------------------------------
\newif\if@indentbody \@indentbodyfalse
\DeclareOption{indentbody}{\@indentbodytrue}
\newif\if@portuguese \@portuguesefalse
\DeclareOption{portuguese}{\@portuguesetrue}
\newif\if@showtime \@showtimetrue
\DeclareOption{notime}{\@showtimefalse}
\newif\if@changelog \@changelogtrue
\DeclareOption{nochangelog}{\@changelogfalse}
\newif\if@showauthors \@showauthorstrue
\DeclareOption{noauthors}{\@showauthorsfalse}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[a4paper,10pt]{article}

% ---- Packages -------------------------------------------------------
\RequirePackage[a4paper,top=3cm,bottom=3cm,left=2cm,right=2cm,%
                headheight=1.4cm,headsep=0.7cm]{geometry}
\RequirePackage{fontspec}
\PassOptionsToPackage{table}{xcolor}
\RequirePackage{xcolor}
\RequirePackage{graphicx}
\RequirePackage{fancyhdr}
\RequirePackage{titlesec}
\RequirePackage[titles]{tocloft}
\RequirePackage{enumitem}
\RequirePackage{fancyvrb}
\RequirePackage{fvextra}
\RequirePackage[most]{tcolorbox}
\RequirePackage{etoolbox}
\RequirePackage{booktabs}
\RequirePackage{array}
\RequirePackage{babel}
\if@portuguese
  \babelprovide[import,main]{brazilian}
\else
  \babelprovide[import,main]{english}
\fi
\RequirePackage{hyperref}
\RequirePackage{caption}
\RequirePackage{float}
\RequirePackage{longtable}

% ---- Shared modules (templates/_base/) ------------------------------
\RequirePackage{huawei-colors}
\RequirePackage{huawei-fonts}
\RequirePackage{huawei-lang}
\RequirePackage{huawei-page}
\RequirePackage{huawei-tables}
\RequirePackage{huawei-code}
\RequirePackage{huawei-callouts}
\RequirePackage{huawei-images}
\RequirePackage{huawei-changelog}
\RequirePackage{huawei-titles}
\RequirePackage{huawei-toc}
\RequirePackage{huawei-cover}
\RequirePackage{huawei-shared}

% ---- Titles (shared) ----------------------------------------------
% (loaded via huawei-titles)

% ---- TOC (shared) -------------------------------------------------
% (loaded via huawei-toc)

% ---- Cover (shared) -----------------------------------------------
% \setdoctitle{...}  -> large cover title (and default header)
\newcommand{\setdoctitle}[1]{\renewcommand{\lg@doctitle}{#1}}
\newcommand{\setguidetitle}[1]{\setdoctitle{#1}}% backward-compatible alias

\endinput
