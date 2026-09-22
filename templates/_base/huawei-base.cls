%% huawei-base.cls
%% =====================================================================
%%  Base class for all Huawei Cloud document templates.
%%  Requires XeLaTeX or LuaLaTeX (due to fontspec).
%%
%%  This class holds the boilerplate shared by every template class
%%  (guide, technical, testbook, poc):
%%    - Shared class options (portuguese, indentbody, notime, nochangelog,
%%      noauthors); any other option is passed to the article class.
%%    - \LoadClass of article (a4paper, 10pt).
%%    - All package loads. A base CLASS may load packages; the shared
%%      huawei-*.sty modules may not (see AGENTS.md L15).
%%    - The 13 shared module loads from templates/_base/:
%%      huawei-colors, huawei-fonts, huawei-lang, huawei-page,
%%      huawei-tables, huawei-code, huawei-callouts, huawei-images,
%%      huawei-changelog, huawei-titles, huawei-toc, huawei-cover,
%%      huawei-shared.
%%    - \setdoctitle (shared cover title setter).
%%
%%  Template classes build on this base:
%%    guide/technical/poc: \LoadClassWithOptions{huawei-base}, then
%%      template-specific commands/environments only.
%%    testbook: declares its extra `noanswers` option, passes remaining
%%      options through with \PassOptionsToClass, then \LoadClass.
%%  Template-specific packages (tabularx, amssymb, seqsplit) and the
%%  huawei-badges module (testbook, poc) stay in the template classes.
%%
%%  Fonts:
%%    - Body : HarmonyOS Sans (fallback: Liberation Sans)
%%    - Code : Cascadia Code (fallback: DejaVu Sans Mono)
%%
%%  Shared class options:
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
\ProvidesClass{huawei-base}[2026/09/23 Huawei Base class v6.13.0]

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
\fvset{breaklines,breakanywhere}
\RequirePackage[most]{tcolorbox}
\RequirePackage{etoolbox}
\RequirePackage{booktabs}
\RequirePackage{array}
\RequirePackage{ragged2e}
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

% ---- Cover title (shared) --------------------------------------------
% \setdoctitle{...}  -> large cover title (and default header).
% The template aliases (setguidetitle, setreporttitle, settestbooktitle,
% setpoctitle) call this command.
\newcommand{\setdoctitle}[1]{\renewcommand{\lg@doctitle}{#1}}

\endinput
