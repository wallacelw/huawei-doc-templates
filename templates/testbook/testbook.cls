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
%%    indentbody  -> indents all running text by \contentindent.
%%                   (default: off)
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
\ProvidesClass{testbook}[2026/09/16 Huawei Test Book template v6.0.1]

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

% =====================================================================
%  LANGUAGE-AWARE LABELS
% =====================================================================
\if@portuguese
  \newcommand{\lg@testcases}{Casos de Teste}
  \newcommand{\lg@testcase}{Caso de Teste}
  \newcommand{\lg@objective}{Objetivo}
  \newcommand{\lg@prerequisites}{Pré-requisitos}
  \newcommand{\lg@procedure}{Procedimento}
  \newcommand{\lg@expectedresult}{Resultado Esperado}
  \newcommand{\lg@remarks}{Observações}
  \newcommand{\lg@testresult}{Resultado do Teste}
  \newcommand{\lg@testcaseid}{ID}
  \newcommand{\lg@testcasetitle}{Título}
  \newcommand{\lg@teststatus}{Status}
\else
  \newcommand{\lg@testcases}{Test Cases}
  \newcommand{\lg@testcase}{Testcase}
  \newcommand{\lg@objective}{Objective}
  \newcommand{\lg@prerequisites}{Prerequisites}
  \newcommand{\lg@procedure}{Procedure}
  \newcommand{\lg@expectedresult}{Expected Result}
  \newcommand{\lg@remarks}{Remarks}
  \newcommand{\lg@testresult}{Test Result}
  \newcommand{\lg@testcaseid}{ID}
  \newcommand{\lg@testcasetitle}{Title}
  \newcommand{\lg@teststatus}{Status}
\fi

% ---- Titles (shared) ----------------------------------------------
% (loaded via huawei-titles)

% ---- TOC (shared) -------------------------------------------------
% (loaded via huawei-toc)

% ---- Cover (shared) -----------------------------------------------
\newcommand{\setdoctitle}[1]{\renewcommand{\lg@doctitle}{#1}}
\newcommand{\settestbooktitle}[1]{\setdoctitle{#1}}

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
%     \begin{testprerequisites}
%       \teststep{X is running.}
%       \teststep{Y is configured.}
%     \end{testprerequisites}
%     \begin{testprocedure}
%       \teststep{Log in to Console}
%       \teststep{Click Create and set parameters}
%     \end{testprocedure}
%     \image[width=0.8\linewidth]{common-assets/screenshot.png}
%     \begin{testexpected}
%       \teststep{The instance is created.}
%     \end{testexpected}
%     \testresult{\testresultbadge{Pass}}
%     \testremarks{Optional remarks.}
%   \end{testcase}

\newcounter{testcase}

\newenvironment{testcase}[1]{%
  \refstepcounter{testcase}%
  \par\medskip
  {\centering\textbf{\lg@testcase~\thetestcase:}~#1\par}\nobreak\medskip
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

% Test case field commands and environments.
% Order: Objective, Prerequisites, Procedure, Expected, Test Result, Remarks
% Prerequisites, Procedure, and Expected Result are environments with
% auto-numbered \teststep items — uniform code, same visual style.
\newcommand{\testobjective}[1]{\lg@testfield{\lg@objective}{#1}}
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
  % middle column = \linewidth - (2 x 2.5cm side columns) - 6\tabcolsep - 4\arrayrulewidth
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
%  TEST FIELD ENVIRONMENTS (prerequisites, procedure, expected)
% =====================================================================
% All three use the same pattern: mini header bar + auto-numbered
% \teststep items.  Images, code blocks, and callouts can be placed
% freely between steps — no tabular restrictions.
%
% Usage:
%   \begin{testprerequisites}
%     \teststep{Terraform apply completed.}
%     \teststep{MRS cluster ID is available.}
%   \end{testprerequisites}
%
%   \begin{testprocedure}
%     \teststep{Log in to Console}
%     \image[width=0.8\linewidth]{common-assets/screenshot.png}
%     \teststep{Verify the instance is created}
%   \end{testprocedure}
%
%   \begin{testexpected}
%     \teststep{Cluster status is Running.}
%     \teststep{All components are Normal.}
%   \end{testexpected}

\newcounter{lg@teststep}

\newenvironment{testprerequisites}{%
  \lg@testfieldheader{\lg@prerequisites}%
  \setcounter{lg@teststep}{0}%
}{%
  \par\medskip
}

\newenvironment{testprocedure}{%
  \lg@testfieldheader{\lg@procedure}%
  \setcounter{lg@teststep}{0}%
}{%
  \par\medskip
}

\newenvironment{testexpected}{%
  \lg@testfieldheader{\lg@expectedresult}%
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
    \tcbox[on line,colback=tipbg,colframe=tipfg,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,Pass\,}%
  }{%
    \ifstrequal{#1}{Fail}{%
      \tcbox[on line,colback=red!15,colframe=huaweired,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,Fail\,}%
    }{%
      \ifstrequal{#1}{Blocked}{%
        \tcbox[on line,colback=warningbg,colframe=warningfg,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,Blocked\,}%
      }{%
        \ifstrequal{#1}{Untested}{%
          \tcbox[on line,colback=codebg,colframe=ruleblack,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,Untested\,}%
        }{%
          \tcbox[on line,colback=codebg,colframe=ruleblack,boxrule=0.8pt,arc=2pt,fontupper=\bfseries\small]{\,#1\,}%
        }%
      }%
    }%
  }%
}

\endinput
