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
%%  All shared boilerplate lives in templates/_base/huawei-base.cls:
%%    - Class options (portuguese, indentbody, notime, nochangelog,
%%      noauthors); any other option is passed to the article class.
%%    - \LoadClass of article (a4paper, 10pt) and all package loads.
%%    - The 13 shared modules from templates/_base/.
%%    - \setdoctitle (shared cover title setter).
%%
%%  Class options (testbook-specific):
%%    noanswers   -> hides Remarks and Test Result rows in test cases.
%%                   (default: show all rows)
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{testbook}[2026/09/26 Huawei Test Book template v6.16.0]

% ---- Options --------------------------------------------------------
% noanswers is testbook-specific; the shared options are declared in
% huawei-base. Remaining options are passed to huawei-base, which
% forwards unknown ones to the article class.
\newif\if@showanswers \@showanswerstrue
\DeclareOption{noanswers}{\@showanswersfalse}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{huawei-base}}
\ProcessOptions\relax

% ---- Base class (options, article, packages, shared modules) ---------
\LoadClass{huawei-base}

% ---- Packages (testbook-specific) ------------------------------------
\RequirePackage{tabularx}

% ---- Shared modules (testbook-specific) -------------------------------
\RequirePackage{huawei-badges}

% =====================================================================
%  LANGUAGE-AWARE LABELS
% =====================================================================
\if@portuguese
  \newcommand{\lg@testcases}{Casos de Teste}
  \newcommand{\lg@testcase}{Caso de Teste}
  \newcommand{\lg@objective}{Objetivo}
  \newcommand{\lg@testscope}{Escopo do Teste}
  \newcommand{\lg@prerequisites}{Pré-requisitos}
  \newcommand{\lg@procedure}{Procedimento}
  \newcommand{\lg@expectedresult}{Resultado Esperado}
  \newcommand{\lg@remarks}{Observações}
  \newcommand{\lg@testresult}{Resultado do Teste}
  \newcommand{\lg@testcaseid}{ID}
  \newcommand{\lg@testcasetitle}{Título}
  \newcommand{\lg@teststatus}{Status}
  % Test result badge labels (source keeps EN enums; rendering is PT-aware)
  \newcommand{\lg@testpass}{Atende}
  \newcommand{\lg@testpartial}{Atende com ressalvas}
  \newcommand{\lg@testfail}{Não atende}
  \newcommand{\lg@testuntested}{Não testado}
\else
  \newcommand{\lg@testcases}{Test Cases}
  \newcommand{\lg@testcase}{Testcase}
  \newcommand{\lg@objective}{Objective}
  \newcommand{\lg@testscope}{Test Scope}
  \newcommand{\lg@prerequisites}{Prerequisites}
  \newcommand{\lg@procedure}{Procedure}
  \newcommand{\lg@expectedresult}{Expected Result}
  \newcommand{\lg@remarks}{Remarks}
  \newcommand{\lg@testresult}{Test Result}
  \newcommand{\lg@testcaseid}{ID}
  \newcommand{\lg@testcasetitle}{Title}
  \newcommand{\lg@teststatus}{Status}
  % Test result badge labels (source keeps EN enums; rendering is PT-aware)
  \newcommand{\lg@testpass}{Pass}
  \newcommand{\lg@testpartial}{Partial}
  \newcommand{\lg@testfail}{Fail}
  \newcommand{\lg@testuntested}{Untested}
\fi

% ---- Titles (shared) ----------------------------------------------
% (loaded via huawei-titles)

% ---- TOC (shared) -------------------------------------------------
% (loaded via huawei-toc)

% ---- Cover (shared) -----------------------------------------------
% \setdoctitle{...} is defined in huawei-base.
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
%   2. Test Scope      — topics/requirements covered by this testcase
%   3. Prerequisites   — what must be true before starting
%   4. Procedure       — step-by-step actions (testprocedure environment)
%   5. Expected Result — what should happen
%   6. Test Result     — pass/fail badge (filled after execution)
%   7. Remarks         — observations (filled after execution)
%
% Usage:
%   \begin{testcase}{Test case title}
%     \testobjective{Verify that X can be created.}
%     \testscope{REQ-001: ECS creation; REQ-003: Network configuration}
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
% Order: Objective, Test Scope, Prerequisites, Procedure, Expected, Test Result, Remarks
% Prerequisites, Procedure, and Expected Result are environments with
% auto-numbered \teststep items — uniform code, same visual style.
\newcommand{\testobjective}[1]{\lg@testfield{\lg@objective}{#1}}
\newcommand{\testscope}[1]{\lg@testfield{\lg@testscope}{#1}}
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

% Result column width: must fit the widest badge the language renders.
% Measured pill widths (HarmonyOS Sans, \bfseries\small): PT "Atende
% com ressalvas" = 4.32cm, EN pills = 2.56cm. The widths add slack so
% no badge touches the cell rules (no Overfull \hbox).
\newlength{\lg@summaryresultcol}
\if@portuguese
  \setlength{\lg@summaryresultcol}{4.5cm}
\else
  \setlength{\lg@summaryresultcol}{2.7cm}
\fi

\newenvironment{testsummary}{%
  \renewcommand{\arraystretch}{1.3}%
  \setcounter{lg@summaryrow}{0}%
  \noindent
  % middle column = \linewidth - ID col (2.5cm) - result col - 6\tabcolsep - 4\arrayrulewidth
  \begin{longtable}{|>{\RaggedRight\arraybackslash}m{2.5cm}|>{\RaggedRight\arraybackslash}m{\dimexpr\linewidth-2.5cm-\lg@summaryresultcol-6\tabcolsep-4\arrayrulewidth\relax}|>{\Centering\arraybackslash}m{\lg@summaryresultcol}|}%
  \hline
  \rowcolor{huaweired}
  {\color{white}\bfseries\lg@testcaseid} &
  {\color{white}\bfseries\lg@testcasetitle} &
  {\color{white}\bfseries\lg@teststatus} \\
  \hline
  \endhead
}{%
  \end{longtable}%
  \medskip
}

\newcounter{lg@summaryrow}
\newcommand{\testsummaryrow}[3]{%
  \stepcounter{lg@summaryrow}%
  \ifodd\value{lg@summaryrow}\gdef\lg@cc{}\else\gdef\lg@cc{\cellcolor{codebg}}\fi
  \lg@cc #1 & \lg@cc #2 & \lg@cc #3 \\ \hline
}

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
  \hangindent=2.5em\hangafter=1
  \noindent\hspace{1em}\textcolor{huaweired}{\bfseries\arabic{lg@teststep}.}\hspace{0.6em}#1\par
}

% =====================================================================
%  TEST RESULT BADGE
% =====================================================================
% Visual badge for pass/partial/fail/untested status.
% Usage: \testresultbadge{Pass}  \testresultbadge{Partial}  \testresultbadge{Fail}  \testresultbadge{Untested}
% Source keeps language-neutral enum values (Pass/Partial/Fail/Untested);
% rendering is language-aware under the portuguese class option
% (Atende/Atende com ressalvas/Não atende/Não testado), mirroring
% \pocresult in poc.cls.
% Unknown values (e.g. legacy Blocked) fall back to the neutral gray pill.

\newcommand{\testresultbadge}[1]{%
  \ifstrequal{#1}{Pass}{%
    \huaweibadge[1.5cm]{tipbg}{tipfg}{\lg@testpass}%
  }{%
    \ifstrequal{#1}{Partial}{%
      \huaweibadge[1.5cm]{warningbg}{warningfg}{\lg@testpartial}%
    }{%
      \ifstrequal{#1}{Fail}{%
        \huaweibadge[1.5cm]{red!15}{huaweired}{\lg@testfail}%
      }{%
        \ifstrequal{#1}{Untested}{%
          \huaweibadge[1.5cm]{codebg}{ruleblack}{\lg@testuntested}%
        }{%
          \huaweibadge[1.5cm]{codebg}{ruleblack}{#1}%
        }%
      }%
    }%
  }%
}

\endinput
