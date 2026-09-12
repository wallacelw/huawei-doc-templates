%% testbook.cls
%% =====================================================================
%%  Huawei Test Book Template — POC/acceptance test case documents.
%%
%%  Structure:
%%    1. Cover page (title, version, date, authors)
%%    2. Table of contents
%%    3. Test cases description (objective, scope, preconditions, acceptance)
%%    4. Test case sections organized by domain (H1)
%%    5. Each test case uses a `testcase` environment (table format)
%%    6. Changelog (optional)
%%
%%  Class options:
%%    portuguese  -> uses Portuguese for predefined labels and babel.
%%                   (default: English)
%%    notime      -> hides the compilation time on the cover.
%%                   (default: show time)
%%    nochangelog -> suppresses the changelog section entirely
%%                   and hides version/date/time on the cover page.
%%                   (default: show changelog)
%%    noauthors   -> hides the authors on the cover page.
%%                   (default: show authors if set)
%%    noanswers   -> hides Remarks and Test Result rows in test cases.
%%                   (default: show all rows)
%%    <any>       -> passed to the article class.
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{testbook}[2026/09/12 Huawei Test Book template v3.8.0]

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
\newif\if@showanswers \@showanswerstrue
\DeclareOption{noanswers}{\@showanswersfalse}
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
%  LANGUAGE-AWARE LABELS
% =====================================================================
\if@portuguese
  \newcommand{\lg@testcases}{Casos de Teste}
  \newcommand{\lg@objective}{Objetivo}
  \newcommand{\lg@prerequisites}{Pré-requisitos}
  \newcommand{\lg@procedure}{Procedimento}
  \newcommand{\lg@expectedresult}{Resultado Esperado}
  \newcommand{\lg@remarks}{Observações}
  \newcommand{\lg@testresult}{Resultado do Teste}
\else
  \newcommand{\lg@testcases}{Test Cases}
  \newcommand{\lg@objective}{Objective}
  \newcommand{\lg@prerequisites}{Prerequisites}
  \newcommand{\lg@procedure}{Procedure}
  \newcommand{\lg@expectedresult}{Expected Result}
  \newcommand{\lg@remarks}{Remarks}
  \newcommand{\lg@testresult}{Test Result}
\fi

% =====================================================================
%  TITLES (headings) — same style as guide.cls for consistency
% =====================================================================
\setcounter{secnumdepth}{4}

\titleformat{\section}[block]
  {\normalfont\bfseries\fontsize{20}{25}\selectfont}
  {\fontsize{56}{56}\selectfont\thesection}
  {0pt}
  {\hfill}
  [\vspace{2pt}{\color{huaweired}\titlerule[1.5pt]}\vspace{14pt}]
\titlespacing*{\section}{0pt}{0pt}{30pt}
\let\lg@origsection\section
\renewcommand{\section}{\clearpage\lg@origsection}

\titleformat{\subsection}
  {\normalfont\fontsize{18}{22}\selectfont}{\thesubsection}{0.4em}{}
\titlespacing*{\subsection}{0pt}{30pt}{6pt}

\titleformat{\subsubsection}
  {\normalfont\fontsize{16}{20}\selectfont}{\thesubsubsection}{0.4em}{}
\titlespacing*{\subsubsection}{0pt}{10pt}{4pt}

\titleformat{\paragraph}[hang]
  {\normalfont\fontsize{14}{18}\selectfont}{\theparagraph}{0.4em}{}
\titlespacing*{\paragraph}{0pt}{8pt}{4pt}

\renewcommand{\thesection}{\arabic{section}}
\renewcommand{\thesubsection}{\thesection.\arabic{subsection}}
\renewcommand{\thesubsubsection}{\thesubsection.\arabic{subsubsection}}
\renewcommand{\theparagraph}{\thesubsubsection.\arabic{paragraph}}

% =====================================================================
%  TABLE OF CONTENTS
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
%  COVER PAGE
% =====================================================================
\newcommand{\lg@testbooktitle}{Test Book}
\newcommand{\settestbooktitle}[1]{\renewcommand{\lg@testbooktitle}{#1}}
\newcommand{\lg@covertext}{Huawei Technologies CO., LTD}
\newcommand{\setcovertext}[1]{\renewcommand{\lg@covertext}{#1}}
\newcommand{\lg@coverlogo}{common-assets/huawei-logo-cover.png}
\newcommand{\setcoverlogo}[1]{\renewcommand{\lg@coverlogo}{#1}}

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
   \fontsize{36}{42}\selectfont\bfseries \lg@testbooktitle\par}%
  \vspace{4.5cm}%
  {\centering
   \includegraphics[width=3.6cm]{\lg@coverlogo}\par}%
  \vspace{0.9cm}%
   {\centering
    \fontsize{16}{20}\selectfont \lg@covertext\par}%
   \if@showauthors
     \ifx\lg@docauthors\@empty\else
       \vspace{0.3cm}%
       {\centering
        \fontsize{12}{14}\selectfont \lg@docauthors\par}%
     \fi
   \fi
   \vspace{0.5cm}%
   {\centering
    \fontsize{12}{14}\selectfont \if@changelog\lg@covermeta\fi\par}%
   \endgroup
  \clearpage}

% =====================================================================
%  TEST CASE ENVIRONMENT
% =====================================================================
% The testcase environment creates a subsection and a structured table.
% Usage:
%   \begin{testcase}{Test case title}
%     \testobjective{Verify that X can be created.}
%     \testprerequisites{1. X is running. \\ 2. Y is configured.}
%     \testprocedure{1. Click Create. \\ 2. Set parameters. \\ 3. Click Save.}
%     \testexpected{1. The instance is created. \\ 2. Settings are saved.}
%     \testremarks{Optional remarks.}
%     \testresult{Pass/Fail}
%   \end{testcase}

\newenvironment{testcase}[1]{%
  \subsection{#1}%
  \renewcommand{\arraystretch}{1.3}%
  \noindent
  \begin{tabular}{|>{\columncolor{huaweired}\color{white}\bfseries}p{3cm}|p{0.72\textwidth}|}%
  \hline
}{%
  \hline
  \end{tabular}%
  \vspace{0.5cm}%
}

% Test case field commands (language-aware labels)
\newcommand{\testobjective}[1]{\lg@objective & #1 \\ \hline}
\newcommand{\testprerequisites}[1]{\lg@prerequisites & #1 \\ \hline}
\newcommand{\testprocedure}[1]{\lg@procedure & #1 \\ \hline}
\newcommand{\testexpected}[1]{\lg@expectedresult & #1 \\ \hline}
\newcommand{\testremarks}[1]{%
  \if@showanswers
    \lg@remarks & #1 \\ \hline
  \fi
}
\newcommand{\testresult}[1]{%
  \if@showanswers
    \lg@testresult & #1 \\ \hline
  \fi
}

\endinput
