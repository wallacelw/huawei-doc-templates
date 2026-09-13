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
\ProvidesClass{testbook}[2026/09/13 Huawei Test Book template v4.3.0]

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
\RequirePackage{tabularx}
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
  \newcommand{\lg@testcaseid}{ID}
  \newcommand{\lg@testcasetitle}{Título}
  \newcommand{\lg@teststatus}{Status}
  \newcommand{\lg@step}{Passo}
  \newcommand{\lg@action}{Ação}
  \newcommand{\lg@actualresult}{Resultado Obtido}
\else
  \newcommand{\lg@testcases}{Test Cases}
  \newcommand{\lg@objective}{Objective}
  \newcommand{\lg@prerequisites}{Prerequisites}
  \newcommand{\lg@procedure}{Procedure}
  \newcommand{\lg@expectedresult}{Expected Result}
  \newcommand{\lg@remarks}{Remarks}
  \newcommand{\lg@testresult}{Test Result}
  \newcommand{\lg@testcaseid}{ID}
  \newcommand{\lg@testcasetitle}{Title}
  \newcommand{\lg@teststatus}{Status}
  \newcommand{\lg@step}{Step}
  \newcommand{\lg@action}{Action}
  \newcommand{\lg@actualresult}{Actual Result}
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
% Alias so PDF metadata (pdftitle in huawei-page.sty) shows the testbook title
\renewcommand{\lg@guidetitle}{\lg@testbooktitle}
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
% Each test case is a subsection heading followed by a breakable
% tcolorbox with a red left-rule.  Each field has a full-width red
% mini header bar (white bold label) followed by content below.
% This allows images, code blocks, callout boxes, and nested
% teststeps tables to render correctly and break across pages.
%
% Field order (workflow: design → execute):
%   1. Objective       — what to verify
%   2. Prerequisites   — what must be true before starting
%   3. Procedure       — step-by-step actions (testprocedure environment)
%   4. Expected Result — what should happen
%   5. Test Result     — pass/fail badge (filled after execution)
%   6. Remarks         — observations (filled after execution)
%
% Usage:
%   \begin{testcase}{Test case title}
%     \testobjective{Verify that X can be created.}
%     \testprerequisites{1. X is running. \\ 2. Y is configured.}
%     \begin{testprocedure}
%       \teststep{1}{Log in to Console}
%       \teststep{2}{Click Create and set parameters}
%     \end{testprocedure}
%     \image[width=0.8\linewidth]{common-assets/screenshot.png}
%     \testexpected{1. The instance is created.}
%     \testresult{\testresultbadge{Pass}}
%     \testremarks{Optional remarks.}
%   \end{testcase}

\newenvironment{testcase}[1]{%
  \subsection{#1}%
  \begin{tcolorbox}[
    enhanced jigsaw,
    breakable,
    parbox=false,
    colback=white,
    colframe=huaweired,
    boxrule=0pt,
    leftrule=3pt,
    arc=0pt,
    outer arc=0pt,
    left=8pt, right=8pt, top=6pt, bottom=6pt,
    before skip=10pt, after skip=10pt,
  ]
  \setlength{\parindent}{0pt}%
}{%
  \end{tcolorbox}%
}

% Generic field header: full-width red bar with white bold label.
\newcommand{\lg@testfieldheader}[1]{%
  \par\medskip
  \noindent\colorbox{huaweired}{%
    \makebox[\dimexpr\linewidth-2\fboxsep\relax][l]{%
      \textcolor{white}{\bfseries\strut~#1}%
    }%
  }\par\nobreak\smallskip
}

% Generic field: header bar + content paragraph.
\newcommand{\lg@testfield}[2]{%
  \lg@testfieldheader{#1}%
  #2\par
}

% Test case field commands (language-aware labels)
% Order: Objective, Prerequisites, [Procedure env], Expected, Test Result, Remarks
\newcommand{\testobjective}[1]{\lg@testfield{\lg@objective}{#1}}
\newcommand{\testprerequisites}[1]{\lg@testfield{\lg@prerequisites}{#1}}
\newcommand{\testexpected}[1]{\lg@testfield{\lg@expectedresult}{#1}}
\newcommand{\testresult}[1]{%
  \if@showanswers
    \lg@testfield{\lg@testresult}{#1}
  \fi
}
\newcommand{\testremarks}[1]{%
  \if@showanswers
    \lg@testfield{\lg@remarks}{#1}
  \fi
}

% =====================================================================
%  TEST LIST — styled enumerate with red bold numbers
% =====================================================================
% Use inside testcase fields (prerequisites, expected result, remarks)
% for consistent numbered lists with red bold numbers matching teststep.
% Usage:
%   \testprerequisites{
%     \begin{testlist}
%       \item Terraform apply completed.
%       \item MRS cluster ID is available.
%     \end{testlist}
%   }

\newenvironment{testlist}{%
  \begin{enumerate}[
    label=\textcolor{huaweired}{\bfseries\arabic*.},
    leftmargin=2.5em,
    labelsep=0.5em,
    itemsep=0.3em,
    parsep=0pt,
    topsep=0pt,
  ]
}{%
  \end{enumerate}
}

% =====================================================================
%  TEST SUMMARY TABLE
% =====================================================================
% Overview table showing all test cases with ID, title, and result.
% Usage:
%   \begin{testsummary}
%     \testsummaryrow{TC-001}{Verify MRS cluster}{Pass}
%     \testsummaryrow{TC-002}{Verify OBS bucket}{Pass}
%   \end{testsummary}

\newenvironment{testsummary}{%
  \renewcommand{\arraystretch}{1.3}%
  \noindent
  \begin{tabular}{|>{\raggedright\arraybackslash}p{2.5cm}|>{\raggedright\arraybackslash}p{\dimexpr\linewidth-5cm-6\tabcolsep-4\arrayrulewidth\relax}|>{\centering\arraybackslash}p{2.5cm}|}%
  \hline
  \rowcolor{huaweired}
  {\color{white}\bfseries\lg@testcaseid} &
  {\color{white}\bfseries\lg@testcasetitle} &
  {\color{white}\bfseries\lg@teststatus} \\
  \hline
}{%
  \hline
  \end{tabular}%
  \vspace{0.5cm}%
}

\newcommand{\testsummaryrow}[3]{#1 & #2 & #3 \\ \hline}

% =====================================================================
%  TEST PROCEDURE ENVIRONMENT
% =====================================================================
% Renders the "Procedure" mini header bar followed by auto-numbered
% paragraph steps.  Each \teststep is a numbered paragraph (red bold
% number).  Images, code blocks, and callouts can be placed freely
% between steps — no tabular restrictions.
% Usage:
%   \begin{testprocedure}
%     \teststep{Log in to Console}
%     \teststep{Click Create and set parameters}
%     \image[width=0.8\linewidth]{common-assets/screenshot.png}
%     \teststep{Verify the instance is created}
%   \end{testprocedure}

\newcounter{lg@teststep}

\newenvironment{testprocedure}{%
  \lg@testfieldheader{\lg@procedure}%
  \setcounter{lg@teststep}{0}%
}{%
  \par\medskip
}

% Auto-numbered step paragraph.  Red bold number, then action text.
% Indented to align with testlist items (leftmargin ~2.5em).
\newcommand{\teststep}[1]{%
  \refstepcounter{lg@teststep}%
  \par\smallskip
  \noindent\hspace{1em}\textcolor{huaweired}{\bfseries\arabic{lg@teststep}.}\hspace{0.6em}#1\par
}

% =====================================================================
%  TEST RESULT BADGE
% =====================================================================
% Visual badge for pass/fail/blocked status.
% Usage: \testresultbadge{Pass}  \testresultbadge{Fail}  \testresultbadge{Blocked}

\newcommand{\testresultbadge}[1]{%
  \ifstrequal{#1}{Pass}{%
    \tcbox[on line,colback=green!15,colframe=green!50!black,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,Pass\,}%
  }{%
    \ifstrequal{#1}{Fail}{%
      \tcbox[on line,colback=red!15,colframe=red!70!black,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,Fail\,}%
    }{%
      \ifstrequal{#1}{Blocked}{%
        \tcbox[on line,colback=orange!15,colframe=orange!80!black,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,Blocked\,}%
      }{%
        \ifstrequal{#1}{Untested}{%
          \tcbox[on line,colback=gray!15,colframe=gray!60,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,Untested\,}%
        }{%
          \tcbox[on line,colback=gray!15,colframe=gray!60,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,#1\,}%
        }%
      }%
    }%
  }%
}

\endinput
