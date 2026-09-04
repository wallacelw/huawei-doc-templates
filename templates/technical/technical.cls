%% technical.cls
%% =====================================================================
%%  LaTeX class for Huawei Cloud technical reports
%%  Requires XeLaTeX or LuaLaTeX (due to fontspec).
%%
%%  v2.15.0 — Rebuilt as LaTeX-based template (replaces python-docx approach).
%%    Loads all shared modules from templates/_base/:
%%    huawei-colors, huawei-fonts, huawei-lang, huawei-page, huawei-tables,
%%    huawei-code, huawei-callouts, huawei-images, huawei-changelog,
%%    huawei-shared.
%%
%%  Provides a 6-section structure for formal incident/analysis reports:
%%    1. Problem Description and Impact
%%    2. Root Cause Analysis
%%    3. Root Cause
%%    4. Trigger Condition
%%    5. Workaround and Impact (with 6 subsections)
%%    6. (Changelog — optional)
%%
%%  Class options:
%%    portuguese  -> uses Portuguese for predefined labels and babel.
%%                   (default: English)
%%    notime      -> hides the compilation time on the cover.
%%                   (default: show time)
%%    nochangelog -> suppresses the changelog section entirely
%%                   and hides version/date/time on the cover page.
%%                   (default: show changelog)
%%    <any>       -> passed to the article class.
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{technical}[2026/09/05 Huawei Technical Report template v2.16.0]

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
%  TITLES (headings) — same style as guide.cls for consistency
% =====================================================================
\setcounter{secnumdepth}{4}

% --- H1: big number (56pt) left-aligned + 20pt bold right-aligned title + rule
\titleformat{\section}[block]
  {\normalfont\bfseries\fontsize{20}{25}\selectfont}
  {\fontsize{56}{56}\selectfont\thesection}
  {0pt}
  {\hfill}
  [\vspace{2pt}{\color{huaweired}\titlerule[1.5pt]}\vspace{14pt}]
\titlespacing*{\section}{0pt}{0pt}{30pt}
% Each \section starts on a new page
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
%  TABLE OF CONTENTS — same style as guide.cls
% =====================================================================
\renewcommand{\contentsname}{\lg@toc}
\renewcommand{\cfttoctitlefont}{\hfill\normalfont\bfseries\fontsize{22}{26}\selectfont}
\renewcommand{\cftaftertoctitle}{\par\vspace{2pt}%
  {\color{ruleblack}\hrule height 0.5pt}\vspace{6pt}}
\renewcommand{\cftsecfont}{\bfseries\fontsize{12}{15}\selectfont}
\renewcommand{\cftsecpagefont}{\bfseries\fontsize{12}{15}\selectfont}
\renewcommand{\cftsecleader}{\bfseries\cftdotfill{\cftdotsep}}
\renewcommand{\cftsubsecfont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsecpagefont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsubsecfont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsubsecpagefont}{\fontsize{10}{13}\selectfont}
\setlength{\cftsecindent}{0pt}
\setlength{\cftsubsecindent}{1.2em}
\setlength{\cftsubsubsecindent}{2.4em}
\setlength{\cftbeforesecskip}{4pt}
\renewcommand{\cftdotsep}{1.2}
\setcounter{tocdepth}{3}

\newcommand{\maketoc}{{\leftskip=0pt\relax\pagestyle{plain}\thispagestyle{plain}\tableofcontents}\clearpage}

% =====================================================================
%  TECHNICAL REPORT — metadata commands
% =====================================================================
\newcommand{\lg@reporttitle}{Technical Report}
\newcommand{\setreporttitle}[1]{\renewcommand{\lg@reporttitle}{#1}}
\newcommand{\lg@reportversion}{}
\newcommand{\setreportversion}[1]{\renewcommand{\lg@reportversion}{#1}}
\newcommand{\lg@reportdate}{\today}
\newcommand{\setreportdate}[1]{\renewcommand{\lg@reportdate}{#1}}
\newcommand{\lg@reportscenario}{}
\newcommand{\setreportscenario}[1]{\renewcommand{\lg@reportscenario}{#1}}
\newcommand{\lg@reporttype}{Technical Report}
\newcommand{\setreporttype}[1]{\renewcommand{\lg@reporttype}{#1}}

% Fix: huawei-page.sty references \lg@guidetitle for PDF metadata.
% Alias it to the report title so technical PDFs don't show "Guide" as pdftitle.
\renewcommand{\lg@guidetitle}{\lg@reporttitle}

% =====================================================================
%  LANGUAGE-AWARE SECTION LABELS
% =====================================================================
\if@portuguese
  \newcommand{\lg@problem}{Descrição do Problema e Impacto}
  \newcommand{\lg@rootcauseanalysis}{Análise de Causa Raiz}
  \newcommand{\lg@rootcause}{Causa Raiz}
  \newcommand{\lg@triggercondition}{Condição de Disparo}
  \newcommand{\lg@workaround}{Solução Alternativa e Impacto}
  \newcommand{\lg@impact}{Impacto}
  \newcommand{\lg@backupdata}{Backup de dados antes da solução alternativa}
  \newcommand{\lg@workaroundsteps}{Solução Alternativa}
  \newcommand{\lg@verification}{Verificação após a solução alternativa}
  \newcommand{\lg@rollback}{Operação de Rollback}
  \newcommand{\lg@cleanup}{Operação de Limpeza}
\else
  \newcommand{\lg@problem}{Problem Description and Impact}
  \newcommand{\lg@rootcauseanalysis}{Root Cause Analysis}
  \newcommand{\lg@rootcause}{Root Cause}
  \newcommand{\lg@triggercondition}{Trigger Condition}
  \newcommand{\lg@workaround}{Workaround and Impact}
  \newcommand{\lg@impact}{Impact}
  \newcommand{\lg@backupdata}{Back up data before the workaround}
  \newcommand{\lg@workaroundsteps}{Workaround}
  \newcommand{\lg@verification}{Verification after the workaround}
  \newcommand{\lg@rollback}{Rollback Operation}
  \newcommand{\lg@cleanup}{Cleanup Operation}
\fi

% =====================================================================
%  6-SECTION ENVIRONMENTS
% =====================================================================
% Each environment creates a section/subsection with a fixed, language-aware
% title. The structure is enforced — users just fill in the content.
\newenvironment{problem}{\section{\lg@problem}}{}
\newenvironment{rootcauseanalysis}{\section{\lg@rootcauseanalysis}}{}
\newenvironment{rootcause}{\section{\lg@rootcause}}{}
\newenvironment{triggercondition}{\section{\lg@triggercondition}}{}
\newenvironment{workaround}{\section{\lg@workaround}}{}
\newenvironment{impact}{\subsection{\lg@impact}}{}
\newenvironment{backupdata}{\subsection{\lg@backupdata}}{}
\newenvironment{workaroundsteps}{\subsection{\lg@workaroundsteps}}{}
\newenvironment{verification}{\subsection{\lg@verification}}{}
\newenvironment{rollback}{\subsection{\lg@rollback}}{}
\newenvironment{cleanup}{\subsection{\lg@cleanup}}{}

% =====================================================================
%  COVER PAGE
% =====================================================================
% Compilation time from \time primitive
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
  \ifx\lg@reportversion\@empty\else\textbf{v\lg@reportversion}\fi
  \ifx\lg@reportversion\@empty\else\ifx\lg@reportdate\@empty\else\ — \fi\fi
  \ifx\lg@reportdate\@empty\else\lg@reportdate\fi
  \if@showtime\ \two@digits{\lg@hour}:\two@digits{\lg@min}\fi%
}

\newcommand{\makecover}{%
  \begingroup
  \leftskip=0pt\relax
  \thispagestyle{empty}%
  \vspace*{2cm}%
  % Logo
  {\centering
   \includegraphics[width=3.6cm]{common-assets/huawei-logo-cover.png}\par}%
  \vspace{1.2cm}%
  % Report type label
  {\centering
   \fontsize{16}{20}\selectfont\bfseries\color{huaweired} \lg@reporttype\par}%
  \vspace{1cm}%
  % Title
  {\centering
   \fontsize{24}{30}\selectfont\bfseries \lg@reporttitle\par}%
  \vspace{2cm}%
  % Version info table
  \begin{center}
  \renewcommand{\arraystretch}{1.4}%
  \begin{tabular}{|>{\columncolor{huaweired}\color{white}\bfseries}l|l|}%
  \hline
  Version & \lg@reportversion \\
  \hline
  Date & \lg@reportdate \\
  \hline
  Scenario & \lg@reportscenario \\
  \hline
  \end{tabular}
  \end{center}
  \vfill
  % Copyright
  {\centering
   \fontsize{10}{12}\selectfont
   Copyright \the\year\ Huawei Technologies Co., Ltd.\par
   All rights reserved.\par}%
  \vspace{0.5cm}%
  {\centering
   \fontsize{10}{12}\selectfont
   \if@changelog\lg@covermeta\fi\par}%
  \endgroup
  \clearpage}

\endinput
