%% guide.cls
%% =====================================================================
%%  LaTeX class for Huawei Cloud guides
%%  Requires XeLaTeX or LuaLaTeX (due to fontspec).
%%
%%  v2.10.0 — Decomposed into shared modules (templates/_base/huawei-*.sty):
%%    huawei-colors, huawei-fonts, huawei-lang, huawei-page, huawei-tables,
%%    huawei-code, huawei-callouts, huawei-images, huawei-changelog,
%%    huawei-shared.
%%  This class loads all packages, then all modules, then applies
%%  template-specific formatting (titles, TOC, cover).
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
%%    <any>       -> passed to the article class.
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{guide}[2026/09/05 Huawei Guide template v2.16.0]

% ---- Options --------------------------------------------------------
\newif\if@indentbody \@indentbodyfalse
\DeclareOption{indentbody}{\@indentbodytrue}
\newif\if@portuguese \@portuguesefalse
\DeclareOption{portuguese}{\@portuguesetrue}
\newif\if@showtime \@showtimetrue
\DeclareOption{notime}{\@showtimefalse}
\newif\if@changelog \@changelogtrue
\DeclareOption{nochangelog}{\@changelogfalse}
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
\RequirePackage{huawei-shared}

% =====================================================================
%  TITLES (headings)
% =====================================================================
\setcounter{secnumdepth}{4}

% --- H1: big number (56pt) left-aligned + 20pt bold right-aligned title + rule
\titleformat{\section}[block]
  {\normalfont\bfseries\fontsize{20}{25}\selectfont}
  {\fontsize{56}{56}\selectfont\thesection}
  {0pt}
  {\hfill}
  [\vspace{2pt}{\color{huaweired}\titlerule[1.5pt]}\vspace{14pt}]
\titlespacing*{\section}{0pt}{0pt}{30pt} % before 0 / after 30pt
% Each \section (chapter) starts on a new page
\let\lg@origsection\section
\renewcommand{\section}{\clearpage\lg@origsection}

% --- H2/H3/H4: regular, decreasing sizes, left-aligned
\titleformat{\subsection}
  {\normalfont\fontsize{18}{22}\selectfont}{\thesubsection}{0.4em}{}
\titlespacing*{\subsection}{0pt}{30pt}{6pt}

\titleformat{\subsubsection}
  {\normalfont\fontsize{16}{20}\selectfont}{\thesubsubsection}{0.4em}{}
\titlespacing*{\subsubsection}{0pt}{10pt}{4pt}

\titleformat{\paragraph}[hang]
  {\normalfont\fontsize{14}{18}\selectfont}{\theparagraph}{0.4em}{}
\titlespacing*{\paragraph}{0pt}{8pt}{4pt}

% Numbering: 1  /  1.1  /  1.1.1  /  1.1.1.1
\renewcommand{\thesection}{\arabic{section}}
\renewcommand{\thesubsection}{\thesection.\arabic{subsection}}
\renewcommand{\thesubsubsection}{\thesubsection.\arabic{subsubsection}}
\renewcommand{\theparagraph}{\thesubsubsection.\arabic{paragraph}}

% =====================================================================
%  TABLE OF CONTENTS — right-aligned title + rule; dotted leaders
% =====================================================================
\renewcommand{\contentsname}{\lg@toc}
\renewcommand{\cfttoctitlefont}{\hfill\normalfont\bfseries\fontsize{22}{26}\selectfont}
\renewcommand{\cftaftertoctitle}{\par\vspace{2pt}%
  {\color{ruleblack}\hrule height 0.5pt}\vspace{6pt}}
% Level 1: bold 12pt
\renewcommand{\cftsecfont}{\bfseries\fontsize{12}{15}\selectfont}
\renewcommand{\cftsecpagefont}{\bfseries\fontsize{12}{15}\selectfont}
\renewcommand{\cftsecleader}{\bfseries\cftdotfill{\cftdotsep}}
% Levels 2 and 3: normal 10pt
\renewcommand{\cftsubsecfont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsecpagefont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsubsecfont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsubsecpagefont}{\fontsize{10}{13}\selectfont}
% TOC indents starting at the margin (ind left=0)
\setlength{\cftsecindent}{0pt}
\setlength{\cftsubsecindent}{1.2em}
\setlength{\cftsubsubsecindent}{2.4em}
\setlength{\cftbeforesecskip}{4pt}
\renewcommand{\cftdotsep}{1.2}
% show dotted leaders also at level 1
\setcounter{tocdepth}{3}

% Convenience command for TOC (resets leftskip)
\newcommand{\maketoc}{{\leftskip=0pt\relax\pagestyle{plain}\thispagestyle{plain}\tableofcontents}\clearpage}

% =====================================================================
%  COVER
% =====================================================================
% \setguidetitle{...}  -> large cover title (and default header)
\newcommand{\setguidetitle}[1]{\renewcommand{\lg@guidetitle}{#1}}
\newcommand{\lg@covertext}{Huawei Technologies CO., LTD}
\newcommand{\setcovertext}[1]{\renewcommand{\lg@covertext}{#1}}
\newcommand{\lg@coverlogo}{common-assets/huawei-logo-cover.png}
\newcommand{\setcoverlogo}[1]{\renewcommand{\lg@coverlogo}{#1}}
% Compilation time from \time primitive (minutes since midnight, respects TZ)
% \two@digits is provided by the LaTeX kernel
\newcount\lg@hour
\newcount\lg@min
\newcount\lg@tmp
\lg@hour=\time
\divide\lg@hour by 60
\lg@tmp=\lg@hour
\multiply\lg@tmp by 60
\lg@min=\time
\advance\lg@min by -\lg@tmp
\newcommand{\lg@covermeta}{%
  \ifx\lg@docversion\@empty\else\textbf{v\lg@docversion}\fi
  \ifx\lg@docversion\@empty\else\ifx\lg@docdate\@empty\else\ — \fi\fi
  \ifx\lg@docdate\@empty\else\lg@docdate\fi
  \if@showtime\ \two@digits{\lg@hour}:\two@digits{\lg@min}\fi%
}

\newcommand{\makecover}{%
  \begingroup
  \leftskip=0pt\relax
  \thispagestyle{empty}%
  \vspace*{2.2cm}%
  {\centering
   \fontsize{36}{42}\selectfont\bfseries \lg@guidetitle\par}%
  \vspace{4.5cm}%
  {\centering
   \includegraphics[width=3.6cm]{\lg@coverlogo}\par}%
  \vspace{0.9cm}%
   {\centering
    \fontsize{16}{20}\selectfont \lg@covertext\par}%
   \vspace{0.5cm}%
   {\centering
    \fontsize{12}{14}\selectfont \if@changelog\lg@covermeta\fi\par}%
   \endgroup
  \clearpage}

\endinput
