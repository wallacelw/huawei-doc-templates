%% poc.cls
%% =====================================================================
%%  Huawei POC/Homologation Template — Proof of Concept and technical
%%  homologation documents for Huawei Cloud.
%%
%%  Structure:
%%    1. Cover page (title, subtitle, client, version, date, authors)
%%    2. Table of contents
%%    3. Preamble: Executive Summary, Background, Goal & Objectives,
%%       Solution Overview
%%    4. Scope & Planning: Scope, Premises, Methodology, Activities,
%%       Schedule, Responsibility Matrix
%%    5. Conclusion: Expected Results, Actual Results, Comments,
%%       Conclusion, Signatures
%%    6. Changelog (optional)
%%
%%  All shared boilerplate lives in templates/_base/huawei-base.cls:
%%    - Class options (portuguese, indentbody, notime, nochangelog,
%%      noauthors); any other option is passed to the article class.
%%    - \LoadClass of article (a4paper, 10pt) and all package loads.
%%    - The 13 shared modules from templates/_base/.
%%    - \setdoctitle (shared cover title setter).
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{poc}[2026/09/23 Huawei POC template v6.14.0]

% ---- Base class (options, article, packages, shared modules) ---------
\LoadClassWithOptions{huawei-base}

% ---- Packages (poc-specific) ------------------------------------------
\RequirePackage{tabularx}
\RequirePackage{amssymb}
\RequirePackage{seqsplit}

% ---- Shared modules (poc-specific) -------------------------------------
\RequirePackage{huawei-badges}

% =====================================================================
%  LANGUAGE-AWARE LABELS
% =====================================================================
\if@portuguese
  % POC result labels
  \newcommand{\lg@pocpass}{Atende}
  \newcommand{\lg@pocpartial}{Atende com ressalvas}
  \newcommand{\lg@pocfail}{Não atende}
  \newcommand{\lg@pocskip}{Não testado}
  % Closing record labels
  \newcommand{\lg@closingitem}{Item}
  \newcommand{\lg@closingrecord}{Registro}
  % Signature labels
  \newcommand{\lg@siggreeting}{At.te,}
  \newcommand{\lg@sigemail}{E-mail}
  % POC classification
  \newcommand{\lg@pochomologated}{Homologada}
  \newcommand{\lg@pocwithreservations}{Homologada com ressalvas}
  \newcommand{\lg@pocnothomologated}{Não homologada}
  % User-facing aliases (no @) for use in passthrough blocks
  \newcommand{\pochomologated}{\lg@pochomologated}
  \newcommand{\pocwithreservations}{\lg@pocwithreservations}
  \newcommand{\pocnothomologated}{\lg@pocnothomologated}
\else
  % POC result labels
  \newcommand{\lg@pocpass}{Pass}
  \newcommand{\lg@pocpartial}{Partial}
  \newcommand{\lg@pocfail}{Fail}
  \newcommand{\lg@pocskip}{Skip}
  % Closing record labels
  \newcommand{\lg@closingitem}{Item}
  \newcommand{\lg@closingrecord}{Record}
  % Signature labels
  \newcommand{\lg@siggreeting}{Sincerely,}
  \newcommand{\lg@sigemail}{E-mail}
  % POC classification
  \newcommand{\lg@pochomologated}{Homologated}
  \newcommand{\lg@pocwithreservations}{With reservations}
  \newcommand{\lg@pocnothomologated}{Not homologated}
  % User-facing aliases (no @) for use in passthrough blocks
  \newcommand{\pochomologated}{\lg@pochomologated}
  \newcommand{\pocwithreservations}{\lg@pocwithreservations}
  \newcommand{\pocnothomologated}{\lg@pocnothomologated}
\fi

% ---- Cover ----------------------------------------------------------
% \setdoctitle{...} is defined in huawei-base.
\newcommand{\setpoctitle}[1]{\setdoctitle{#1}}

% =====================================================================
%  POC RESULT BADGE
% =====================================================================
% Visual badge for POC/homologation results.
% Usage: \pocresult{Pass}  \pocresult{Partial}  \pocresult{Fail}  \pocresult{Skip}
% Labels are language-aware (Atende / Pass, etc.)

\newcommand{\pocresult}[1]{%
  \ifstrequal{#1}{Pass}{%
    \huaweibadge{tipbg}{tipfg}{\lg@pocpass}%
  }{%
    \ifstrequal{#1}{Partial}{%
      \huaweibadge{warningbg}{warningfg}{\lg@pocpartial}%
    }{%
      \ifstrequal{#1}{Fail}{%
        \huaweibadge{red!15}{huaweired}{\lg@pocfail}%
      }{%
        \ifstrequal{#1}{Skip}{%
          \huaweibadge{codebg}{ruleblack}{\lg@pocskip}%
        }{%
          \huaweibadge{codebg}{ruleblack}{#1}%
        }%
      }%
    }%
  }%
}

% =====================================================================
%  OBJECTIVE BLOCK
% =====================================================================
% Highlighted box for the goal statement in Section 3.
% Usage:
%   \begin{objectiveblock}
%   Migrate the application to Huawei Cloud ...
%   \end{objectiveblock}

\newenvironment{objectiveblock}{%
  \begin{tcolorbox}[
    enhanced jigsaw, breakable,
    colback=infobg, colframe=infofg,
    boxrule=1pt, arc=3pt,
    left=8pt, right=8pt, top=6pt, bottom=6pt,
  ]
}{%
  \end{tcolorbox}
}

% =====================================================================
%  STAKEHOLDERS TABLE
% =====================================================================
% Contact table grouped by organization.
% Usage (passthrough block):
%   \begin{stakeholders}
%   \stakeholderorg{Organization Name}
%   \stakeholderrow{Name}{email}{phone}{role}
%   \stakeholderorg{Another Org}
%   \stakeholderrow{Name}{email}{phone}{role}
%   \end{stakeholders}

\newenvironment{stakeholders}{%
  \par
  \renewcommand{\arraystretch}{1.3}%
  \noindent
  \begin{tabular}{|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-5\arrayrulewidth-8\tabcolsep)*15/100\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-5\arrayrulewidth-8\tabcolsep)*35/100\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-5\arrayrulewidth-8\tabcolsep)*20/100\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-5\arrayrulewidth-8\tabcolsep)*30/100\relax}|}
  \hline
}{%
  \end{tabular}%
  \par
}
\newcommand{\stakeholderorg}[1]{%
  \rowcolor{huaweired}\multicolumn{4}{|>{\RaggedRight\arraybackslash}m{\dimexpr\linewidth-2\tabcolsep-2\arrayrulewidth\relax}|}{\color{white}\textbf{#1}} \\ \hline
}
\newcommand{\stakeholderrow}[4]{#1 & \seqsplit{#2} & #3 & #4 \\ \hline}

% =====================================================================
%  CLOSING RECORD
% =====================================================================
% Final classification table with checkboxes.
% Usage (passthrough block):
%   \begin{closingrecord}
%   \closingrow{Preliminary result}{\checkbox{\pochomologated} \checkbox{\pocwithreservations}}
%   \closingrow{Critical pending items}{}
%   \closingrow{Deadline for evidence}{2026-12-31}
%   \closingrow{Responsibles}{Jane Doe}
%   \closingrow{Final observations}{}
%   \end{closingrecord}

\newenvironment{closingrecord}{%
  \par
  \renewcommand{\arraystretch}{1.5}%
  \noindent
  \begin{tabular}{|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-3\arrayrulewidth-4\tabcolsep)*30/100\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-3\arrayrulewidth-4\tabcolsep)*70/100\relax}|}
  \hline
  \rowcolor{huaweired}
  {\color{white}\bfseries\lg@closingitem} & {\color{white}\bfseries\lg@closingrecord} \\
  \hline
}{%
  \end{tabular}%
  \par
}
\newcommand{\closingrow}[2]{#1 & #2 \\ \hline}
\newcommand{\checkbox}[1]{\fbox{\,}~#1}

% =====================================================================
%  SIGNATURES
% =====================================================================
% Formal sign-off block — 2x2 grid.
% Use \signaturecell for each cell, with & and \\ \hline explicitly.
% Usage (passthrough block):
%   \begin{signatures}
%   \signaturecell{Name}{Title}{email}{Address} & \signaturecell{Name}{Title}{email}{Address} \\ \hline
%   \signaturecell{Name}{Title}{email}{Address} & \signaturecell{Name}{Title}{email}{Address} \\ \hline
%   \end{signatures}

\newenvironment{signatures}{%
  \par
  \begin{tabular}{|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-3\arrayrulewidth-4\tabcolsep)/2\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-3\arrayrulewidth-4\tabcolsep)/2\relax}|}
  \hline
}{%
  \end{tabular}%
  \par
}
\newcommand{\signaturecell}[4]{%
  \lg@siggreeting \par\medskip
  \textbf{#1} \par
  #2 \par
  \textbf{\lg@sigemail:} \texttt{\seqsplit{#3}} \par
  #4 \par\bigskip
}

\endinput
